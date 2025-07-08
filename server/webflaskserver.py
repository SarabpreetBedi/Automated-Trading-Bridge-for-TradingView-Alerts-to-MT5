from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/data')
def data():
    return jsonify({
        "message": "trade now",
        "symbol": "EURUSD",
        "lot": 0.1,
        "cmd": "BUY",
        "sl": 20,
        "tp": 40
    })

if __name__ == '__main__':
    app.run(host="127.0.0.1", port=5000)
