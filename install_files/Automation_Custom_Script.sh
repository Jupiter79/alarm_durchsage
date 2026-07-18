#!/bin/bash
set -e

curl -fsSL \
https://raw.githubusercontent.com/Jupiter79/alarm_durchsage/refs/heads/main/install_linux.sh \
-o /tmp/install_linux.sh

chmod +x /tmp/install_linux.sh

bash /tmp/install_linux.sh