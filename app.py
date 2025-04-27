from flask import Flask, render_template
from flask_socketio import SocketIO
import time
import threading

app = Flask(__name__)
socketio = SocketIO(app, async_mode='threading')



@app.route('/')
def index():
    return render_template('index.html')

# Fake data udsender
def send_fake_data():
    while True:
        socketio.emit('unit_data', {
            'unit': 'Blox 1',
            'Ip': '192.168.20.50',
            'Temp': f'{24 + (time.time() % 5):.2f}',
            'Liter': f'{100 + (time.time() % 50):.2f}'
        })
        time.sleep(3)

if __name__ == '__main__':
    # Start fake data i baggrund
    threading.Thread(target=send_fake_data, daemon=True).start()

    # Start SocketIO server (HTTP eller HTTPS)
    socketio.run(app, host='0.0.0.0', port=5000, ssl_context=('/opt/blox-webui/certs/cert.pem', '/opt/blox-webui/certs/key.pem'), allow_unsafe_werkzeug=True)

