let currentConfig = null;

// --- Initialization & Auth ---
document.addEventListener('DOMContentLoaded', () => {
    checkAuth();

    document.getElementById('form-login').addEventListener('submit', async (e) => {
        e.preventDefault();
        const pwd = document.getElementById('login-password').value;
        try {
            const res = await fetch('/api/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ password: pwd })
            });
            if (res.ok) {
                const data = await res.json();
                localStorage.setItem('durchsage_pwd', pwd);
                handleLoginSuccess(data.password_changed);
            } else {
                showLoginError('Falsches Passwort.');
            }
        } catch (e) {
            showLoginError('Netzwerkfehler.');
        }
    });

    document.getElementById('form-change-password').addEventListener('submit', async (e) => {
        e.preventDefault();
        const pwd1 = document.getElementById('new-password').value;
        const pwd2 = document.getElementById('new-password-confirm').value;

        if (pwd1 !== pwd2) {
            showCpError('Passwörter stimmen nicht überein.');
            return;
        }

        try {
            const res = await fetch('/api/change_password', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ password: pwd1 })
            });
            if (res.ok) {
                localStorage.setItem('durchsage_pwd', pwd1);
                showView('view-app');
                initApp();
            } else {
                showCpError('Fehler beim Speichern.');
            }
        } catch (e) {
            showCpError('Netzwerkfehler.');
        }
    });

    // Formulare umschalten basierend auf Gong
    window.updateFormFields = function () {
        const val = parseInt(document.getElementById('announce-gong').value);
        let isAlarm = false;

        if (currentConfig && currentConfig.gongs) {
            const gongInfo = currentConfig.gongs.find(g => g.id === val);
            if (gongInfo && gongInfo.is_alarm) {
                isAlarm = true;
            }
        } else if ([1, 2, 3].includes(val)) {
            // Fallback while config is loading
            isAlarm = true;
        }

        const $einsatz = $('#einsatz-container');
        const $text = $('#text-container');
        const $btn = $('#submit-announce-btn');

        if (isAlarm) {
            $text.hide();
            $einsatz.show();
            $('#announce-text').prop('required', false);
            $('#announce-stichwort, #announce-schlagwort, #announce-strasse, #announce-ort, #announce-gemeinde').prop('required', true);
            $btn.addClass('btn-danger').removeClass('btn-primary').text('Alarmdurchsage durchführen');
        } else {
            $text.show();
            $einsatz.hide();
            $('#announce-text').prop('required', true);
            $('#announce-stichwort, #announce-schlagwort, #announce-strasse, #announce-ort, #announce-gemeinde').prop('required', false);
            $btn.addClass('btn-primary').removeClass('btn-danger').text('Durchsage durchführen');
        }
    };
    // Init state
    if (document.getElementById('announce-gong')) {
        updateFormFields();
    }

    // Submit Announce
    document.getElementById('form-announce').addEventListener('submit', async (e) => {
        e.preventDefault();
        const gong = parseInt(document.getElementById('announce-gong').value);
        const isAlarm = [1, 2, 3].includes(gong);

        let body = { gong: gong };

        if (isAlarm) {
            body.stichwort = document.getElementById('announce-stichwort').value.trim();
            body.schlagwort = document.getElementById('announce-schlagwort').value.trim();
            body.strasse = document.getElementById('announce-strasse').value.trim();
            body.ort = document.getElementById('announce-ort').value.trim();
            body.gemeinde = document.getElementById('announce-gemeinde').value.trim();
            body.zusatzinfo = document.getElementById('announce-zusatzinfo').value.trim();
        } else {
            body.text = document.getElementById('announce-text').value.trim();
        }

        try {
            const res = await fetch('/api/announce', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(body)
            });
            if (res.ok) {
                alert('Erfolgreich ausgelöst!');
            } else {
                alert('Fehler beim Auslösen.');
            }
        } catch (e) {
            alert('Netzwerkfehler beim Auslösen.');
        }
    });

    // Auto-save Alarm Mode on radio change
    $('input[name="alarm_mode"]').on('change', async function () {
        const mode = $(this).val();
        try {
            const res = await fetch('/api/settings/alarm_mode', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ mode: mode })
            });
            if (!res.ok) alert('Fehler beim Speichern des Modus.');
        } catch (e) { }
    });

    if (document.getElementById('form-upload-gong')) {
        document.getElementById('form-upload-gong').addEventListener('submit', async (e) => {
            e.preventDefault();
            const name = document.getElementById('new-gong-name').value;
            const isAlarm = document.getElementById('new-gong-alarm').value === "true";
            const fileInput = document.getElementById('new-gong-file');

            if (fileInput.files.length === 0) return;

            const formData = new FormData();
            formData.append('name', name);
            formData.append('is_alarm', isAlarm);
            formData.append('file', fileInput.files[0]);

            try {
                const res = await fetch('/api/gongs', {
                    method: 'POST',
                    body: formData
                });
                if (res.ok) {
                    document.getElementById('form-upload-gong').reset();
                    loadGongs();
                    loadConfig(); // Refresh dropdown
                } else {
                    alert("Fehler beim Hochladen.");
                }
            } catch (err) {
                alert("Netzwerkfehler beim Hochladen.");
            }
        });
    }
});

