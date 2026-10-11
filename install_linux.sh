#!/bin/bash
set -e

KEEP_NETWORK=true

for arg in "$@"; do
    if [ "$arg" == "--install-networkmanager" ]; then
        KEEP_NETWORK=false
    fi
done

# Log-Datei für die Installation anlegen (schreibt in die Konsole und in die Datei gleichzeitig)
if [ "$EUID" -eq 0 ] || [ -w /var/log ]; then
    LOG_FILE="/var/log/alarmdurchsage_install.log"
else
    LOG_FILE="/tmp/alarmdurchsage_install.log"
fi
exec > >(tee -i "$LOG_FILE") 2>&1

# System- und Hardware-Erkennung
ARCH=$(uname -m)
IS_RPI=false
IS_DIETPI=false

if [ -f /boot/dietpi/func/dietpi-set_hardware ] || [ -f /boot/dietpi.txt ]; then
    IS_DIETPI=true
fi

if ([ -f /proc/device-tree/model ] && grep -qi "Raspberry Pi" /proc/device-tree/model) || [ "$IS_DIETPI" = true ]; then
    IS_RPI=true
fi

echo "====================================================="
echo " Alarmdurchsage - Linux Installer"
if [ "$IS_DIETPI" = true ]; then
    echo " (Erkannt: DietPi-System / $ARCH)"
elif [ "$IS_RPI" = true ]; then
    echo " (Erkannt: Raspberry Pi / $ARCH)"
else
    echo " (Erkannt: Standard Linux PC / $ARCH)"
fi
echo "====================================================="

# 1. Grundlegende Werkzeuge prüfen und installieren
echo ">>> [1/6] Prüfe Basis-Werkzeuge..."

PACKAGES_TO_INSTALL=""

if ! command -v git &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL git"
fi

if ! command -v curl &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL curl"
fi

if [ "$KEEP_NETWORK" = false ]; then
    if ! command -v nmcli &> /dev/null; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL network-manager"
    fi

    if ! command -v wpa_supplicant &> /dev/null; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL wpasupplicant wireless-tools iw rfkill"
    fi
fi

if ! command -v aplay &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL alsa-utils"
fi

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installiere fehlende Pakete: $PACKAGES_TO_INSTALL"
    sudo apt-get update -y
    sudo apt-get install -y $PACKAGES_TO_INSTALL
else
    echo "Alle Basis-Werkzeuge sind bereits installiert!"
fi

if [ "$KEEP_NETWORK" = false ]; then
    if [ "$IS_DIETPI" = true ]; then
        # 1.5 DietPi Netzwerk-Architektur auf "Pure NetworkManager" umbauen
        echo ">>> [1.5/6] Konfiguriere NetworkManager als alleinigen Herrscher (DietPi)..."

        # ifupdown entmachten (DietPis alte Netzwerkkontrolle deaktivieren)
        if [ -f /etc/network/interfaces ]; then
            if ! grep -q "Pure NetworkManager Setup" /etc/network/interfaces; then
                echo "Sichere alte DietPi Netzwerk-Konfiguration..."
                sudo cp /etc/network/interfaces /etc/network/interfaces.bak
                
                echo "Lösche ifupdown-Konfiguration für eth0 und wlan0..."
                sudo bash -c 'cat << EOF > /etc/network/interfaces
