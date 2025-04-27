#!/bin/bash
set -e

# === BLOX Installer / Reset Script ===
BRANCH="${1:-main}"

echo "===> BLOX Installer / Reset Script"
echo "👉 Bruger branch: $BRANCH"
echo

# --- SELF-REFRESH: Sikrer vi altid bruger nyeste version ---
if [[ "$SELF_REFRESH_DONE" != "yes" ]]; then
    echo "🔄 Henter nyeste version af install.sh fra GitHub ($BRANCH branch)..."
    rm -f install.sh
    curl -O https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/install.sh
    chmod +x install.sh
    echo "✅ Nyeste install.sh hentet!"
    echo
    echo "🚀 Starter opdateret install.sh..."
    export SELF_REFRESH_DONE="yes"
    exec sudo ./install.sh "$BRANCH"
    exit 0
fi

# --- Funktion: hent hjælpe-scripts ---
hent_og_gør_eksekverbar() {
    fil="$1"
    echo "Henter og klargør $fil..."
    curl -O "https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/$fil"
    chmod +x "$fil"
}

# --- STOP gammel service ---
echo "🛑 Stopper gammel BLOX service (hvis eksisterende)..."
sudo systemctl stop blox-webui.service || true
sudo systemctl disable blox-webui.service || true

# --- PAKKEINSTALLATION ---
echo "🔧 Opdaterer pakker og installerer nødvendige Python-pakker..."
sudo apt update
sudo apt install -y python3 python3-pip git openssl python3-requests python3-netifaces curl

echo "📦 Installerer Flask, Flask-SocketIO og Eventlet..."
sudo pip3 install flask flask-socketio eventlet || true

# --- SLET gammel mappe ---
echo "🧹 Sletter gammel BLOX-mappe hvis den findes..."
sudo rm -rf /opt/blox-webui

# --- KLON BLOX PROJEKT ---
echo "📥 Kloner BLOX projekt fra GitHub..."
sudo git clone --branch "$BRANCH" https://github.com/Elektropac/BLOX.git /opt/blox-webui

# --- SSL CERTIFIKAT ---
echo "🔒 Opretter SSL-certifikat..."
sudo mkdir -p /opt/blox-webui/certs
cd /opt/blox-webui/certs
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=blox.local"
sudo chown -R $USER:$USER /opt/blox-webui/certs

# --- MAC-OPSÆTNING ---
echo
read -p "🔄 Vil du generere en ny MAC-adresse for denne BLOX? (y/n) " svaret
if [[ "$svaret" == "y" ]]; then
    echo "🔧 Genererer ny MAC-adresse..."
    HEX1=$(printf '%02X' $((RANDOM % 256)))
    HEX2=$(printf '%02X' $((RANDOM % 256)))
    HEX3=$(printf '%02X' $((RANDOM % 256)))
    NY_MAC="02:12:34:$HEX1:$HEX2:$HEX3"
    echo "$NY_MAC" | sudo tee /etc/blox-mac.conf
    echo "✅ MAC-adresse sat til $NY_MAC"
    echo

    # Opret systemd service til MAC
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

# --- SYSTEMD SERVICE BLOX WEBUI ---
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

# --- BLOX-RESET ---
echo "🔁 Opretter 'blox-reset' genvej..."
sudo tee /usr/local/bin/blox-reset > /dev/null <<EOF
#!/bin/bash
rm -f install.sh
curl -O https://raw.githubusercontent.com/Elektropac/BLOX/$BRANCH/install.sh
chmod +x install.sh
./install.sh
EOF
sudo chmod +x /usr/local/bin/blox-reset

# --- HENT EKSTRA SCRIPTS ---
echo "⚙️ Henter ekstra scripts..."
cd ~
hent_og_gør_eksekverbar setip.sh
scripts=("blox_welcome.sh")
for fil in "${scripts[@]}"; do
    hent_og_gør_eksekverbar "$fil"
done

# --- VIS IP ---
IP=$(hostname -I | awk '{print $1}')

echo
echo "✅ BLOX Web UI installation færdig!"
echo "🌐 HTTP adgang:  http://$IP:5000"
echo "🔒 HTTPS adgang: https://$IP:5001"
echo "⚡ Parallel IP Setup script er klar: ~/setip.sh"
echo "🛠️ Hjælpescripts (fx blox_welcome.sh) ligger i ~/"
echo
echo "✅ Du kan altid køre 'blox-reset' for at starte forfra!"
echo "✅ Husk at acceptere self-signed certifikat i browseren første gang."
echo

# --- AUTO-REBOOT ---
echo "⚠️ BLOX genstarter automatisk om 10 sekunder for at aktivere ny MAC og netværk..."
sleep 10
sudo reboot