async function checkAuth() {
    try {
        const res = await fetch('/api/auth_status');
        const data = await res.json();
        if (data.authenticated) {
            handleLoginSuccess(data.password_changed);
            return;
        }
    } catch (e) {
        console.error("Auth status error:", e);
    }

    const localPwd = localStorage.getItem('durchsage_pwd');
    if (localPwd) {
        try {
            const loginRes = await fetch('/api/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ password: localPwd })
            });
            if (loginRes.ok) {
                const data = await loginRes.json();
                handleLoginSuccess(data.password_changed);
                return;
            } else {
                localStorage.removeItem('durchsage_pwd');
            }
        } catch (e) {
            console.error("Auto-login error:", e);
        }
    }

    showView('view-login');
}

function handleLoginSuccess(passwordChanged) {
    if (!passwordChanged) {
        showView('view-change-password');
    } else {
        showView('view-app');
        initApp();
    }
}

async function logout() {
    localStorage.removeItem('durchsage_pwd');
    await fetch('/api/logout', { method: 'POST' });
    showView('view-login');
    document.getElementById('login-password').value = '';
}

// --- UI Navigation ---
function showView(viewId) {
    document.querySelectorAll('.view-section').forEach(v => v.classList.remove('active'));
    document.getElementById(viewId).classList.add('active');
}

function switchTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(t => t.style.display = 'none');
    document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));

    document.getElementById(`tab-${tabId}`).style.display = 'block';
    const targetLink = Array.from(document.querySelectorAll('.nav-link')).find(l => l.innerText.toLowerCase().includes(tabId.toLowerCase()));
    if (targetLink) targetLink.classList.add('active');

    if (tabId === 'config') loadConfig();
    if (tabId === 'logs') loadLogs();
    if (tabId === 'gongs') loadGongs();
}

function showLoginError(msg) {
    const el = document.getElementById('login-error');
    el.innerText = msg;
    el.style.display = 'block';
}

function showCpError(msg) {
    const el = document.getElementById('cp-error');
    el.innerText = msg;
    el.style.display = 'block';
}

// --- App Logic ---
async function checkSystemStatus() {
    try {
        const res = await fetch('/api/system_status');
        if (res.ok) {
            const status = await res.json();

            if (status.critical_error) {
                document.getElementById('crit-error-msg').innerText = status.critical_error;
                document.getElementById('crit-error-alert').style.display = 'block';
            } else {
                const ce = document.getElementById('crit-error-alert');
                if (ce) ce.style.display = 'none';
            }

            if (!status.ffmpeg_installed) {
                document.getElementById('ffmpeg-warning').style.display = 'block';
                // Disable manual announce button
                const announceBtn = document.getElementById('submit-announce-btn');
                if (announceBtn) {
                    announceBtn.disabled = true;
                    announceBtn.innerHTML = '<i class="fa-solid fa-triangle-exclamation"></i> FFmpeg fehlt';
                    announceBtn.classList.replace('btn-primary', 'btn-secondary');
                }

                if (status.os === 'Windows') {
                    document.getElementById('ffmpeg-cmd-win').style.display = 'block';
                    document.getElementById('ffmpeg-cmd-lin').style.display = 'none';
                } else {
                    document.getElementById('ffmpeg-cmd-win').style.display = 'none';
                    document.getElementById('ffmpeg-cmd-lin').style.display = 'block';
                }
            } else {
                document.getElementById('ffmpeg-warning').style.display = 'none';
                const announceBtn = document.getElementById('submit-announce-btn');
                if (announceBtn) {
                    announceBtn.disabled = false;
                    announceBtn.innerHTML = 'Durchsage durchführen';
                    announceBtn.classList.replace('btn-secondary', 'btn-primary');
                }
            }
        }
    } catch (e) { }
}

