import threading
import time
import os
import json
import asyncio
import queue
import signal
import sys
import re
import secrets
import shutil
from datetime import datetime, timedelta
from typing import Optional, Any, Dict, Union
import logging
from logging.handlers import TimedRotatingFileHandler
from contextlib import asynccontextmanager

import subprocess
import platform
import xml.sax.saxutils

import requests
import socketio
import edge_tts
import edge_tts.exceptions
import uvicorn
from pydub import AudioSegment
import pygame
from fastapi import FastAPI, HTTPException, Header, Depends, status, Form, Body, Request, Cookie, Response, UploadFile, File
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel, ConfigDict

# =============================================================================
# 1. KONFIGURATION & SETUP
# =============================================================================

CONFIG_FILE = "config.json"

def load_config():
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def save_config(cfg_data):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        json.dump(cfg_data, f, indent=4, ensure_ascii=False)

cfg = load_config()

LOG_FILE = cfg["logging"]["file"]
TTS_TEMP_FILE = "tts_temp.wav"
DEBUG = cfg.get("debug", False)

logger = logging.getLogger("durchsage")
logger.setLevel(logging.DEBUG)
syslog_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
syslog_handler = TimedRotatingFileHandler("system.log", when="midnight", interval=1, backupCount=30, encoding="utf-8")
syslog_handler.setFormatter(syslog_formatter)
logger.addHandler(syslog_handler)
console_handler = logging.StreamHandler()
console_handler.setFormatter(syslog_formatter)
logger.addHandler(console_handler)

@asynccontextmanager
async def lifespan(app: FastAPI):
    cfg_live = load_config()
    yield
    logger.info("Lifespan Shutdown: Beende Audio...")
    if pygame and pygame.mixer.get_init():
        try: pygame.mixer.quit()
        except: pass

app = FastAPI(title="Alarmdurchsage Server Web UI", lifespan=lifespan)

# Globale Objekte & Locks
alarm_queue = queue.Queue()
stop_event = threading.Event()
http_session = requests.Session()
sio = socketio.Client(logger=False, engineio_logger=False, reconnection=True)
last_disconnect_time = time.time()
connection_error_msg = None

log_lock = threading.Lock()
timers_lock = threading.Lock()
auth_lock = threading.Lock()
active_timers = []

# Simple Auth Token Management
active_sessions = set()

# =============================================================================
# 2. AUDIO INITIALISIERUNG
# =============================================================================

def ensure_mixer():
    if not pygame.mixer.get_init():
        try:
            cfg_live = load_config()
            audio_device = cfg_live.get("audio", {}).get("output_device", "").strip()
            if audio_device:
                try:
                    pygame.mixer.init(devicename=audio_device)
                except Exception as e:
                    logger.warning(f"Audio Init mit Device '{audio_device}' fehlgeschlagen ({e}), versuche Standard...")
                    pygame.mixer.init()
            else:
                pygame.mixer.init()
            pygame.mixer.music.set_volume(1)
            logger.info(f"Audio-System initialisiert. Device: {audio_device or 'Standard'}")
        except Exception as e:
            logger.error(f"Audio Init endgültig fehlgeschlagen: {e}")

ensure_mixer()

# =============================================================================
# 3. HELPER: NETZWERK & API
# =============================================================================

def robust_api_get(url):
    try:
        resp = http_session.get(url, timeout=5)
        if resp.status_code == 401:
            logger.warning("401 Unauthorized bei LAWZ API erkannt. Starte Re-Login...")
            with auth_lock:
                if login_external():
                    logger.info("Re-Login erfolgreich. Wiederhole Request...")
                    resp = http_session.get(url, timeout=5)
                else:
                    logger.error("Re-Login fehlgeschlagen!")
                    return None
        resp.raise_for_status()
        return resp.json()
    except Exception as e:
        logger.error(f"Fehler bei {url}: {e}")
        return None

def get_department_status_data():
    ts = int(time.time() * 1000)
    url = f"{cfg['credentials']['base_url']}/status/resources?_t={ts}"
    data = robust_api_get(url)
    if data:
        try:
            return data["data"][0]["department"]
        except (KeyError, IndexError):
            pass
    return None

def fetch_single_mission_details(mission_id):
    ts = int(time.time() * 1000)
    url = f"{cfg['credentials']['base_url']}/alert?alertId={mission_id}&_={ts}"
    logger.info(f"Hole Update von LAWZ für Einsatz ID {mission_id}...")
    return robust_api_get(url)

# =============================================================================
# 4. SOCKET.IO EVENT HANDLER
# =============================================================================

@sio.event
def connect():
    global last_disconnect_time, connection_error_msg
    last_disconnect_time = None
    connection_error_msg = None
    logger.info(f"Socket.io Verbunden. Session ID: {sio.sid}")
    sio.emit("refresh")

