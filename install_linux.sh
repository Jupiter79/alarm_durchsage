#!/bin/bash
set -e

echo "====================================================="
echo " Alarmdurchsage - Linux / Raspberry Pi Installer"
echo "====================================================="

# 1. Grundlegende Werkzeuge installieren
echo ">>> [1/6] Installiere Basis-Werkzeuge..."
sudo apt-get update -y
sudo apt-get install -y git curl

# 2. Docker installieren (falls noch nicht vorhanden)
echo ">>> [2/6] Prüfe Docker-Installation..."
if ! command -v docker &> /dev/null; then
    echo "Docker nicht gefunden. Installiere Docker jetzt..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo "Füge den aktuellen Benutzer zur Docker-Gruppe hinzu..."
    sudo usermod -aG docker $USER
else
    echo "Docker ist bereits installiert!"
fi

# 3. Projekt klonen
echo ">>> [3/6] Lade Projekt herunter..."
INSTALL_DIR="$HOME/alarm_durchsage"
if [ ! -d "$INSTALL_DIR" ]; then
    git clone https://github.com/Jupiter79/alarm_durchsage.git "$INSTALL_DIR"
else
    echo "Verzeichnis existiert bereits. Hole neueste Updates..."
    cd "$INSTALL_DIR"
    git pull
fi

cd "$INSTALL_DIR"

# 4. Fehlerhafte Ordner (falls vorhanden) löschen und Log-Dateien sauber anlegen
echo ">>> [4/6] Bereite Konfiguration und Logs vor..."
rm -rf system.log log.json 2>/dev/null || true
touch system.log log.json

# 5. Docker Container bauen und starten
echo ">>> [5/6] Baue und starte den Container (Pi-Profil mit Audio)..."
# Wir nutzen sudo docker, da die usermod-Änderung aus Schritt 2 ohne Abmelden noch nicht greift
sudo docker compose --profile pi up -d --build

# 6. Abschlussmeldung
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "====================================================="
echo " INSTALLATION ABGESCHLOSSEN!"
echo "====================================================="
echo " Der Container läuft jetzt im Hintergrund."
echo " Er startet bei jedem PC-Neustart dank Docker automatisch wieder."
echo ""
echo " Die Weboberfläche ist in wenigen Sekunden erreichbar unter:"
echo " -> http://${IP_ADDR}"
echo " -> http://alarmdurchsage.local (falls der Hostname so lautet)"
echo "====================================================="