async function initApp() {
    document.getElementById('status-badge').className = 'badge-status success me-3';
    document.getElementById('status-badge').innerText = 'Verbunden';

    // Check system capabilities like FFmpeg and Connection Error periodically
    await checkSystemStatus();
    setInterval(checkSystemStatus, 5000);

    // Load config to set alarm mode initially
    await loadConfig();
}

async function clearQueue() {
    try {
        const res = await fetch('/api/queue', { method: 'DELETE' });
        if (res.ok) alert('Alle Ausgaben (inkl. Sprachausgabe und Gongs) gestoppt!');
    } catch (e) { }
}

function previewGongId(id) {
    const audio = document.getElementById('audio-preview');
    audio.src = `/api/gongs/${id}/audio`;
    audio.play().catch(e => alert("Gong-Datei nicht gefunden oder Fehler beim Abspielen."));
}

function previewGong() {
    const gongId = document.getElementById('announce-gong').value;
    if (gongId == "0" || gongId == "-1") return;

    previewGongId(gongId);
}

let availableAudioDevices = [];

// --- Config Management ---
async function loadConfig() {
    try {
        const res = await fetch('/api/config');
        if (res.ok) {
            currentConfig = await res.json();

            try {
                const devRes = await fetch('/api/audio_devices');
                if (devRes.ok) {
                    const data = await devRes.json();
                    availableAudioDevices = data.devices || [];
                }
            } catch (e) { }

            renderConfigEditor();
            populateGongsSelect();

            // Set alarm_mode radio button
            const mode = currentConfig.ui?.alarm_mode || 'full';
            const radio = document.querySelector(`input[name="alarm_mode"][value="${mode}"]`);
            if (radio) radio.checked = true;
        }
    } catch (e) { }
}