@sio.event
def disconnect():
    global last_disconnect_time
    if last_disconnect_time is None:
        last_disconnect_time = time.time()
    logger.info("Socket.io Verbindung getrennt.")

@sio.on("update")
def socket_update(data):
    sio.emit("refresh")

@sio.on("action")
def socket_action(data):
    if not isinstance(data, dict): return
    if not data.get("externalId"): return
    if "übung" in data.get("type", "").lower(): return

    try:
        process_alarm_logic(data)
    except Exception as e:
        logger.error(f"Fehler bei Verarbeitung des Socket Actions: {e}")

# =============================================================================
# 5. LOGGING
# =============================================================================

class EinsatzPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: Union[int, str]
    type: Optional[str] = None
    description: Optional[str] = None
    placeLAWZ: Optional[str] = None
    additionalAddressInfo: Optional[str] = None

def clean_old_logs(logs):
    cfg_live = load_config()
    try:
        retention = int(cfg_live.get("logging", {}).get("retention_days", 365))
    except Exception:
        retention = 365
    
    if retention == -1:
        return logs
        
    cutoff = datetime.now() - timedelta(days=retention)
    clean = []
    for entry in logs:
        try:
            ts_str = entry.get("detectionTime")
            if ts_str:
                dt = datetime.fromisoformat(ts_str)
                if dt > cutoff: clean.append(entry)
            else: clean.append(entry)
        except ValueError: clean.append(entry)
    return clean

def log_event(data):
    if isinstance(data, BaseModel):
        data = data.model_dump()

    with log_lock:
        logs = []
        if os.path.exists(LOG_FILE):
            try:
                with open(LOG_FILE, "r", encoding="utf-8") as f:
                    logs = json.load(f)
            except Exception: logs = []

        data["detectionTime"] = datetime.now().isoformat()
        logs.append(data)
        logs = clean_old_logs(logs)

        with open(LOG_FILE, "w", encoding="utf-8") as f:
            json.dump(logs, f, indent=4, ensure_ascii=False)

def is_event_processed(einsatz_id):
    if not einsatz_id: return False
    with log_lock:
        if not os.path.exists(LOG_FILE): return False
        try:
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                logs = json.load(f)
                for entry in logs:
                    if str(entry.get("id")) == str(einsatz_id):
                        return True
        except Exception: return False
    return False

# =============================================================================
# 6. TEXT & TTS
# =============================================================================

def expand_units(text: str) -> str:
    if not text: return ""
    text = re.sub(r'(\d+(?:[.,]\d+)?)\s*t\b', lambda m: m.group(1).replace('.', ',') + " Tonnen", text)
    text = re.sub(r'(\d+(?:[.,]\d+)?)\s*L\b', lambda m: m.group(1).replace('.', ',') + " Liter", text)
    text = re.sub(r'(\d+(?:[.,]\d+)?)\s*km\b', lambda m: m.group(1).replace('.', ',') + " Kilometer", text)
    text = re.sub(r'(\d+(?:[.,]\d+)?)\s*m\b', lambda m: m.group(1).replace('.', ',') + " Meter", text)
    return text

def normalize_text(text: str) -> str:
    if not text: return ""
    text = re.sub(r"(\+?\d{1,3}[\s\-]?)?(\(?\d{2,4}\)?[\s\-]?)(\d{2,4}[\s\-]?){2,4}", "", text)
    
    cfg_live = load_config()
    abbreviations = cfg_live.get("text_processing", {}).get("abbreviations", {})
    for abk, ersatz in abbreviations.items():
        text = re.sub(rf"\b{re.escape(abk)}(?!\w)", ersatz, text, flags=re.IGNORECASE)
    
    return " ".join(expand_units(text).split())

def format_stichwort(original: str) -> str:
    if not original: return ""
    o = " ".join(original.split())
    u = o.upper()
    
    kategorie = "Einsatz!" 
    cfg_live = load_config()
    mapping = cfg_live.get("text_processing", {}).get("keyword_mapping", {})
    found_mapping = False
    
    for key, klartext in mapping.items():
        if u.startswith(key.upper()): 
            kategorie = f"{klartext}!"
            found_mapping = True
            break
    
    if not found_mapping:
        if re.match(r"^[BF]\d*", u): 
            kategorie = "Brandeinsatz!"
        elif u.startswith("T"): 
            kategorie = "Technischer Einsatz!"
            
    return expand_units(f"{kategorie} {o}!")

