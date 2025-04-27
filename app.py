from flask import Flask, render_template, request
from flask_socketio import SocketIO
import socket
import time
import threading
import requests
import netifaces
import ipaddress

# --- BLOX opsætning ---
app = Flask(__name__)
socketio = SocketIO(app, async_mode='threading')

# Tilladte BLOX subnets
allowed_subnets = [
    ipaddress.IPv4Network('192.168.50.0/24'),
    ipaddress.IPv4Network('192.168.51.0/24'),
    ipaddress.IPv4Network('192.168.52.0/24'),
    ipaddress.IPv4Network('192.168.53.0/24'),
    ipaddress.IPv4Network('192.168.54.0/24'),
    ipaddress.IPv4Network('192.168.55.0/24'),
    ipaddress.IPv4Network('192.168.56.0/24'),
    ipaddress.IPv4Network('192.168.57.0/24'),
    ipaddress.IPv4Network('192.168.58.0/24'),
    ipaddress.IPv4Network('192.168.59.0/24'),
    ipaddress.IPv4Network('192.168.60.0/24'),
]

# Find den BLOX IP-adresse vi skal arbejde på
def find_blox_ip():
    for interface in netifaces.interfaces():
        addrs = netifaces.ifaddresses(interface)
        if netifaces.AF_INET in addrs:
            for link in addrs[netifaces.AF_INET]:
                ip = link.get('addr')
                if ip:
                    ip_obj = ipaddress.IPv4Address(ip)
                    for subnet in allowed_subnets:
                        if ip_obj in subnet:
                            return ip
    return None

# --- Flask Routes ---
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/data', methods=['POST'])
def receive_data():
    data = request.get_json()
    if data and 'id' in data:
        data['unit'] = f"Blox {data['id']}"
        socketio.emit('unit_data', data)
        return 'OK', 200
    return 'Bad Request', 400

# --- Funktion: Send masterens egen data ---
def send_own_data_master(blox_ip):
    while True:
        payload = {
            'unit': 'Blox 0',
            'ip': blox_ip,
            'temp': f'{24 + (time.time() % 5):.2f}',
            'liter': f'{100 + (time.time() % 50):.2f}'
        }
        socketio.emit('unit_data', payload)
        time.sleep(3)

# --- Funktion: Send data til master som client ---
def send_data_to_master(master_ip, own_id, own_ip):
    while True:
        payload = {
            'id': own_id,
            'ip': own_ip,
            'temp': f'{20 + (time.time() % 5):.2f}',
            'liter': f'{80 + (time.time() % 50):.2f}'
        }
        try:
            requests.post(f'http://{master_ip}:5000/data', json=payload, timeout=2)
        except Exception as e:
            print(f"[CLIENT ERROR] Kunne ikke sende til master: {e}")
        time.sleep(3)

# --- Hovedprogram ---
if __name__ == '__main__':
    blox_ip = find_blox_ip()

    if blox_ip:
        last_octet = int(blox_ip.split('.')[-1])
        if last_octet == 254:
            # Vi er MASTER
            print(f"[MASTER] Jeg er Blox 0 på {blox_ip}")
            threading.Thread(target=send_own_data_master, args=(blox_ip,), daemon=True).start()
            socketio.run(app, host='0.0.0.0', port=5000, allow_unsafe_werkzeug=True)
        else:
            # Vi er CLIENT
            print(f"[CLIENT] Jeg er Blox {last_octet} på {blox_ip}")
            master_ip = blox_ip.rsplit('.', 1)[0] + '.254'
            threading.Thread(target=send_data_to_master, args=(master_ip, last_octet, blox_ip), daemon=True).start()

            # Client skal IKKE starte egen server - hold bare tråden i gang
            while True:
                time.sleep(60)
    else:
        print("[FEJL] Ingen BLOX-netværk fundet. Check netværk og IP-indstillinger.")