function renderConfigEditor() {
    const container = document.getElementById('config-editor-container');
    container.innerHTML = '';

    if (!currentConfig) return;

    const createInput = (label, path, value, type = "text", helpText = "", advanced = false) => {
        const advancedClass = advanced ? 'advanced-input' : '';
        return `
            <div class="mb-3">
                <label class="form-label ${advanced ? 'text-muted' : ''}">${label}</label>
                <input type="${type}" class="form-control ${advancedClass}" data-path="${path}" value="${value}">
                ${helpText ? `<div class="form-text">${helpText}</div>` : ''}
            </div>
        `;
    };

    const createSelect = (label, path, value, options, helpText = "", advanced = false) => {
        const advancedClass = advanced ? 'advanced-input' : '';
        let optionsHtml = '<option value="">Standardgerät (Keines explizit ausgewählt)</option>';

        let found = false;
        options.forEach(opt => {
            const isSelected = (opt === value) ? 'selected' : '';
            if (opt === value) found = true;
            optionsHtml += `<option value="${opt}" ${isSelected}>${opt}</option>`;
        });

        if (value && !found) {
            optionsHtml += `<option value="${value}" selected>${value} (Aktuell konfiguriert, aber offline?)</option>`;
        }

        return `
            <div class="mb-3">
                <label class="form-label ${advanced ? 'text-muted' : ''}">${label}</label>
                <select class="form-select ${advancedClass}" data-path="${path}">
                    ${optionsHtml}
                </select>
                ${helpText ? `<div class="form-text">${helpText}</div>` : ''}
            </div>
        `;
    };

    const createDictEditor = (title, path, obj, helpText = "") => {
        let rows = '';
        for (let key in obj) {
            rows += `
                <div class="d-flex mb-2 gap-2 dict-row" data-path="${path}">
                    <input type="text" class="form-control dict-key" value="${key}" placeholder="Schlüssel">
                    <input type="text" class="form-control dict-val" value="${obj[key]}" placeholder="Wert">
                    <button type="button" class="btn btn-outline-danger" onclick="this.parentElement.remove()"><i class="fa-solid fa-trash"></i></button>
                </div>
            `;
        }
        return `
            <div class="config-group">
                <h5 class="text-primary mb-3">${title}</h5>
                ${helpText ? `<p class="text-muted small">${helpText}</p>` : ''}
                <div id="container-${path.replace('.', '-')}">${rows}</div>
                <button type="button" class="btn btn-sm btn-outline-primary mt-2" onclick="addDictRow('container-${path.replace('.', '-')}', '${path}')">+ Eintrag hinzufügen</button>
            </div>
        `;
    };

    let html = '';

    // UI & Server
    html += '<div class="config-group"><h5 class="text-primary mb-3">🖥️ System & Web-UI</h5>';
    html += createInput('Web UI Port', 'ui.port', currentConfig.ui.port, 'number', 'Auf welchem Port soll diese Webseite laufen? (Standard ist 80 (erreichbar unter http://alarmdurchsage.local). Beispiel: Wenn hier 5000 steht, erreichst du die Seite unter http://alarmdurchsage.local:5000. ACHTUNG: Nach einer Änderung muss das Programm komplett neu gestartet werden!)');
    html += createInput('DNS Name (mDNS)', 'server.dns_name', currentConfig.server?.dns_name || 'alarmdurchsage', 'text', 'Unter welchem Namen soll das System im Netzwerk erreichbar sein? ACHTUNG: Nach einer Änderung muss das Programm komplett neu gestartet werden!)');
    html += createInput('Log Aufbewahrung (Tage)', 'logging.retention_days', currentConfig.logging.retention_days, 'number', 'Wie viele Tage sollen vergangene Einsätze in der Historie sichtbar bleiben, bevor sie automatisch gelöscht werden? (Gib -1 ein für unendlich. Empfohlen: 365)');
    html += '</div>';

    // UI
    html += '<div class="config-group"><h5 class="text-primary mb-3">🔒 Web-Interface</h5>';
    html += createInput('Login-Passwort', 'ui.password', currentConfig.ui?.password || 'admin', 'password', 'Das Passwort, um diese Oberfläche zu öffnen (Standard: admin).');
    html += '</div>';

    // Connection
    html += '<div class="config-group"><h5 class="text-primary mb-3">🌍 Verbindung zum FWEI-Server (Leitstellenverbund Kärnten)</h5>';

    let baseUrl = currentConfig.credentials.base_url || 'https://feuerwehr.einsatz.or.at';
    let isCustomUrl = baseUrl !== 'https://feuerwehr.einsatz.or.at';
    html += `
        <div class="mb-3">
            <label class="form-label text-muted">Serveradresse</label>
            <select class="form-select advanced-input mb-2" onchange="const inp = this.nextElementSibling; if(this.value==='custom') { inp.style.display='block'; inp.value=''; } else { inp.style.display='none'; inp.value=this.value; }">
                <option value="https://feuerwehr.einsatz.or.at" ${!isCustomUrl ? 'selected' : ''}>Leitstellenverbund Kärnten (https://feuerwehr.einsatz.or.at)</option>
                <option value="custom" ${isCustomUrl ? 'selected' : ''}>Eigener Server</option>
            </select>
            <input type="text" class="form-control advanced-input" data-path="credentials.base_url" value="${baseUrl}" style="display: ${isCustomUrl ? 'block' : 'none'};" placeholder="https://mein-server.at">
            <div class="form-text">Die Haupt-Internetadresse, von der die Einsatzdaten bezogen werden.</div>
        </div>
    `;

    html += createInput('Benutzername', 'credentials.username', currentConfig.credentials.username, 'text', 'Dein Benutzername für den FWEI Zugang.');
    html += createInput('Passwort', 'credentials.password', currentConfig.credentials.password, 'password', 'Das dazugehörige Passwort für den FWEI Zugang.');
    html += '<button type="button" class="btn btn-outline-info mt-3 w-100" onclick="testConnection()"><i class="fa-solid fa-rotate me-2"></i>Konfiguration speichern & Neu verbinden & Verbindung Testen</button>';
    html += '</div>';

    // Audio
    html += '<div class="config-group"><h5 class="text-primary mb-3">🔊 Audio & Sprachausgabe</h5>';
    html += createInput('Microsoft TTS Stimme', 'audio.voice', currentConfig.audio.voice, 'text', 'Der Name der Computerstimme. Standardmäßig "de-DE-KillianNeural" (eine sehr deutliche, deutsche männliche Stimme).');
    html += createInput('Sprech-Geschwindigkeit', 'audio.rate', currentConfig.audio.rate, 'text', 'Wie schnell soll gesprochen werden? Verwende Prozentwerte mit Plus/Minus. Z.B. "-10%" bedeutet 10% langsamer als normal (besser verständlich). "+10%" wäre schneller.');
    html += createInput('Lautstärkeanhebung (dB)', 'audio.gain_db', currentConfig.audio.gain_db, 'number', 'Um wie viel Dezibel (dB) soll die berechnete Sprachausgabe lauter gemacht werden? "9" bedeutet deutlich lauter. Wenn es übersteuert (krächzt), setze den Wert tiefer (z.B. 4).');
    html += createInput('Pause nach Gong (Sekunden)', 'audio.gong_pause_sec', currentConfig.audio.gong_pause_sec, 'number', 'Wie viele Sekunden Stille sollen zwischen dem Ende des Gongs und dem Start der Sprachansage vergehen? (Empfohlen: 1 oder 1.5)');
    html += createSelect('Audio Ausgabe-Gerät', 'audio.output_device', currentConfig.audio.output_device || '', availableAudioDevices, 'Wähle den System-Lautsprecherausgang. Empfehlung: Am Raspberry Pi den nativen Aux-Ausgang (oft "bcm2835 ALSA" oder "Headphones") verwenden. Je nach Anlage wird hierfür oft ein "AUX auf Cinch" Kabeladapter benötigt. ACHTUNG: Bei Änderung muss das Programm neu gestartet werden!');
    html += '<button type="button" class="btn btn-outline-danger px-4" onclick="triggerTestAlarm()" title="Löst einen Einsatz inklusive geplanten Wiederholungen aus"><i class="fa-solid fa-bell me-2"></i>Test-Einsatz simulieren</button>';
    html += '<div class="alert alert-secondary mt-3 mb-0 border-0" style="font-size: 0.85rem;"><i class="fa-solid fa-circle-info me-2"></i><strong>Hinweis zum Datenschutz (TTS):</strong> Zur Generierung der gesprochenen Texte (TTS) wird das Paket <code>edge_tts</code> verwendet. Die Textdaten werden zur Umwandlung an Microsoft-Server gesendet (genaue Ziel-URL: <code>wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1</code>).</div>';
    html += '</div>';

    // Repeat Alert
    html += '<div class="config-group"><h5 class="text-primary mb-3">🔁 Alarm Wiederholungen</h5>';
    html += `<div class="form-text mb-2 text-warning fw-bold">Nach wie vielen Minuten soll ein laufender realer Einsatz erneut durchgesagt werden? (Kommagetrennte Zahlen!)</div>`;
    html += `<div class="form-text mb-2">Beispiel: Wenn hier "1.5, 3, 4.5" steht, wird die Durchsage nach 1,5 Minuten, dann nochmal nach 3 Minuten und nochmal nach 4,5 Minuten wiederholt!<br>Hat den Sinn, da nicht alle Kameraden bei der Alarmierung im Feuerwehrhaus sind sondern erst nach und nach einrücken.</div>`;
    html += `<input type="text" class="form-control" data-path="repeatAlert" value="${currentConfig.repeatAlert.join(', ')}">`;
    html += '</div>';

    // Text Processing
    html += '<div class="config-group"><h5 class="text-primary mb-3">📝 Text- & Sprachkorrekturen</h5>';
    html += '<p class="text-muted small">Die Computerstimme liest genau das vor, was sie bekommt. Hier kannst du einstellen, dass Abkürzungen oder Stichworte aus dem System schöner und vor allem richtig ausgesprochen werden.</p>';

    html += createDictEditor('Stichwort Mapping (Alarmarten übersetzen)', 'text_processing.keyword_mapping', currentConfig.text_processing.keyword_mapping, 'Links steht das Stichwort wie es von der Leitstelle kommt (z.B. "T VU"). Rechts steht der Satz, der vorgelesen werden soll (z.B. "Verkehrsunfall").');

    html += createDictEditor('Abkürzungen ersetzen', 'text_processing.abbreviations', currentConfig.text_processing.abbreviations, 'Wenn im Zusatztext der Leitstelle Dinge wie "BMA" oder "verm." stehen, liest die Computerstimme das oft komisch vor. Links die Abkürzung eintragen, Rechts das vollständige Wort (z.B. "Brandmeldeanlage", "vermutlich").');

    html += createDictEditor('Adress-Sonderfälle bereinigen', 'text_processing.address_replacements', currentConfig.text_processing.address_replacements, 'Ähnlich wie Abkürzungen, greift aber NUR bei der Adresse! Z.B. "AS" durch "Anschlussstelle" oder ein Pfeil ">" durch "Fahrtrichtung".');
    html += '</div>';

    container.innerHTML = html;
}