def create_announcement_text(data: dict) -> str:
    stichwort = format_stichwort(data.get("type", ""))
    
    adresse_raw = data.get("additionalAddressInfo", "")
    desc = normalize_text(data.get("description", ""))
    gemeinde = data.get("placeLAWZ", "")

    addr = adresse_raw
    cfg_live = load_config()
    addr_replacements = cfg_live.get("text_processing", {}).get("address_replacements", {})
    if addr:
        for search, replace in addr_replacements.items():
            addr = addr.replace(search, replace)
        lines = [l.strip() for l in addr.splitlines() if l.strip()]
        addr_full = ", ".join(lines)
    else:
        addr_full = ""

    parts = []
    if stichwort: parts.append(stichwort)
    if addr_full: parts.append(addr_full + "!")
    if gemeinde: parts.append(f"Gemeinde {gemeinde}!")
    if desc: parts.append(f"Information: {desc}")

    return " ".join(parts)

async def generate_tts(text, filename):
    if not text or not text.strip(): return None
    
    if os.path.exists(filename):
        try: os.remove(filename)
        except Exception: pass
    
    cfg_live = load_config()
    try:
        temp_mp3 = "tts_temp.mp3"
        communicate = edge_tts.Communicate(
            text=text,
            voice=cfg_live["audio"]["voice"],
            rate=cfg_live["audio"]["rate"]
        )
        await communicate.save(temp_mp3)
        if os.path.exists(temp_mp3):
            try:
                sound = AudioSegment.from_file(temp_mp3)
                sound += cfg_live["audio"]["gain_db"]
                sound.export(filename, format="wav")
                os.remove(temp_mp3)
                return filename
            except Exception as e:
                logger.error(f"FFmpeg fehlt oder Pydub Fehler! Verarbeitung abgebrochen. ({e})")
                return None
    except Exception as e:
        logger.error(f"TTS Fehler: {e}")
        return None
    return None

# =============================================================================
# 7. AUDIO WORKER
# =============================================================================

def play_file_blocking(filepath):
    if not os.path.exists(filepath): return
    ensure_mixer()
    if not pygame.mixer.get_init(): return
    try:
        pygame.mixer.music.load(filepath)
        pygame.mixer.music.play()
        while pygame.mixer.music.get_busy():
            time.sleep(0.1)
        try: pygame.mixer.music.unload()
        except: pass
    except Exception as e:
        logger.error(f"Playback Fehler bei {filepath}: {e}")

def worker_loop():
    logger.info("Audio-Warteschlange (Worker) gestartet.")
    
    while True:
        try:
            item = alarm_queue.get()
            stop_event.clear()

            if item == "CLEAR":
                if pygame.mixer.get_init(): pygame.mixer.music.stop()
                alarm_queue.task_done()
                continue
            
            # sound_mode: "full", "gong_only", "speech_only", "mute"
            text, gong_id, sound_mode = item
            
            cfg_live = load_config()
            pause_sec = cfg_live["audio"].get("gong_pause_sec", 1.0)

            if sound_mode == "mute":
                logger.info("Modus 'Stumm'. Überspringe Audio-Ausgabe komplett.")
                alarm_queue.task_done()
                continue

            tts_file = "tts.wav"
            play_file = None
            
            def run_tts():
                nonlocal play_file
                play_file = asyncio.run(generate_tts(text, tts_file))
                
            tts_thread = None
            if sound_mode in ["full", "speech_only"] and text:
                logger.info(f"Starte TTS-Generierung asynchron für Text: {text}")
                tts_thread = threading.Thread(target=run_tts)
                tts_thread.start()

            if stop_event.is_set():
                alarm_queue.task_done()
                continue

            # Gong abspielen (während TTS im Hintergrund generiert wird)
            if str(gong_id) not in ["0", "-1"] and sound_mode != "speech_only":
                gong_file = os.path.join("gongs", f"{gong_id}.mp3")
                if os.path.exists(gong_file):
                    logger.info(f"Spiele Gong Datei: {gong_file}")
                    play_file_blocking(gong_file)
                
                if stop_event.is_set():
                    alarm_queue.task_done()
                    continue
                time.sleep(pause_sec)
                
            if tts_thread:
                # Warten, bis TTS-Generierung abgeschlossen ist, bevor die Durchsage startet
                tts_thread.join()

            # Durchsage abspielen
            if sound_mode in ["full", "speech_only"] and text and play_file:
                logger.info(f"Spiele TTS Durchsage Datei: {play_file}")
                play_file_blocking(play_file)
            elif sound_mode in ["full", "speech_only"] and text and not play_file:
                logger.error("Überspringe Sprachausgabe, da TTS Datei nicht fehlerfrei generiert werden konnte (FFmpeg fehlt?).")

            alarm_queue.task_done()

        except Exception as e:
            logger.error(f"Fehler im Audio-Worker-Ablauf: {e}")
            alarm_queue.task_done()

threading.Thread(target=worker_loop, daemon=True).start()

# =============================================================================
# 8. LOGIK & WIEDERHOLUNGEN
# =============================================================================

