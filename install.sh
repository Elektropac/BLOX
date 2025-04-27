#!/bin/bash

set -e

echo "===> BLOX Installer / Reset Script"

# Hvis der gives en parameter, brug den som branch, ellers brug "main"
BRANCH="${1:-main}"

echo "👉 Bruger branch: $BRANCH"

# Funktion til at hente filer og gøre dem eksekverbare
hent_og_gør_eksekverbar() {
    fil="$1"
    echo "Henter og klargør $fil..."
    curl -k -O "https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/$fil"
    chmod +x "$fil"
}

# Opret bruger 'blox' hvis den ikke findes
echo "👤 Tjekker om bruger 'blox' findes..."
if id "blox" &>/dev/null; then
    echo "📄 Bruger 'blox' findes allerede."
else
    echo "🔧 Opretter bruger 'blox' med password 'blox'..."
    sudo useradd -m -s /bin/bash blox
    echo "blox:blox" | sudo chpasswd
    sudo usermod -aG sudo blox
fi

# Tids-synkronisering

echo "🕒 Installerer og aktiverer systemd-timesyncd for automatisk tids-synkronisering..."
sudo apt update
sudo apt install -y systemd-timesyncd
sudo systemctl enable systemd-timesyncd
sudo systemctl start systemd-timesyncd

# Bekræft
echo "✅ Automatisk tidssynkronisering er aktiveret."

# Stop gammel service

echo "🔛 Stopper gammel BLOX service (hvis eksisterende)..."
sudo systemctl stop blox-webui.service || true
sudo systemctl disable blox-webui.service || true

# Opdater pakker og installer nødvendige Python-pakker

echo "🔧 Installerer nødvendige pakker..."
sudo apt install -y python3 python3-pip git openssl python3-requests python3-netifaces
sudo pip3 install flask flask-socketio eventlet || true

# Slet gammel mappe

echo "🧹 Sletter gammel BLOX-mappe hvis den findes..."
sudo rm -rf /opt/blox-webui

# Clone nyeste kode

echo "📥 Kloner nyeste BLOX-projekt fra GitHub..."
sudo git clone --branch "$BRANCH" https://github.com/Elektropac/BLOX.git /opt/blox-webui

# SSL-certifikat

echo "🔐 Opretter SSL-certifikat..."
sudo mkdir -p /opt/blox-webui/certs
cd /opt/blox-webui/certs
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=blox.local"

sudo chown -R $USER:$USER /opt/blox-webui/certs

# Opret systemd service

echo "🛠️ Opretter systemd service for BLOX Web UI..."
sudo tee /etc/systemd/system/blox-webui.service > /dev/null <<EOF
[Unit]
Description=BLOX Web UI Flask Server
After=network.target

[Service]
User=$USER
WorkingDirectory=/opt/blox-webui
ExecStart=/usr/bin/python3 /opt/blox-webui/app.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable blox-webui.service
sudo systemctl start blox-webui.service

# Hent ekstra scripts
echo "🛠️ Henter ekstra scripts..."
cd ~
hent_og_gør_eksekverbar setip.sh
hent_og_gør_eksekverbar blox_welcome.sh

# MAC-adresse - Spørg bruger

echo
read -p "🔄 Vil du generere en ny MAC-adresse for denne BLOX? (y/n) " valg
if [[ "$valg" == "y" || "$valg" == "Y" ]]; then
    echo "🔧 Genererer ny MAC-adresse..."
    NY_MAC="02:12:34:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"
    echo "$NY_MAC" > /etc/blox-mac.txt
    echo "✅ Ny MAC-adresse sat til $NY_MAC"

    sudo tee /etc/systemd/system/blox-mac.service > /dev/null <<EOF
[Unit]
Description=BLOX - Sæt fast MAC på eth0
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip link set dev eth0 down
ExecStart=/sbin/ip link set dev eth0 address $NY_MAC
ExecStart=/sbin/ip link set dev eth0 up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable blox-mac.service
    echo "📅 MAC-adresse-service aktiveret (fast MAC ved reboot)"
fi

# Find IP automatisk
IP=$(hostname -I | awk '{print $1}')

# Afslutning
echo

echo "✅ BLOX Web UI kører nu!"
echo "🌐 HTTP adgang:  http://$IP:5000"
echo "🔒 HTTPS adgang: https://$IP:5001"
echo "⚡ Parallel IP Setup script er klar: ~/setip.sh"
echo "🛠️ Hjælpescripts (fx blox_welcome.sh) ligger i ~/"
echo "✅ Husk at acceptere self-signed certifikat i browseren første gang."