window.addDictRow = function (containerId, path) {
    const div = document.createElement('div');
    div.className = 'd-flex mb-2 gap-2 dict-row';
    div.setAttribute('data-path', path);
    div.innerHTML = `
        <input type="text" class="form-control dict-key" placeholder="Schlüssel">
        <input type="text" class="form-control dict-val" placeholder="Wert">
        <button type="button" class="btn btn-outline-danger" onclick="this.parentElement.remove()"><i class="fa-solid fa-trash"></i></button>
    `;
    document.getElementById(containerId).appendChild(div);
};

async function saveConfig() {
    if (!currentConfig) return;

    const setPath = (obj, path, val) => {
        const parts = path.split('.');
        let curr = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            curr = curr[parts[i]];
        }
        curr[parts[parts.length - 1]] = val;
    };

    // Form Data erzeugen
    const data = JSON.parse(JSON.stringify(currentConfig));

    document.querySelectorAll('#form-config input[data-path], #form-config select[data-path]').forEach(el => {
        const path = el.getAttribute('data-path');
        let val = el.value;
        if (el.type === 'number') val = Number(val);

        if (path === 'repeatAlert') {
            val = val.split(',').map(s => Number(s.trim())).filter(n => !isNaN(n));
        }

        if (path === 'ui.password' || path === 'credentials.password') {
            if (val === '***' || val === '') return;
        }

        if (path !== 'repeatAlert' && !el.classList.contains('dict-key') && !el.classList.contains('dict-val')) {
            setPath(currentConfig, path, val);
        } else if (path === 'repeatAlert') {
            currentConfig.repeatAlert = val;
        }
    });

    ['keyword_mapping', 'abbreviations', 'address_replacements'].forEach(dictName => {
        const newDict = {};
        document.querySelectorAll(`.dict-row[data-path="text_processing.${dictName}"]`).forEach(row => {
            const key = row.querySelector('.dict-key').value.trim();
            const val = row.querySelector('.dict-val').value.trim();
            if (key) newDict[key] = val;
        });
        currentConfig.text_processing[dictName] = newDict;
    });

    try {
        const res = await fetch('/api/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(currentConfig)
        });
        if (res.ok) alert('Konfiguration gespeichert!');
        else alert('Fehler beim Speichern.');
    } catch (e) {
        alert('Netzwerkfehler.');
    }
}