def get_test_alarm_payload(mission_id: str) -> dict:
    return {
        "id": mission_id,
        "type": "T SONDERLAGE,\nTest Einsatz",
        "additionalAddressInfo": "Burgplatz 1! Spittal an der Drau",
        "placeLAWZ": "Spittal an der Drau",
        "description": "Test der Alarmdurchsage.",
        "is_test": True
    }

def execute_repeated_announcement(mission_id):
    global active_timers
    with timers_lock:
        active_timers = [t for t in active_timers if t.is_alive()]

    if stop_event.is_set(): return

    if str(mission_id).startswith("test_alarm"):
        fresh_data = get_test_alarm_payload(mission_id)
    else:
        fresh_data = fetch_single_mission_details(mission_id)
        
    if fresh_data:
        text = create_announcement_text(fresh_data)
        logger.info(f"Spiele REPEAT Durchsage für ID {mission_id}.")
        cfg_live = load_config()
        alarm_mode = cfg_live.get("ui", {}).get("alarm_mode", "full")
        alarm_queue.put((text, -1, alarm_mode)) # -1 für keinen Gong bei Wiederholung

def process_alarm_logic(data_dict: dict):
    einsatz_id = data_dict.get("id")
    
    if einsatz_id and is_event_processed(einsatz_id) and not DEBUG:
        logger.info(f"Alarm mit ID {einsatz_id} ignoriert, da bereits verarbeitet (Duplikat).")
        return {"status": "Duplicate", "id": einsatz_id}

    logger.info(f"Verarbeite neuen Einsatz: ID {einsatz_id}, Typ: {data_dict.get('type')}")
    text = create_announcement_text(data_dict)
    
    dept_info = get_department_status_data()
    alerted = (dept_info and dept_info.get("state") == 2) or data_dict.get("is_test", False)
            
    gong_id = 1 if alerted else 2
    
    data_dict["durchsage_text"] = text
    data_dict["gong_used"] = gong_id
    
    # 1. Abspielen
    cfg_live = load_config()
    alarm_mode = cfg_live.get("ui", {}).get("alarm_mode", "full")
    alarm_queue.put((text, gong_id, alarm_mode))
    
    # 2. Loggen
    log_event(data_dict)
    
    # 3. Wiederholungen planen
    if alerted:
        cfg_live = load_config()
        
        # Webhook Aufruf
        webhook_url = cfg_live.get("webhook", {}).get("url", "")
        if webhook_url:
            def call_webhook(url):
                try:
                    logger.info(f"Rufe Webhook auf: {url}")
                    requests.get(url, timeout=5)
                except Exception as e:
                    logger.error(f"Fehler beim Webhook-Aufruf: {e}")
            threading.Thread(target=call_webhook, args=(webhook_url,), daemon=True).start()

        repeats = cfg_live.get("repeatAlert", []) 
        if repeats and isinstance(repeats, list):
            for minuten in repeats:
                try:
                    delay_sec = float(minuten) * 60
                    t = threading.Timer(delay_sec, execute_repeated_announcement, args=(einsatz_id,))
                    t.daemon = True
                    with timers_lock:
                        active_timers.append(t)
                    t.start()
                except ValueError: pass

    return {"status": "Processed", "gong": gong_id, "text": text}

# =============================================================================
# 9. SERVER & ENDPOINTS
# =============================================================================

def scheduled_reconnect_loop():
    cfg_live = load_config()
    hours = 19
    interval_seconds = hours * 3600
    
    while True:
        time.sleep(interval_seconds)
        if sio.connected:
            try:
                sio.disconnect()
            except Exception: pass

def login_external():
    cfg_live = load_config()
    try:
        resp = http_session.post(
            f"{cfg_live['credentials']['base_url']}/login",
            data={
                "username": cfg_live["credentials"]["username"],
                "password": cfg_live["credentials"]["password"],
                "persistent": "true",
                "sessionName": "DurchsageServer"
            },
            timeout=10
        )
        resp.raise_for_status()
        return True
    except Exception: return False

# --- WEB UI API ENDPOINTS ---

class LoginData(BaseModel):
    password: str

async def verify_session(session_token: Optional[str] = Cookie(None)):
    if session_token not in active_sessions:
        raise HTTPException(status_code=401, detail="Unauthorized")
    return True

@app.post("/api/login")
def api_login(data: LoginData, response: Response):
    cfg_live = load_config()
    if data.password == cfg_live["ui"]["password"]:
        token = secrets.token_hex(32)
        active_sessions.add(token)
        response.set_cookie(key="session_token", value=token, httponly=True, samesite='lax')
        return {"status": "ok", "password_changed": cfg_live["ui"]["password_changed"]}
    raise HTTPException(status_code=401, detail="Falsches Passwort")

@app.post("/api/logout")
def api_logout(response: Response, session_token: Optional[str] = Cookie(None)):
    if session_token in active_sessions:
        active_sessions.remove(session_token)
    response.delete_cookie("session_token")
    return {"status": "ok"}