# Pure NetworkManager Setup
# Diese Datei wurde geleert, damit der NetworkManager die volle Kontrolle
# über alle LAN-Kabel und WLAN-Chips übernehmen kann.
auto lo
iface lo inet loopback
EOF'
            fi
        fi

        # NetworkManager zwingen, die Verwaltung zu übernehmen
        if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
            echo "Setze managed=true im NetworkManager, um alles zu übernehmen..."
            sudo sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
        fi

        echo "Starte NetworkManager neu (LAN-Verbindung könnte kurz abbrechen)..."
        sudo systemctl enable NetworkManager || true
        sudo systemctl restart NetworkManager || true

        # 1.5.1 DietPi Blacklists und Hardware-Sperren (Device-Tree) restlos entfernen
        echo ">>> [1.5/6b] Entferne DietPi-Kernel-Blockaden (Blacklists & Overlays)..."

        # Entferne Hardware-Sperre in den Boot-Konfigurationen (sonst sagt NM "hardware missing")
        for CONFIG_FILE in /boot/config.txt /boot/firmware/config.txt /boot/dietpi.txt; do
            if [ -f "$CONFIG_FILE" ]; then
                if grep -q "disable-wifi" "$CONFIG_FILE"; then
                    echo "Entferne WLAN-Hardwaresperre in $CONFIG_FILE..."
                    sudo sed -i 's/^.*disable-wifi.*$/#dtoverlay=disable-wifi/g' "$CONFIG_FILE"
                fi
            fi
        done

        # DietPi blockiert WLAN und Audio per modprobe-Blacklist, wenn in dietpi.txt nicht aktiviert
        sudo rm -f /etc/modprobe.d/dietpi-disable_wifi.conf 2>/dev/null || true
        sudo rm -f /etc/modprobe.d/dietpi-disable_audio.conf 2>/dev/null || true
        sudo rm -f /etc/modprobe.d/dietpi-disable_bluetooth.conf 2>/dev/null || true

        # 1.6 DietPi WLAN-Sperre aufheben & einfachen Wachhund installieren
        echo ">>> [1.6/6] Installiere permanenten WLAN-Wachhund für Reboots..."
        sudo rfkill unblock wifi || true
        sudo rfkill unblock wlan || true
        if command -v nmcli &> /dev/null; then
            sudo nmcli radio wifi on || true
        fi

        # Erstelle einen Systemdienst, der sicherstellt, dass DietPi beim Booten das WLAN nicht hardwareseitig sperrt
        cat << 'EOF' | sudo tee /etc/systemd/system/alarm-network-fix.service
[Unit]
Description=Alarmdurchsage Network Fix for DietPi
After=network.target dietpi-postboot.service NetworkManager.service docker.service

[Service]
Type=oneshot
# Entsperre WLAN Hardware (rfkill), bringe wlan0 hoch und schalte Radio an
ExecStart=/bin/bash -c 'rfkill unblock wifi || true; rfkill unblock wlan || true; ip link set wlan0 up || true; nmcli dev set wlan0 managed yes || true; nmcli radio wifi on || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload
        sudo systemctl enable alarm-network-fix.service
        sudo systemctl start alarm-network-fix.service
    else
        echo ">>> [1.5 - 1.6/6] Standard-Linux erkannt. DietPi-Netzwerkmodifikationen werden übersprungen..."
    fi
else
    echo ">>> [1.5 - 1.6/6] Überspringe Netzwerk-Konfiguration (NetworkManager wird nicht verändert)..."
fi

# 1.7 Audio vollautomatisch aktivieren
echo ">>> [1.7/6] Prüfe Audio-Konfiguration..."

if [ "$IS_RPI" = true ]; then
    echo "Raspberry Pi erkannt. Konfiguriere Onboard-Audio..."
    if [ -f /boot/dietpi/func/dietpi-set_hardware ]; then
        echo "DietPi-Konfigurationswerkzeug gefunden."
        PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null || true)
        echo "Erkanntes Mainboard-Modell: $PI_MODEL"
        
        echo "Aktiviere automatische Audio-Erkennung (HDMI / 3.5mm) für alle Modelle..."
        sudo /boot/dietpi/func/dietpi-set_hardware soundcard rpi-bcm2835-auto || true
    fi

    # Fallback für Standard-Betriebssystem (Raspberry Pi OS)
    for CONFIG_FILE in /boot/config.txt /boot/firmware/config.txt; do
        if [ -f "$CONFIG_FILE" ]; then
            if ! grep -q "^dtparam=audio=on" "$CONFIG_FILE"; then
                echo "Aktiviere Audio-Fallback in $CONFIG_FILE"
                echo "dtparam=audio=on" | sudo tee -a "$CONFIG_FILE"
            fi
        fi
    done

    # Kernel-Modul in den Autostart (beim Booten) eintragen
    if ! grep -q "^snd_bcm2835" /etc/modules 2>/dev/null; then
        echo "Füge snd_bcm2835 zu /etc/modules hinzu..."
        echo "snd_bcm2835" | sudo tee -a /etc/modules
    fi

    # Kernel-Modul SOFORT laden (wichtig für die erste Docker-Ausführung, sonst fehlt /dev/snd)
    echo "Lade Soundkarten-Treiber (snd_bcm2835)..."
    sudo modprobe snd_bcm2835 || true