async function testConnection() {
    await saveConfig();
    try {
        const res = await fetch('/api/reconnect', { method: 'POST' });
        if (res.ok) {
            const data = await res.json();
            if (data.success) {
                alert("Erfolgreich verbunden!");
                checkSystemStatus();
            } else {
                alert("Verbindung fehlgeschlagen: " + (data.error || "Falsche Zugangsdaten?"));
                checkSystemStatus();
            }
        } else {
            alert("Fehler beim Serveraufruf.");
        }
    } catch (e) {
        alert("Netzwerkfehler beim Testen der Verbindung.");
    }
}

// --- Logs ---
async function loadLogs() {
    try {
        const res = await fetch('/api/history');
        if (res.ok) {
            const logs = await res.json();
            renderLogs(logs);
        }
    } catch (e) { }
}

function renderLogs(logs) {
    const tbody = document.querySelector('#logs-table tbody');
    tbody.innerHTML = '';

    logs.sort((a, b) => new Date(b.detectionTime || 0) - new Date(a.detectionTime || 0));

    logs.forEach(log => {
        const dt = new Date(log.detectionTime);
        const timeStr = isNaN(dt) ? 'Unbekannt' : dt.toLocaleString('de-DE');

        // Find if it was an alarm or manual
        const isAlarm = log.id ? true : false;
        const rowClass = isAlarm ? 'alarm-row' : '';
        const gongVal = log.gong || log.gong_used || 0;

        let gongText = gongVal;
        if (gongVal == 0) {
            gongText = 'Kein';
        } else if (currentConfig && currentConfig.gongs) {
            const gInfo = currentConfig.gongs.find(g => g.id == gongVal);
            if (gInfo) gongText = gInfo.name;
        } else {
            if (gongVal == 1) gongText = 'Einsatz';
            else if (gongVal == 2) gongText = 'Folgeeinsatz';
            else if (gongVal == 3) gongText = 'Jugend';
            else if (gongVal == 4) gongText = 'Durchsage';
            else if (gongVal == 5) gongText = 'ÖBB';
        }

        let detailsHtml = '';
        if (log.durchsage_text || log.final_text) {
            detailsHtml += `<strong>Gesprochen:</strong> ${log.durchsage_text || log.final_text}<br>`;
        }
        if (log.description) {
            detailsHtml += `<strong>Zusatzinfo:</strong> ${log.description}<br>`;
        }
        if (log.type) {
            detailsHtml += `<strong>Typ:</strong> ${log.type}`;
        }
        if (!detailsHtml) detailsHtml = '-';

        tbody.innerHTML += `
            <tr class="${rowClass}">
                <td class="text-nowrap">${timeStr}</td>
                <td><strong>${gongText}</strong></td>
                <td>${log.placeLAWZ ? log.placeLAWZ + ' ' : ''}${log.additionalAddressInfo || '-'}</td>
                <td>
                    ${detailsHtml}
                </td>
            </tr>
        `;
    });
}