@app.get("/api/auth_status")
def api_auth_status(session_token: Optional[str] = Cookie(None)):
    cfg_live = load_config()
    if session_token in active_sessions:
        return {"authenticated": True, "password_changed": cfg_live["ui"]["password_changed"]}
    return {"authenticated": False}

@app.post("/api/change_password", dependencies=[Depends(verify_session)])
def api_change_password(data: LoginData):
    if len(data.password) < 3:
        raise HTTPException(status_code=400, detail="Passwort zu kurz")
    cfg_live = load_config()
    cfg_live["ui"]["password"] = data.password
    cfg_live["ui"]["password_changed"] = True
    save_config(cfg_live)
    return {"status": "ok"}

@app.get("/api/config", dependencies=[Depends(verify_session)])
def api_get_config():
    cfg_live = load_config()
    # Passwort ausblenden
    cfg_live["ui"]["password"] = "***"
    return cfg_live

@app.post("/api/config", dependencies=[Depends(verify_session)])
def api_save_config(new_config: dict = Body(...)):
    cfg_live = load_config()
    # Neues Passwort wird nicht via config update gespeichert, sondern nur über change_password
    if "password" in new_config.get("ui", {}):
        new_config["ui"]["password"] = cfg_live["ui"]["password"]
    
    save_config(new_config)
    # Globale config aktualisieren, falls benötigt. Meistens laden wir sie on-the-fly.
    return {"status": "ok"}

@app.get("/api/history", dependencies=[Depends(verify_session)])
def api_history():
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return []

class AnnounceRequest(BaseModel):
    gong: int
    sound_mode: Optional[str] = "full"
    text: Optional[str] = None
    stichwort: Optional[str] = None
    schlagwort: Optional[str] = None
    strasse: Optional[str] = None
    ort: Optional[str] = None
    gemeinde: Optional[str] = None
    zusatzinfo: Optional[str] = None

@app.post("/api/announce", dependencies=[Depends(verify_session)])
def api_manual_announce(req: AnnounceRequest):
    final_text = req.text or ""
    
    cfg_live = load_config()
    is_alarm = False
    gongs = cfg_live.get("gongs", [])
    for g in gongs:
        if g["id"] == req.gong and g.get("is_alarm"):
            is_alarm = True
            break
            
    # Falls Einsatz-Modus mit Stichwort
    if is_alarm and req.stichwort:
        fake_payload = {
            "type": f"{req.stichwort}, {req.schlagwort or ''}".strip(", "),
            "additionalAddressInfo": f"{req.strasse or ''}! {req.ort or ''}".strip(),
            "placeLAWZ": req.gemeinde or "",
            "description": req.zusatzinfo or ""
        }
        final_text = create_announcement_text(fake_payload)
        
    log_payload = {
        "type": "Manuelle Durchsage" if not is_alarm else f"Manuell: {req.stichwort}, {req.schlagwort or ''}",
        "gong_used": req.gong,
        "additionalAddressInfo": req.text if not is_alarm else f"{req.strasse or ''}! {req.ort or ''}".strip(),
        "placeLAWZ": "" if not is_alarm else req.gemeinde or "",
        "description": req.text if not is_alarm else req.zusatzinfo or "",
        "durchsage_text": final_text
    }
    log_event(log_payload)
        
    alarm_queue.put((final_text, req.gong, req.sound_mode))
    return {"status": "Queued"}

class AlarmModeRequest(BaseModel):
    mode: str

@app.post("/api/settings/alarm_mode", dependencies=[Depends(verify_session)])
def api_settings_alarm_mode(req: AlarmModeRequest):
    cfg_live = load_config()
    if "ui" not in cfg_live: cfg_live["ui"] = {}
    cfg_live["ui"]["alarm_mode"] = req.mode
    save_config(cfg_live)
    return {"status": "ok", "mode": req.mode}

@app.post("/api/test_alarm", dependencies=[Depends(verify_session)])
def api_test_alarm():
    test_id = f"test_alarm_{int(time.time())}"
    data_dict = get_test_alarm_payload(test_id)
    process_alarm_logic(data_dict)
    return {"status": "ok"}

@app.delete("/api/queue", dependencies=[Depends(verify_session)])
def api_clear_queue():
    stop_event.set() 
    with alarm_queue.mutex:
        alarm_queue.queue.clear()
        
    with timers_lock:
        count = 0
        for t in active_timers:
            if t.is_alive():
                t.cancel()
                count += 1
        active_timers.clear()

    if pygame.mixer.get_init():
        pygame.mixer.music.stop()
        try: pygame.mixer.music.unload()
        except: pass
    
    logger.info(f"Warteschlange gelöscht! {count} aktive Timer beendet.")
    return {"status": "Stopped", "cancelled_timers": count}

