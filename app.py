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
            'unit': 'blox1',
            'ip': '192.168.1.10',
            'temp': f'{24 + (time.time() % 5):.2f}',
            'liter': f'{100 + (time.time() % 50):.2f}'
        })
        socketio.emit('unit_data', {
            'unit': 'blox2',
            'ip': '192.168.1.11',
            'temp': f'{20 + (time.time() % 5):.2f}',
            'liter': f'{90 + (time.time() % 30):.2f}'
        })
        socketio.emit('unit_data', {
            'unit': 'blox3',
            'ip': '192.168.1.12',
            'temp': f'{22 + (time.time() % 5):.2f}',
            'liter': f'{85 + (time.time() % 40):.2f}'
        })
        time.sleep(3)


if __name__ == '__main__':
    # Start fake data i baggrund
    threading.Thread(target=send_fake_data, daemon=True).start()

    # Start SocketIO server (HTTP eller HTTPS)
    socketio.run(app, host='0.0.0.0', port=5000, ssl_context=('/opt/blox-webui/certs/cert.pem', '/opt/blox-webui/certs/key.pem'), allow_unsafe_werkzeug=True)