// --- Gongs Management ---
async function loadGongs() {
    try {
        const res = await fetch('/api/gongs');
        if (res.ok) {
            const gongs = await res.json();
            const tbody = document.querySelector('#gongs-table tbody');
            tbody.innerHTML = '';
            gongs.forEach(g => {
                const isAlarmText = g.is_alarm ? '<span class="badge bg-danger">Alarm</span>' : '<span class="badge bg-secondary">Durchsage</span>';
                let deleteBtn = `<button class="btn btn-sm btn-outline-danger" onclick="deleteGong(${g.id})" title="Löschen"><i class="fa-solid fa-trash"></i></button>`;
                if (g.id === 1 || g.id === 2) {
                    deleteBtn = `<button class="btn btn-sm btn-outline-secondary" disabled title="Standard-Gong (geschützt)"><i class="fa-solid fa-lock"></i></button>`;
                }

                let replaceInput = `<input type="file" id="replace-file-${g.id}" style="display:none" accept=".mp3" onchange="replaceGong(${g.id}, this)">
                                    <button class="btn btn-sm btn-outline-warning" onclick="document.getElementById('replace-file-${g.id}').click()" title="Gong ersetzen"><i class="fa-solid fa-upload"></i></button>`;
                let resetBtn = '';
                if (g.id === 1 || g.id === 2) {
                    resetBtn = `<button class="btn btn-sm btn-outline-info" onclick="resetGong(${g.id})" title="Auf Standard zurücksetzen"><i class="fa-solid fa-rotate-left"></i></button>`;
                }

                tbody.innerHTML += `
                    <tr>
                        <td>${g.id}</td>
                        <td>${g.name}</td>
                        <td>${isAlarmText}</td>
                        <td>
                            <button class="btn btn-sm btn-outline-primary" onclick="previewGongId(${g.id})" title="Vorhören"><i class="fa-solid fa-play"></i></button>
                            ${replaceInput}
                            ${resetBtn}
                            ${deleteBtn}
                        </td>
                    </tr>
                `;
            });
        }
    } catch (e) {
        alert("Fehler beim Laden der Gongs");
    }
}