@app.get("/api/audio_devices", dependencies=[Depends(verify_session)])
def api_get_audio_devices():
    try:
        import pygame._sdl2.audio as sdl2_audio
        pygame.init()
        devices = sdl2_audio.get_audio_device_names(False)
        return {"devices": devices}
    except Exception as e:
        logger.error(f"Fehler beim Abrufen der Audio-Geräte: {e}")
        return {"devices": []}

@app.get("/api/syslog", dependencies=[Depends(verify_session)])
def api_get_syslog():
    try:
        with open("system.log", "r", encoding="utf-8") as f:
            return Response(content=f.read(), media_type="text/plain")
    except Exception:
        return Response(content="Systemlog leer oder nicht gefunden.", media_type="text/plain")

@app.post("/api/reconnect", dependencies=[Depends(verify_session)])
def api_reconnect():
    global connection_error_msg, last_disconnect_time
    success = login_external()
    if success:
        connection_error_msg = None
        if sio.connected:
            sio.disconnect()
        return {"success": True}
    else:
        connection_error_msg = "Login fehlgeschlagen. Bitte Zugangsdaten für feuerwehreinsatz.info in den Einstellungen prüfen!"
        if last_disconnect_time is None:
            last_disconnect_time = time.time()
        return {"success": False, "error": connection_error_msg}

@app.post("/api/restart", dependencies=[Depends(verify_session)])
def api_restart():
    logger.warning("Benutzer hat System-Neustart angefordert. Beende Prozess in 1 Sekunde...")
    def do_restart():
        time.sleep(1)
        if platform.system() == "Windows":
            vbs_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "start_alarm_durchsage.vbs")
            if os.path.exists(vbs_path):
                os.startfile(vbs_path)
                os._exit(0)
            else:
                os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)])
        else:
            os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)])
    threading.Thread(target=do_restart, daemon=True).start()
    return {"status": "ok", "message": "Neustart eingeleitet..."}

@app.get("/api/is_active")
def api_is_active_mission():
    dept_info = get_department_status_data()
    if dept_info and dept_info.get("state") != 2:
        return Response(content="true", media_type="text/plain")
    return Response(content="false", media_type="text/plain")

@app.get("/api/system_status", dependencies=[Depends(verify_session)])
def api_system_status():
    import platform
    has_ffmpeg = shutil.which("ffmpeg") is not None
    
    crit_error = None
    if not sio.connected:
        if connection_error_msg:
            crit_error = connection_error_msg
        elif last_disconnect_time is not None and (time.time() - last_disconnect_time) > 20:
            crit_error = "Fehler: Keine Verbindung zu feuerwehreinsatz.info möglich (Timeout > 20s)."
            
    return {
        "ffmpeg_installed": has_ffmpeg,
        "os": platform.system(),
        "critical_error": crit_error
    }


@app.get("/api/gongs", dependencies=[Depends(verify_session)])
def api_get_gongs():
    cfg_live = load_config()
    return cfg_live.get("gongs", [])

@app.post("/api/gongs", dependencies=[Depends(verify_session)])
def api_add_gong(name: str = Form(...), is_alarm: bool = Form(...), file: UploadFile = File(...)):
    cfg_live = load_config()
    gongs = cfg_live.get("gongs", [])
    
    # Finde naechste verfuegbare ID
    max_id = 0
    for g in gongs:
        if g["id"] > max_id:
            max_id = g["id"]
    new_id = max_id + 1
    
    os.makedirs("gongs", exist_ok=True)
    file_path = os.path.join("gongs", f"{new_id}.mp3")
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    gongs.append({"id": new_id, "name": name, "is_alarm": is_alarm})
    cfg_live["gongs"] = gongs
    save_config(cfg_live)
    return {"status": "ok", "id": new_id}

@app.put("/api/gongs/{gong_id}", dependencies=[Depends(verify_session)])
def api_update_gong(gong_id: int, data: dict = Body(...)):
    cfg_live = load_config()
    gongs = cfg_live.get("gongs", [])
    for g in gongs:
        if g["id"] == gong_id:
            g["name"] = data.get("name", g["name"])
            g["is_alarm"] = data.get("is_alarm", g["is_alarm"])
            save_config(cfg_live)
            return {"status": "ok"}
    raise HTTPException(status_code=404, detail="Gong nicht gefunden")

@app.delete("/api/gongs/{gong_id}", dependencies=[Depends(verify_session)])
def api_delete_gong(gong_id: int):
    if gong_id in [1, 2]:
        raise HTTPException(status_code=400, detail="Einsatz- und Folgeeinsatz-Gong (1 und 2) duerfen nicht geloescht werden.")
        
    cfg_live = load_config()
    gongs = cfg_live.get("gongs", [])
    new_gongs = [g for g in gongs if g["id"] != gong_id]
    
    if len(new_gongs) == len(gongs):
        raise HTTPException(status_code=404, detail="Gong nicht gefunden")
        
    file_path = os.path.join("gongs", f"{gong_id}.mp3")
    if os.path.exists(file_path):
        os.remove(file_path)
        
    cfg_live["gongs"] = new_gongs
    save_config(cfg_live)
    return {"status": "ok"}

