#!/bin/bash
set -e

echo "====================================================="
echo " Alarmdurchsage - DietPi Installer"
echo " (Optimiert für DietPi mit NetworkManager & Audio)"
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

if ! command -v wpa_supplicant &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL wpasupplicant wireless-tools iw rfkill"
fi

if ! command -v aplay &> /dev/null; then
    PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL alsa-utils"
fi

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installiere fehlende Pakete: $PACKAGES_TO_INSTALL"
    sudo apt-get update -y
    sudo apt-get install -y $PACKAGES_TO_INSTALL
else
    echo "Alle Basis-Werkzeuge (git, curl, network-manager) sind bereits installiert!"
fi

# 1.5 DietPi Netzwerk-Architektur auf "Pure NetworkManager" umbauen
echo ">>> [1.5/6] Konfiguriere NetworkManager als alleinigen Herrscher..."

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
echo ">>> [1.5/6b] Zerstöre DietPi-Kernel-Blockaden (Blacklists & Overlays)..."

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

# 1.7 DietPi Audio vollautomatisch aktivieren (Pi 3/4 vs Pi 5)
echo ">>> [1.7/6] Aktiviere Onboard-Audio permanent..."

if [ -f /boot/dietpi/func/dietpi-set_hardware ]; then
    echo "DietPi-Konfigurationswerkzeug gefunden."
    PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null || true)
    echo "Erkanntes Mainboard-Modell: $PI_MODEL"
    
    if [[ "$PI_MODEL" == *"Raspberry Pi 5"* ]]; then
        echo "Raspberry Pi 5 hat keinen Aux-Anschluss. Aktiviere HDMI-Audio als Standard..."
        sudo /boot/dietpi/func/dietpi-set_hardware soundcard rpi-bcm2835-hdmi || true
    else
        echo "Aktiviere nativen 3.5mm Aux-Anschluss als Standard..."
        sudo /boot/dietpi/func/dietpi-set_hardware soundcard rpi-bcm2835-3.5mm || true
    fi
fi

# Fallback für Standard-Raspberry Pi OS
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
echo "Lade Soundkarten-Treiber..."
sudo modprobe snd_bcm2835 || true

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
echo " WICHTIG: Wenn du DietPi nutzt, starte den Pi jetzt am besten"
echo " einmal neu mit dem Befehl: sudo reboot"
echo "====================================================="