from flask import Flask, render_template, request
from flask_socketio import SocketIO
import socket
import time
import threading
import requests

# --- Opsætning ---
app = Flask(__name__)
socketio = SocketIO(app, async_mode='threading')


# Hjælpefunktion: Find egen IP
def get_own_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

own_ip = get_own_ip()
last_octet = int(own_ip.split('.')[-1])

# Master hvis IP slutter på 254
is_master = (last_octet == 254)
own_id = 0 if is_master else last_octet

master_ip = '.'.join(own_ip.split('.')[:-1]) + '.254'  # Altid på samme subnet .254

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


# --- Funktion: Send egen data som master ---
def send_own_data_master():
    while True:
        payload = {
            'unit': f"Blox 0",
            'ip': own_ip,
            'temp': f'{24 + (time.time() % 5):.2f}',
            'liter': f'{100 + (time.time() % 50):.2f}'
        }
        socketio.emit('unit_data', payload)
        time.sleep(3)


# --- Funktion: Send egen data som klient ---
def send_data_to_master():
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
    if is_master:
        print(f"[MASTER] Jeg er Blox 0 på IP {own_ip}")
        threading.Thread(target=send_own_data_master, daemon=True).start()
        socketio.run(app, host='0.0.0.0', port=5000, ssl_context=('/opt/blox-webui/certs/cert.pem', '/opt/blox-webui/certs/key.pem'), allow_unsafe_werkzeug=True)
    else:
        print(f"[CLIENT] Jeg er Blox {own_id} på IP {own_ip}, sender til {master_ip}")
        threading.Thread(target=send_data_to_master, daemon=True).start()

        # Kør en "tom" Flask-app, så alle enheder kan få samme system
        app.run(host='0.0.0.0', port=5000)
