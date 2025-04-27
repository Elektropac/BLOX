#!/bin/bash
# BLOX Start Installer - Henter altid nyeste install.sh før noget kører

echo "🔄 Henter nyeste install.sh fra GitHub (devide branch)..."
rm -f install.sh
curl -k -O https://raw.githubusercontent.com/Elektropac/BLOX/devide/install.sh
chmod +x install.sh
echo "🚀 Starter nyeste install.sh..."
sudo ./install.sh devide
