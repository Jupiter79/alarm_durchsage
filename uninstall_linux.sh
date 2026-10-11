#!/bin/bash
set -e

echo "====================================================="
echo " Alarmdurchsage - Deinstallation"
echo "====================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    INSTALL_DIR="$SCRIPT_DIR"
else
    INSTALL_DIR="$HOME/alarm_durchsage"
fi

# Compose-Befehl ermitteln
COMPOSE_CMD=""
if docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
fi

if [ -d "$INSTALL_DIR" ]; then
    echo "Stoppe Container und lösche Images..."
    cd "$INSTALL_DIR"
    if [ -n "$COMPOSE_CMD" ]; then
        sudo $COMPOSE_CMD --profile pi down --rmi all -v || true
        sudo $COMPOSE_CMD --profile windows down --rmi all -v || true
    fi
else
    echo "Installationsverzeichnis $INSTALL_DIR nicht gefunden."
    echo "Versuche Container direkt zu löschen..."
    sudo docker stop alarmdurchsage-pi 2>/dev/null || true
    sudo docker rm alarmdurchsage-pi 2>/dev/null || true
    sudo docker rmi alarm_durchsage-alarmdurchsage-pi 2>/dev/null || true
fi

echo "Entferne Systemdienst (Network-Fix) falls vorhanden..."
sudo systemctl stop alarm-network-fix.service 2>/dev/null || true
sudo systemctl disable alarm-network-fix.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/alarm-network-fix.service 2>/dev/null || true
sudo systemctl daemon-reload 2>/dev/null || true

echo "====================================================="
echo " Deinstallation abgeschlossen!"
echo " Das Programm und die Images wurden entfernt."
echo " Um alle Dateien restlos zu entfernen, kannst du"
echo " den Ordner mit folgendem Befehl löschen:"
echo " rm -rf $INSTALL_DIR"
echo "====================================================="
