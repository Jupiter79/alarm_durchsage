#!/bin/bash
set -e

echo "====================================================="
echo " Alarmdurchsage - Deinstallation"
echo "====================================================="

INSTALL_DIR="$HOME/alarm_durchsage"

if [ -d "$INSTALL_DIR" ]; then
    echo "Stoppe Docker Container und lösche Images..."
    cd "$INSTALL_DIR"
    if command -v docker &> /dev/null; then
        sudo docker compose --profile pi down --rmi all -v || true
        sudo docker compose --profile windows down --rmi all -v || true
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
sudo systemctl daemon-reload

echo "====================================================="
echo " Deinstallation abgeschlossen!"
echo " Das Programm und die Images wurden entfernt."
echo " Um alle Dateien restlos zu entfernen, kannst du"
echo " den Ordner mit folgendem Befehl löschen:"
echo " rm -rf $INSTALL_DIR"
echo "====================================================="