@app.post("/api/gongs/{gong_id}/audio", dependencies=[Depends(verify_session)])
def api_replace_gong_audio(gong_id: int, file: UploadFile = File(...)):
    cfg_live = load_config()
    if not any(g["id"] == gong_id for g in cfg_live.get("gongs", [])):
        raise HTTPException(status_code=404, detail="Gong nicht gefunden")
        
    os.makedirs("gongs", exist_ok=True)
    file_path = os.path.join("gongs", f"{gong_id}.mp3")
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"status": "ok"}

@app.post("/api/gongs/{gong_id}/reset", dependencies=[Depends(verify_session)])
def api_reset_gong(gong_id: int):
    if gong_id not in [1, 2]:
        raise HTTPException(status_code=400, detail="Nur Einsatz- und Folgeeinsatz-Gong (1 und 2) können auf Standard zurückgesetzt werden.")
        
    cfg_live = load_config()
    if not any(g["id"] == gong_id for g in cfg_live.get("gongs", [])):
        raise HTTPException(status_code=404, detail="Gong nicht gefunden")
        
    default_path = os.path.join("default_gongs", f"{gong_id}.mp3")
    if not os.path.exists(default_path):
        raise HTTPException(status_code=404, detail="Kein Standard-Gong für diese ID vorhanden.")
        
    target_path = os.path.join("gongs", f"{gong_id}.mp3")
    shutil.copyfile(default_path, target_path)
    return {"status": "ok"}

@app.get("/api/gongs/{gong_id}/audio")
def api_get_gong_audio(gong_id: int):
    filename = os.path.join("gongs", f"{gong_id}.mp3")
    if os.path.exists(filename):
        return FileResponse(filename, media_type="audio/mpeg")
    raise HTTPException(status_code=404, detail="Gong nicht gefunden")

# =============================================================================
# 9.5 NETWORK SETTINGS (LAN / WLAN)
# =============================================================================

