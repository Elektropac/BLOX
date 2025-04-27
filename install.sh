#!/bin/bash
set -e

echo "===> BLOX Installer / Reset Script"

BRANCH="${1:-main}"
echo "👉 Bruger branch: $BRANCH"

# Funktion: hent script
hent_og_gør_eksekverbar() {
    fil="$1"
    echo "Henter og klargør $fil..."
    curl -O "https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/$fil"
    chmod +x "$fil"
}

# Stop gammelt WebUI
echo "🛑 Stopper gammel BLOX service (hvis eksisterende)..."
sudo systemctl stop blox-webui.service || true
sudo systemctl disable blox-webui.service || true

# Opdater pakker
echo "🔧 Opdaterer pakker og installerer nødvendige Python-pakker..."
sudo apt update
sudo apt install -y python3 python3-pip git openssl python3-requests python3-netifaces curl

# Installer Flask, SocketIO
echo "📦 Installerer Flask, Flask-SocketIO og Eventlet..."
sudo pip3 install flask flask-socketio eventlet || true

# Slet gammel mappe
echo "🧹 Sletter gammel BLOX-mappe hvis den findes..."
sudo rm -rf /opt/blox-webui

# Klon BLOX repo
echo "📥 Kloner BLOX projekt fra GitHub..."
sudo git clone --branch "$BRANCH" https://github.com/Elektropac/BLOX.git /opt/blox-webui

# Opret SSL cert
echo "🔒 Opretter SSL-certifikat..."
sudo mkdir -p /opt/blox-webui/certs
cd /opt/blox-webui/certs
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=blox.local"

# Permissions
sudo chown -R $USER:$USER /opt/blox-webui/certs

# --- NYT: Spørg om vi skal lave ny MAC ---
read -p "🔄 Vil du generere en ny MAC-adresse for denne BLOX? (y/n) " svaret
if [[ "$svaret" == "y" ]]; then
    echo "🔧 Genererer ny MAC-adresse..."
    # Lav en random MAC (starter altid med 02:12:34)
    HEX1=$(printf '%02X' $((RANDOM % 256)))
    HEX2=$(printf '%02X' $((RANDOM % 256)))
    HEX3=$(printf '%02X' $((RANDOM % 256)))
    NY_MAC="02:12:34:$HEX1:$HEX2:$HEX3"
    echo "$NY_MAC" | sudo tee /etc/blox-mac.conf
    echo "✅ MAC-adresse sat til $NY_MAC"

    # Lav systemd service
    sudo tee /etc/systemd/system/blox-mac.service > /dev/null <<EOF
[Unit]
Description=BLOX - Sæt fast MAC på eth0
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/sbin/ip link set dev eth0 down
ExecStart=/sbin/ip link set dev eth0 address $NY_MAC
ExecStart=/sbin/ip link set dev eth0 up
ExecStart=/sbin/dhclient eth0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable blox-mac.service
fi

# Opret systemd service til WebUI
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

# Installer blox-reset genvej
echo "🔁 Opretter 'blox-reset' genvej..."
sudo tee /usr/local/bin/blox-reset > /dev/null <<EOF
#!/bin/bash
rm -f install.sh
curl -O https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/install.sh
chmod +x install.sh
./install.sh
EOF
sudo chmod +x /usr/local/bin/blox-reset

# Hent 'setip.sh' og hjælpe-scripts
echo "⚙️ Henter ekstra scripts..."
cd ~
hent_og_gør_eksekverbar setip.sh

scripts=("blox_welcome.sh")
for fil in "${scripts[@]}"; do
    hent_og_gør_eksekverbar "$fil"
done

# Find IP
IP=$(hostname -I | awk '{print $1}')

echo
echo "✅ BLOX Web UI kører nu!"
echo "🌐 HTTP adgang:  http://$IP:5000"
echo "🔒 HTTPS adgang: https://$IP:5001"
echo "⚡ Parallel IP Setup script er klar: ~/setip.sh"
echo "🛠️ Hjælpescripts (fx blox_welcome.sh) ligger i ~/"
echo "✅ Du kan altid køre 'blox-reset' for at starte forfra!"
echo "✅ Husk at acceptere self-signed certifikat i browseren første gang."
