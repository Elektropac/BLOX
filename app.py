from flask import Flask, render_template
import threading

app = Flask(__name__)

@app.route('/')
def index():
    return render_template('index.html')

def run_http():
    app.run(host='0.0.0.0', port=5000, debug=False)

def run_https():
    app.run(host='0.0.0.0', port=5001, debug=False, ssl_context=('/opt/blox-webui/certs/cert.pem', '/opt/blox-webui/certs/key.pem'))

if __name__ == '__main__':
    threading.Thread(target=run_http).start()
    threading.Thread(target=run_https).start()
