#!/bin/bash
set -e

echo "====================================================="
echo " Alarmdurchsage - DietPi Installer"
echo " (Optimiert für DietPi mit NetworkManager)"
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

if ! command -v nmcli &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL network-manager"
fi

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installiere fehlende Pakete: $PACKAGES_TO_INSTALL"
    sudo apt-get update -y
    sudo apt-get install -y $PACKAGES_TO_INSTALL
else
    echo "Alle Basis-Werkzeuge (git, curl, network-manager) sind bereits installiert!"
fi

# 1.5 DietPi Netzwerk-Fix
echo ">>> [1.5/6] Konfiguriere NetworkManager für DietPi..."

# wlan0 aus der DietPi-eigenen Konfiguration entfernen, damit NetworkManager nicht blockiert wird
if grep -q "wlan0" /etc/network/interfaces 2>/dev/null; then
    echo "Deaktiviere wlan0 in /etc/network/interfaces (DietPi Fallback)..."
    sudo sed -i 's/^.*wlan0.*$/#&/g' /etc/network/interfaces
fi

# NetworkManager zwingen, die Verwaltung zu übernehmen
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    echo "Setze managed=true im NetworkManager..."
    sudo sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
fi

echo "Starte NetworkManager neu..."
sudo systemctl enable NetworkManager || true
sudo systemctl restart NetworkManager || true

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

# Stelle sicher, dass Docker beim Systemstart (Autostart) automatisch gestartet wird
echo "Stelle sicher, dass Docker beim Systemstart aktiviert ist..."
sudo systemctl enable docker || true
sudo systemctl start docker || true

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
echo " -> http://${IP_ADDR}:8122"
echo " -> http://alarmdurchsage.local:8122 (falls der Hostname so lautet)"
echo "====================================================="