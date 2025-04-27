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
echo "🛑 Stopper gammel BLOX service (hvis eksisterende)..."
sudo systemctl stop blox-webui.service || true
sudo systemctl disable blox-webui.service || true

# Update and install required packages
echo "🔧 Opdaterer pakker og installerer nødvendige Python-pakker..."
sudo apt update
sudo apt install -y python3 python3-pip git openssl python3-requests python3-netifaces

# Install Flask og SocketIO (ignorer fejl hvis allerede installeret)
echo "📦 Installerer Flask, Flask-SocketIO og Eventlet..."
sudo pip3 install flask flask-socketio eventlet || true

# Remove old folder
echo "🧹 Sletter gammel BLOX-mappe hvis den findes..."
sudo rm -rf /opt/blox-webui

# Clone new repo
echo "📥 Kloner nyeste BLOX-projekt fra GitHub..."
sudo git clone --branch "$BRANCH" https://github.com/Elektropac/BLOX.git /opt/blox-webui

# Generate SSL cert
echo "🔒 Opretter SSL-certifikat..."
sudo mkdir -p /opt/blox-webui/certs
cd /opt/blox-webui/certs
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=blox.local"

# Set correct permissions
sudo chown -R $USER:$USER /opt/blox-webui/certs

# MAC-setup: Spørg om ny MAC
MAC_FILE="/opt/blox-webui/.macaddr"

if [ -f "$MAC_FILE" ]; then
    echo "🔎 En eksisterende MAC-adresse blev fundet: $(cat $MAC_FILE)"
    read -p "❓ Vil du genbruge den gamle MAC? (y/n): " valg
    if [ "$valg" != "y" ]; then
        echo "♻️ Genererer ny MAC-adresse..."
        rm "$MAC_FILE"
    else
        echo "✅ Genbruger eksisterende MAC."
    fi
fi

# Opretter MAC-setup script
echo "🛠️ Opretter set-mac script..."
sudo tee /opt/blox-webui/set-mac.sh > /dev/null <<'EOF'
#!/bin/bash
MAC_FILE="/opt/blox-webui/.macaddr"
if [ ! -f "$MAC_FILE" ]; then
    echo "[SET-MAC] Ingen MAC-fil fundet. Genererer ny MAC..."
    MAC_ADDR=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    echo "$MAC_ADDR" > "$MAC_FILE"
else
    MAC_ADDR=$(cat "$MAC_FILE")
    echo "[SET-MAC] Bruger eksisterende MAC: $MAC_ADDR"
fi
ip link set dev eth0 down
ip link set dev eth0 address $MAC_ADDR
ip link set dev eth0 up
EOF

sudo chmod +x /opt/blox-webui/set-mac.sh

# Opretter systemd service for MAC-setup
echo "🛠️ Opretter set-mac systemd service..."
sudo tee /etc/systemd/system/set-mac.service > /dev/null <<EOF
[Unit]
Description=Set custom MAC address for eth0
After=network-pre.target
Before=network.target

[Service]
Type=oneshot
ExecStart=/opt/blox-webui/set-mac.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Aktiver MAC-setup service
sudo systemctl daemon-reload
sudo systemctl enable set-mac.service

# Create systemd service for WebUI
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

# Reload systemd, enable and start WebUI service
echo "🔄 Genindlæser systemd, aktiverer og starter BLOX Web UI..."
sudo systemctl daemon-reload
sudo systemctl enable blox-webui.service
sudo systemctl start blox-webui.service

# Hent og opsæt blox-reset genvej
echo "🔁 Opretter 'blox-reset' genvej..."
sudo tee /usr/local/bin/blox-reset > /dev/null <<EOF
#!/bin/bash
rm -f install.sh
curl -O https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/install.sh
chmod +x install.sh
./install.sh
EOF

sudo chmod +x /usr/local/bin/blox-reset

# Hent setip.sh til hjemmemappen
echo "⚙️ Henter 'setip.sh' script..."
cd ~
hent_og_gør_eksekverbar setip.sh

# Hent ekstra hjælpe-scripts
echo "🧩 Henter ekstra hjælpe-scripts..."

cd ~

scripts=("blox_welcome.sh")  # Tilføj flere her senere hvis nødvendigt

for fil in "${scripts[@]}"; do
    echo "Henter og klargør $fil..."
    curl -O "https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/$fil"
    chmod +x "$fil"
done

# Find IP-adresse automatisk
IP=$(hostname -I | awk '{print $1}')

echo
echo "✅ BLOX Web UI kører nu!"
echo "🌐 HTTP adgang:  http://$IP:5000"
echo "🔒 HTTPS adgang: https://$IP:5001"
echo "⚡ Parallel IP Setup script er klar: ~/setip.sh"
echo "🛠️ Hjælpescripts (fx blox_welcome.sh) ligger i ~/"
echo "✅ Du kan altid køre 'blox-reset' for at starte forfra!"
echo "✅ Husk at acceptere self-signed certifikat i browseren første gang."
