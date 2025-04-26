to use this

install curl and run:

curl -O https://raw.githubusercontent.com/Elektropac/BLOX/main/install.sh && chmod +x install.sh && ./install.sh


BLOX Setup
Dette repository indeholder scripts til hurtigt at installere, konfigurere og vedligeholde BLOX-enheder.

Installation
For at installere eller gendanne BLOX Web UI, kør følgende kommando på din enhed:

curl -O https://raw.githubusercontent.com/Elektropac/BLOX/main/install.sh && chmod +x install.sh && ./install.sh

Dette vil:

Installere nødvendige pakker (Python, Flask, Git, OpenSSL)

Clone det nyeste BLOX Web UI fra GitHub

Oprette SSL-certifikat (self-signed)

Starte både HTTP (port 5000) og HTTPS (port 5001) servere

Opsætte systemd service så serveren starter automatisk efter genstart

Hente ekstra værktøjer som setip.sh

BLOX Reset
Efter installation kan du til enhver tid gendanne BLOX ved at køre:

blox-reset

Dette henter og kører en frisk version af install.sh, så systemet sættes tilbage til start.

Parallel IP Setup (setip.sh)
For at opsætte et parallelt netværk (en ekstra IP-adresse) på din BLOX-enhed, brug:

sudo ./setip.sh

Dette script vil:

Vise alle tilgængelige netværksinterfaces

Spørge hvilket interface du vil bruge (f.eks. eth0)

Spørge hvilket subnet (eks. 20 → 192.168.20.x)

Spørge hvilket IP-nummer (eks. 114 → 192.168.x.114)

Opsætte en ekstra IP-adresse på enheden

Oprette en systemd-service så IP'en automatisk genskabes efter genstart

Eksempel på brug
sudo ./setip.sh
Vælg interface: eth0
Vælg subnet: 20
Vælg IP: 114

Resultat: 192.168.20.114 tilføjes som ekstra IP på eth0

Efterfølgende kan enheden tilgås både via den normale netværksadresse og den nye parallelle IP.

Adgang til BLOX Web UI
HTTP adgang: http://<din-ip>:5000

HTTPS adgang: https://<din-ip>:5001
(Første gang skal du muligvis acceptere en self-signed certifikat i din browser)

Bemærkninger
BLOX systemet er designet til at være hurtigt at installere, tilpasse og resette efter behov.

Parallelle netværk gør det muligt at kommunikere direkte mellem enheder på specialiserede subnets.


