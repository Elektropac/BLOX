#!/bin/bash

set -e

echo "===> BLOX Parallel IP Setup Script"

# Find aktive interfaces
echo "Tilgængelige netværksinterfaces:"
ip -o link show | awk -F': ' '{print $2}' | grep -v lo

# Spørg hvilket interface vi skal bruge
read -p "Indtast navnet på netværksinterfacet du vil bruge (f.eks. eth0): " interface

# Spørg efter subnet og IP
read -p "Indtast subnetnummer (eks. 20 for 192.168.20.x): " subnet
read -p "Indtast IP-nummer (eks. 114 for 192.168.x.114): " ipnumber

# Saml IP-adressen
NEW_IP="192.168.$subnet.$ipnumber"

echo "Opsætter IP $NEW_IP på interface $interface..."

# Fjern tidligere ekstra IP (hvis en gammel findes)
echo "Fjerner tidligere ekstra IP på $interface (hvis nogen)..."
sudo ip addr flush dev $interface label $interface:1 || true

# Tilføj den nye ekstra IP
echo "Tilføjer IP $NEW_IP til $interface..."
sudo ip addr add $NEW_IP/24 dev $interface label $interface:1

# Gem config til senere brug
sudo mkdir -p /etc/blox/
echo "$interface" | sudo tee /etc/blox/interface.conf > /dev/null
echo "$NEW_IP" | sudo tee /etc/blox/ip.conf > /dev/null

# Opret systemd service
echo "Opretter systemd service..."

sudo tee /etc/systemd/system/blox-parallel-ip.service > /dev/null <<EOF
[Unit]
Description=BLOX Parallel IP Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ip addr add $(cat /etc/blox/ip.conf)/24 dev $(cat /etc/blox/interface.conf) label $(cat /etc/blox/interface.conf):1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable og start service
sudo systemctl daemon-reload
sudo systemctl enable blox-parallel-ip.service
sudo systemctl restart blox-parallel-ip.service

echo
echo "✅ BLOX Parallel IP er nu sat op!"
echo "🌐 Ny IP: $NEW_IP på interface $interface"
