#!/bin/bash

MAC_FILE="/opt/blox-webui/.macaddr"

# Hvis MAC-fil ikke findes, generer en ny
if [ ! -f "$MAC_FILE" ]; then
    echo "[SET-MAC] Ingen MAC-fil fundet. Genererer ny MAC..."
    MAC_ADDR=$(printf '02:%02x:%02x:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    echo "$MAC_ADDR" > "$MAC_FILE"
else
    MAC_ADDR=$(cat "$MAC_FILE")
    echo "[SET-MAC] Bruger eksisterende MAC: $MAC_ADDR"
fi

# Sæt MAC på eth0
ip link set dev eth0 down
ip link set dev eth0 address $MAC_ADDR
ip link set dev eth0 up
