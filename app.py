from flask import Flask, render_template, request
from flask_socketio import SocketIO
import socket
import time
import threading

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

# Hvis sidste oktet er 254, så er vi master
is_master = (last_octet == 254)
own_id = 0 if is_master else last_octet  # Master = ID 0, ellers ID = sidste oktet

@app.route('/')
def index():
    return render_template('index.html')


# Endpoint til at modtage data fra andre enheder
@app.route('/data', methods=['POST'])
def receive_data():
    data = request.get_json()
    if data and 'id' in data:
        data['unit'] = f"Blox {data['id']}"  # Enhedsnavn = "Blox X"
        socketio.emit('unit_data', data)
        return 'OK', 200
    return 'Bad Request', 400


# Masters egen data-funktion
def send_own_data():
    while True:
        payload = {
            'unit': f"Blox 0",  # Master ID = 0
            'ip': own_ip,
            'temp': f'{24 + (time.time() % 5):.2f}',
            'liter': f'{100 + (time.time() % 50):.2f}'
        }
        socketio.emit('unit_data', payload)
        time.sleep(3)


if __name__ == '__main__':
    if is_master:
        print(f"[MASTER] IP: {own_ip} - Jeg er Blox 0")
        threading.Thread(target=send_own_data, daemon=True).start()
    else:
        print(f"[CLIENT] IP: {own_ip} - Jeg burde kun sende data, ikke køre server!")

    socketio.run(app, host='0.0.0.0', port=5000, ssl_context=('/opt/blox-webui/certs/cert.pem', '/opt/blox-webui/certs/key.pem'), allow_unsafe_werkzeug=True)