else
    echo "Standard-Linux-System erkannt ($ARCH). Raspberry Pi Audio-Treiber werden übersprungen."
fi

# 2. Container-Laufzeit (Docker / Podman) prüfen
echo ">>> [2/6] Prüfe Container-Laufzeit (Docker / Podman)..."

IS_PODMAN=false
if command -v podman &> /dev/null; then
    if ! systemctl list-unit-files docker.service 2>/dev/null | grep -q "docker.service" || (docker --version 2>&1 | grep -qi "podman"); then
        IS_PODMAN=true
    fi
fi

if ! command -v docker &> /dev/null && [ "$IS_PODMAN" = false ]; then
    echo "Docker nicht gefunden. Installiere Docker jetzt..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo "Füge den aktuellen Benutzer zur Docker-Gruppe hinzu..."
    sudo usermod -aG docker $USER
else
    if [ "$IS_PODMAN" = true ]; then
        echo "Podman ist installiert und wird als Container-Laufzeit verwendet."
    else
        echo "Docker ist bereits installiert!"
    fi
fi

if [ "$IS_PODMAN" = true ]; then
    echo "Aktiviere Podman-Socket für Docker-Compose-Kompatibilität..."
    sudo systemctl enable --now podman.socket || true
    if [ ! -e /var/run/docker.sock ] && [ -S /run/podman/podman.sock ]; then
        sudo ln -s /run/podman/podman.sock /var/run/docker.sock 2>/dev/null || true
    fi
else
    echo "Stelle sicher, dass Docker beim Systemstart aktiviert ist..."
    if systemctl list-unit-files docker.service 2>/dev/null | grep -q "docker.service"; then
        sudo systemctl enable docker || true
        sudo systemctl start docker || true
    fi
fi

# Compose-Befehl ermitteln
COMPOSE_CMD=""
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
else
    COMPOSE_CMD="docker compose"
fi

# 3. Projektverzeichnis ermitteln
echo ">>> [3/6] Prüfe Projektverzeichnis..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

if [ -f "$SCRIPT_DIR/docker-compose.yml" ] && [ -f "$SCRIPT_DIR/durchsage.py" ]; then
    INSTALL_DIR="$SCRIPT_DIR"
    echo "Installationsskript wird direkt im Projektordner ausgeführt: $INSTALL_DIR"
else
    INSTALL_DIR="$HOME/alarm_durchsage"
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "Klone Projekt nach $INSTALL_DIR..."
        git clone https://github.com/Jupiter79/alarm_durchsage.git "$INSTALL_DIR"
    else
        echo "Verzeichnis existiert bereits. Hole neueste Updates..."
        cd "$INSTALL_DIR"
        git pull || true
    fi
fi

cd "$INSTALL_DIR"

# 4. Fehlerhafte Ordner löschen und Log-Dateien sauber anlegen
echo ">>> [4/6] Bereite Konfiguration und Logs vor..."
rm -rf system.log log.json 2>/dev/null || true
touch system.log log.json
echo "NETWORK_MANAGEMENT_DISABLED=$KEEP_NETWORK" > .env

# Audio-Konfiguration ermitteln
if [ -e /dev/snd ]; then
    AUDIO_DEVICE_MOUNT="/dev/snd:/dev/snd"
