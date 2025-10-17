from flask import Flask, jsonify, request
from prometheus_client import (
    Counter,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)
import time

app = Flask(__name__)

REQUEST_COUNT = Counter(
    'app_requests_total', 'Total HTTP requests'
)
REQUEST_LATENCY = Histogram(
    'app_request_latency_seconds', 'Request latency'
)
ERROR_COUNT = Counter('app_errors_total', 'Total app errors')

# Simple failure mode toggle
failure_mode = {'enabled': False, 'error_rate': 0.5, 'latency_seconds': 0.5}


@app.route('/')
def index():
    REQUEST_COUNT.inc()
    start = time.time()
    # Simulate latency if enabled
    if failure_mode['enabled']:
        # introduce latency
        time.sleep(failure_mode.get('latency_seconds', 0.1))
        # and sometimes return errors
        import random
        if random.random() < failure_mode.get('error_rate', 0.5):
            REQUEST_LATENCY.observe(time.time() - start)
            ERROR_COUNT.inc()
            return (
                jsonify({'status': 'error', 'reason': 'simulated failure'}),
                500,
            )

    REQUEST_LATENCY.observe(time.time() - start)
    return jsonify({'status': 'ok', 'message': 'Hello from Chaos Canary'})


@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})


@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/failure', methods=['POST'])
def set_failure():
    data = request.get_json() or {}
    for k in ['enabled', 'error_rate', 'latency_seconds']:
        if k in data:
            failure_mode[k] = data[k]
    return jsonify({'failure_mode': failure_mode})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
