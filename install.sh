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
sudo apt install -y python3 python3-pip git

# Install Flask
echo "Installerer Flask hvis nødvendigt..."
pip3 install flask || true

# Remove old folder
echo "Sletter gammel BLOX-mappe hvis den findes..."
sudo rm -rf /opt/blox-webui

# Clone new repo
echo "Kloner nyeste BLOX-projekt fra GitHub..."
sudo git clone https://github.com/Elektropac/BLOX.git /opt/blox-webui

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

echo "===> BLOX Web UI er nu installeret og kører!"