@app.get("/api/network/status", dependencies=[Depends(verify_session)])
def api_get_network_status():
    system = platform.system()
    status = {"mode": "lan", "ssid": None}
    
    if system == "Windows":
        try:
            result = subprocess.check_output(['netsh', 'wlan', 'show', 'interfaces'], shell=True, text=True, encoding='cp850', errors='ignore')
            for line in result.splitlines():
                if "State" in line and "connected" in line:
                    status["mode"] = "wlan"
                elif "SSID" in line and "BSSID" not in line and ":" in line:
                    val = line.split(":", 1)[1].strip()
                    if val:
                        status["ssid"] = val
            if not status.get("ssid"):
                status["mode"] = "lan"
        except Exception:
            pass
            
    elif system == "Linux":
        try:
            result = subprocess.check_output(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE,CONNECTION', 'dev'], text=True)
            for line in result.splitlines():
                parts = line.split(':', 3)
                if len(parts) >= 4:
                    if parts[1] == 'wifi' and parts[2] == 'connected':
                        status["mode"] = "wlan"
                        status["ssid"] = parts[3].strip().replace('\\:', ':')
                        break
        except Exception:
            pass
            
    return status

@app.get("/api/network/wifi", dependencies=[Depends(verify_session)])
def api_get_wifi_networks():
    system = platform.system()
    networks = []
    
    if system == "Windows":
        try:
            result = subprocess.check_output(['netsh', 'wlan', 'show', 'networks'], shell=True, text=True, encoding='cp850', errors='ignore')
            for line in result.splitlines():
                if "SSID" in line and ":" in line:
                    ssid = line.split(":", 1)[1].strip()
                    if ssid and ssid not in networks:
                        networks.append(ssid)
        except Exception as e:
            logger.error(f"Fehler beim WLAN-Scan (Windows): {e}")
            
    elif system == "Linux":
        try:
            result = subprocess.check_output(['nmcli', '-t', '-f', 'SSID', 'dev', 'wifi'], text=True)
            for line in result.splitlines():
                ssid = line.strip()
                if ssid and ssid not in networks:
                    networks.append(ssid)
        except Exception as e:
            logger.error(f"Fehler beim WLAN-Scan (Linux). nmcli installiert?: {e}")
            
    return {"networks": networks}

class NetworkConnectRequest(BaseModel):
    mode: str
    ssid: Optional[str] = None
    password: Optional[str] = None

@app.post("/api/network/connect", dependencies=[Depends(verify_session)])
def api_network_connect(req: NetworkConnectRequest):
    system = platform.system()
    
    if req.mode == "lan":
        if system == "Windows":
            try:
                res = subprocess.run(['netsh', 'wlan', 'disconnect'], capture_output=True, text=True, encoding='cp850', errors='ignore')
                if res.returncode != 0:
                    raise Exception(res.stdout + res.stderr)
                return {"status": "ok", "message": "WLAN getrennt. LAN wird verwendet."}
            except Exception as e:
                raise HTTPException(status_code=500, detail=str(e))
        elif system == "Linux":
            try:
                subprocess.check_call(['nmcli', 'radio', 'wifi', 'off'])
                return {"status": "ok", "message": "WLAN deaktiviert. LAN wird verwendet."}
            except Exception as e:
                raise HTTPException(status_code=500, detail=str(e))
                
    elif req.mode == "wlan":
        if not req.ssid:
            raise HTTPException(status_code=400, detail="SSID fehlt.")
            
        if system == "Windows":
            # XML Escape um Fehler bei Sonderzeichen (&, <, >) im WLAN-Namen oder Passwort zu verhindern
            safe_ssid = xml.sax.saxutils.escape(req.ssid)
            safe_password = xml.sax.saxutils.escape(req.password or "")
            
            xml_profile = f"""<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>{safe_ssid}</name>
    <SSIDConfig>
        <SSID>
            <name>{safe_ssid}</name>
        </SSID>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>{safe_password}</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>"""
            try:
                profile_path = "temp_wifi_profile.xml"
                with open(profile_path, "w", encoding="utf-8") as f:
                    f.write(xml_profile)
                
                res_add = subprocess.run(['netsh', 'wlan', 'add', 'profile', f'filename={profile_path}'], capture_output=True, text=True, encoding='cp850', errors='ignore')
                if res_add.returncode != 0:
                    raise Exception(f"Profile add failed: {res_add.stdout} {res_add.stderr}")
                    
                os.remove(profile_path)
                
                res_conn = subprocess.run(['netsh', 'wlan', 'connect', f'name={req.ssid}'], capture_output=True, text=True, encoding='cp850', errors='ignore')
                if res_conn.returncode != 0:
                    raise Exception(f"Connect failed: {res_conn.stdout} {res_conn.stderr}")
                    
                return {"status": "ok", "message": f"Verbinde mit {req.ssid}..."}
            except Exception as e:
                if os.path.exists("temp_wifi_profile.xml"):
                    os.remove("temp_wifi_profile.xml")
                raise HTTPException(status_code=500, detail=f"WLAN Fehler (Windows): {e}")
                
        elif system == "Linux":
            try:
                subprocess.check_call(['nmcli', 'radio', 'wifi', 'on'])
                cmd = ['nmcli', 'dev', 'wifi', 'connect', req.ssid]
                if req.password:
                    cmd.extend(['password', req.password])
                subprocess.check_call(cmd)
                return {"status": "ok", "message": f"Erfolgreich mit {req.ssid} verbunden."}
            except Exception as e:
                raise HTTPException(status_code=500, detail=f"WLAN Fehler (Linux): {e}")
                
    raise HTTPException(status_code=400, detail="Unbekannter Modus")

# Statische Dateien einbinden (muss am Ende stehen!)
os.makedirs("static", exist_ok=True)
app.mount("/", StaticFiles(directory="static", html=True), name="static")

# =============================================================================
# 10. STARTUP
# =============================================================================

def start_socket_service():
    global connection_error_msg, last_disconnect_time
    while True:
        if login_external():
            connection_error_msg = None
            cookies = http_session.cookies.get_dict()
            cookie_str = "; ".join([f"{k}={v}" for k, v in cookies.items()])
            try:
                cfg_live = load_config()
                sio.connect(
                    cfg_live["credentials"]["base_url"],
                    headers={"Cookie": cookie_str}
                )
                sio.wait()
            except Exception as e:
                logger.error(f"Socket.io Verbindung getrennt oder Fehler: {e}")
                if sio.connected:
                    sio.disconnect()
        else:
            connection_error_msg = "Login fehlgeschlagen. Bitte Zugangsdaten für feuerwehreinsatz.info in den Einstellungen prüfen!"
            if last_disconnect_time is None:
                last_disconnect_time = time.time()
        time.sleep(5)


if __name__ == "__main__":
    logger.info("--- ALARM SERVER GESTARTET ---")
    
    t_socket = threading.Thread(target=start_socket_service, daemon=True)
    t_socket.start()

    t_reconnect = threading.Thread(target=scheduled_reconnect_loop, daemon=True)
    t_reconnect.start()

    cfg_live = load_config()
    uvicorn.run(app, host=cfg_live["server"]["host"], port=cfg_live["ui"]["port"], log_level="error")
