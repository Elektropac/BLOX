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
    curl -O "https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/$fil"
    chmod +x "$fil"
}

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
sudo git clone --branch "$BRANCH" https://github.com/Elektropac/BLOX.git /opt/blox-webui

# Generate SSL cert
echo "Opretter SSL-certifikat..."
sudo mkdir -p /opt/blox-webui/certs
cd /opt/blox-webui/certs
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=blox.local"

# Set correct permissions
sudo chown -R $USER:$USER /opt/blox-webui/certs

# Create systemd service
echo "Opretter systemd service for BLOX Web UI..."

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

# Hent og opsæt blox-reset genvej
echo "Opretter 'blox-reset' genvej..."
sudo tee /usr/local/bin/blox-reset > /dev/null <<EOF
#!/bin/bash
rm -f install.sh
curl -O https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/install.sh
chmod +x install.sh
./install.sh
EOF

sudo chmod +x /usr/local/bin/blox-reset

# Hent setip.sh til hjemmemappen
echo "Henter 'setip.sh' script..."
cd ~
hent_og_gør_eksekverbar setip.sh

# Hent ekstra hjælpe-scripts til hjemmemappen
echo "Henter ekstra scripts til ~/ ..."

cd ~

# Liste over ekstra scripts
scripts=("blox_welcome.sh")  # Tilføj flere navne her hvis du laver flere hjælpe-scripts senere

for fil in "${scripts[@]}"; do
    echo "Henter og klargør $fil..."
    curl -O "https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/$fil"
    chmod +x "$fil"
done

echo
# Find IP-adresse automatisk
IP=$(hostname -I | awk '{print $1}')

echo "✅ BLOX Web UI kører nu!"
echo "🌐 HTTP adgang:  http://$IP:5000"
echo "🔒 HTTPS adgang: https://$IP:5001"
echo "⚡ Parallel IP Setup script er klar: ~/setip.sh"
echo "🛠️ Hjælpescripts (fx blox_welcome.sh) ligger i ~/"
echo "✅ Du kan altid køre 'blox-reset' for at starte forfra!"
echo "✅ Husk at acceptere self-signed certifikat i browseren første gang."