async function deleteGong(id) {
    if (!confirm("Diesen Gong wirklich löschen?")) return;
    try {
        const res = await fetch(`/api/gongs/${id}`, { method: 'DELETE' });
        if (res.ok) {
            loadGongs();
            loadConfig(); // Refresh config and dropdown
        } else {
            alert("Fehler beim Löschen.");
        }
    } catch (e) {
        alert("Netzwerkfehler.");
    }
}

async function replaceGong(id, inputElement) {
    if (inputElement.files.length === 0) return;
    if (!confirm("Diesen Gong wirklich überschreiben?")) {
        inputElement.value = '';
        return;
    }
    const formData = new FormData();
    formData.append('file', inputElement.files[0]);
    try {
        const res = await fetch(`/api/gongs/${id}/audio`, { method: 'POST', body: formData });
        if (res.ok) {
            alert("Gong erfolgreich ersetzt!");
        } else {
            alert("Fehler beim Ersetzen.");
        }
    } catch (e) {
        alert("Netzwerkfehler.");
    }
    inputElement.value = '';
}

async function resetGong(id) {
    if (!confirm("Soll dieser Gong wirklich auf den Standard-Gong zurückgesetzt werden?")) return;
    try {
        const res = await fetch(`/api/gongs/${id}/reset`, { method: 'POST' });
        if (res.ok) {
            alert("Gong auf Standard zurückgesetzt!");
        } else {
            const err = await res.json();
            alert("Fehler: " + (err.detail || "Unbekannt"));
        }
    } catch (e) {
        alert("Netzwerkfehler.");
    }
}

function populateGongsSelect() {
    const select = document.getElementById('announce-gong');
    if (!select || !currentConfig || !currentConfig.gongs) return;

    const currentVal = select.value;

    select.innerHTML = '<option value="0" selected>Keinen</option>';
    currentConfig.gongs.forEach(g => {
        select.innerHTML += `<option value="${g.id}">${g.name}</option>`;
    });

    if (Array.from(select.options).some(o => o.value === currentVal)) {
        select.value = currentVal;
    }
}

async function triggerTestAlarm() {
    if (!confirm("Achtung: Dies löst einen Test-Alarm aus, der WIE EIN ECHTER EINSATZ verarbeitet wird (inklusive Gong, Durchsage und geplanten Wiederholungen). Fortfahren?")) return;
    try {
        const res = await fetch('/api/test_alarm', { method: 'POST' });
        if (res.ok) {
            alert("Test-Einsatz wurde gestartet.");
            loadLogs(); // Update history
        } else {
            alert("Fehler beim Starten des Test-Einsatzes.");
        }
    } catch (e) {
        alert("Netzwerkfehler.");
    }
}

// --- System & Wartung ---
async function downloadSyslog() {
    window.open('/api/syslog', '_blank');
}

async function restartSystem() {
    if (confirm("⚠️ Bist du sicher, dass du das gesamte Alarmdurchsage Server System neu starten möchtest? (Die Verbindung wird kurz unterbrochen)")) {
        try {
            const res = await fetch('/api/restart', { method: 'POST' });
            if (res.ok) {
                alert("System startet neu! Bitte die Seite in ca. 5 Sekunden manuell neu laden.");
            } else {
                alert("Fehler beim Neustart.");
            }
        } catch (e) {
            alert("System startet neu! Die Verbindung wurde getrennt.");
        }
    }
}