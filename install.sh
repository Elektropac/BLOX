#!/bin/bash

set -e

echo "===> BLOX Installer / Reset Script"

# Stop and disable previous service if exists
echo "Stopper gammel BLOX service (hvis eksisterende)..."
sudo systemctl stop blox-webui.service || true
sudo systemctl disable blox-webui.service || true

# Update and install required packages
echo "Opdaterer pakker..."
sudo apt update
sudo apt install -y python3 python3-pip git openssl

# Install Flask
echo "Installerer Flask hvis nødvendigt..."
pip3 install flask || true

# Remove old folder
echo "Sletter gammel BLOX-mappe hvis den findes..."
sudo rm -rf /opt/blox-webui

# Clone new repo
echo "Kloner nyeste BLOX-projekt fra GitHub..."
sudo git clone https://github.com/Elektropac/BLOX.git /opt/blox-webui

# Generate SSL cert if not exists
echo "Opretter SSL-certifikat..."
sudo mkdir -p /opt/blox-webui/certs
cd /opt/blox-webui/certs
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=blox.local"

# Set correct permissions so Flask kan læse certs
sudo chown -R $USER:$USER /opt/blox-webui/certs

# Create systemd service
echo "Opretter systemd service for BLOX..."

sudo tee /etc/systemd/system/blox-webui.service > /dev/null <<EOF
[Unit]
Description=BLOX Web UI Flask Server
After=network.target

[Service]
User=$USER
WorkingDirectory=/opt/blox-webui
ExecStart=/usr/bin/python3 /opt/blox-webui/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start service
sudo systemctl daemon-reload
sudo systemctl enable blox-webui.service
sudo systemctl start blox-webui.service

# Opret /usr/local/bin/blox-reset kommando
echo "Opretter 'blox-reset' genvej..."

sudo tee /usr/local/bin/blox-reset > /dev/null <<EOF
#!/bin/bash
rm -f install.sh
curl -O https://raw.githubusercontent.com/Elektropac/BLOX/main/install.sh
chmod +x install.sh
./install.sh
EOF

sudo chmod +x /usr/local/bin/blox-reset

echo
echo "✅ 'blox-reset' kommando er klar! Du kan nu skrive 'blox-reset' for at gendanne alt."

# Find IP-adresse automatisk
IP=$(hostname -I | awk '{print $1}')

echo
echo "✅ BLOX Web UI kører nu!"
echo "🌐 HTTP adgang:  http://$IP:5000"
echo "🔒 HTTPS adgang: https://$IP:5001"
echo "⚠️  OBS: Første gang skal du måske acceptere self-signed certifikat i browseren."