else
    AUDIO_DEVICE_MOUNT="/dev/null:/tmp/dummy_snd"
fi
PULSE_SOCKET_MOUNT="/dev/null:/tmp/dummy_pulse"
PULSE_COOKIE_MOUNT="/dev/null:/tmp/dummy_cookie"
SDL_AUDIODRIVER="alsa"
PULSE_SERVER=""

if pgrep -x "pulseaudio" > /dev/null || pgrep -x "pipewire" > /dev/null || pgrep -x "pipewire-pulse" > /dev/null; then
    echo ">>> Desktop-Audio (PulseAudio/Pipewire) erkannt. Passe Docker an..."
    
    # Finde den aktiven Desktop-Benutzer
    if [ -n "$SUDO_USER" ]; then
        DESKTOP_USER=$SUDO_USER
    else
        DESKTOP_USER=$(who | awk '{print $1}' | head -n 1)
        [ -z "$DESKTOP_USER" ] && DESKTOP_USER=$USER
    fi
    USER_ID=$(id -u "$DESKTOP_USER" 2>/dev/null || echo 1000)
    
    if [ -S "/run/user/$USER_ID/pulse/native" ]; then
        echo ">>> Konfiguriere PulseAudio Passthrough für Benutzer $DESKTOP_USER (ID $USER_ID)..."
        PULSE_SOCKET_MOUNT="/run/user/$USER_ID/pulse:/run/user/$USER_ID/pulse"
        PULSE_SERVER="unix:/run/user/$USER_ID/pulse/native"
        SDL_AUDIODRIVER="pulse"
        
        # Cookie mapping für Authentifizierung
        PULSE_COOKIE_FILE="$(eval echo ~$DESKTOP_USER)/.config/pulse/cookie"
        if [ -f "$PULSE_COOKIE_FILE" ]; then
            PULSE_COOKIE_MOUNT="$PULSE_COOKIE_FILE:/root/.config/pulse/cookie:ro"
        fi
    fi
fi

echo "AUDIO_DEVICE_MOUNT=$AUDIO_DEVICE_MOUNT" >> .env
echo "PULSE_SOCKET_MOUNT=$PULSE_SOCKET_MOUNT" >> .env
echo "PULSE_COOKIE_MOUNT=$PULSE_COOKIE_MOUNT" >> .env
echo "SDL_AUDIODRIVER=$SDL_AUDIODRIVER" >> .env
if [ -n "$PULSE_SERVER" ]; then
    echo "PULSE_SERVER=$PULSE_SERVER" >> .env
fi

# 5. Docker Container bauen und starten
echo ">>> [5/6] Baue und starte den Container (Linux-Profil mit Audio)..."
sudo $COMPOSE_CMD --profile pi up -d --build

# 6. Abschlussmeldung
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
[ -z "$IP_ADDR" ] && IP_ADDR="localhost"

echo "====================================================="
echo " INSTALLATION ABGESCHLOSSEN!"
echo "====================================================="
echo " Der Container ist fertig eingerichtet."
echo " Die Weboberfläche ist erreichbar unter:"
echo " -> http://${IP_ADDR}:8122"
echo " -> http://localhost:8122"
if [ "$IS_RPI" = true ]; then
    echo " -> http://alarmdurchsage.local:8122"
    echo ""
    echo " Auf dem Raspberry Pi wird ein Neustart empfohlen,"
    echo " damit Audio-Treiber und Einstellungen vollständig aktiv sind."
    echo "====================================================="
    read -p " Möchtest du das System jetzt neustarten? (j/N): " -r REBOOT_REPLY
    if [[ "$REBOOT_REPLY" =~ ^[jJyY]$ ]]; then
        echo " Das System startet neu..."
        sudo reboot
    else
        echo " Neustart übersprungen. Du kannst die Weboberfläche nun nutzen."
    fi
else
    echo ""
    echo " Du kannst die Weboberfläche nun direkt im Browser aufrufen."
    echo "====================================================="
fi