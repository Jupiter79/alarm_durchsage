#!/bin/sh

set -e

# 1. Community Repository aktivieren & Update (lautlos)
sed -i '/community/s/^#//' /etc/apk/repositories
apk update -q >/dev/null 2>&1

# 2. System-Pakete installieren (lautlos)
apk add -q python3 py3-pip python3-dev build-base ffmpeg git sdl2-dev sdl2_image-dev sdl2_mixer-dev sdl2_ttf-dev freetype-dev alsa-utils alsa-lib >/dev/null 2>&1

# 3. Audio-Hardware des Raspberry Pi aktivieren
mount -o remount,rw /boot 2>/dev/null || true

if ! grep -q "^dtparam=audio=on" /boot/config.txt 2>/dev/null; then
    printf "dtparam=audio=on\n" >> /boot/config.txt
fi

if ! grep -q "^snd_bcm2835" /etc/modules 2>/dev/null; then
    printf "snd_bcm2835\n" >> /etc/modules
fi

# 4. Python-Pakete global installieren (lautlos)
pip install -q --break-system-packages --no-cache-dir fastapi pydantic uvicorn pydub pygame edge-tts requests python-socketio python-multipart audioop-lts zeroconf >/dev/null 2>&1

# 5. Repository klonen (lautlos)
cd /home
if [ ! -d "alarm_durchsage" ]; then
    git clone -q https://github.com/Jupiter79/alarm_durchsage >/dev/null 2>&1
fi

# 6. OpenRC Service (Autostart) einrichten
cat << 'EOF' > /etc/init.d/alarmdurchsage
#!/sbin/openrc-run

name="Alarm Durchsage"
command="/usr/bin/python3"
command_args="durchsage.py"
directory="/home/alarm_durchsage"
supervisor="supervise-daemon"

depend() {
    need net localmount
}
EOF

# Rechte setzen und zum Autostart hinzufügen (lautlos)
chmod +x /etc/init.d/alarmdurchsage
rc-update add alarmdurchsage default >/dev/null 2>&1 || true