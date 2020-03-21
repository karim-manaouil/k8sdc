from flask import Flask
from flask import request
import threading
import os

app= Flask(__name__)

lock = threading.Lock()
logger= open("/tmp/db", "w+")
lines= 0

@app.route('/register')
def register():
    host = request.args.get('host')
    date = request.args.get('date')

    with lock:
        global lines, logger
        logger.write("Client %s at %s\n" % (host, date))
        logger.flush()
        lines = lines + 1
        if lines == int(os.environ['MAX_LINES']):
            lines = 0
            logger.seek(0)

    return 'Done'

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
