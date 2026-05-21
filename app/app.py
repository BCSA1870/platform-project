try:
    from flask import Flask
except ImportError as exc:
    raise ImportError(
        "Flask is required to run this application. Install it with 'pip install flask'."
    ) from exc

from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
 
app = Flask(__name__)
 
# Prometheus counters — these track how many requests came in
REQUEST_COUNT = Counter(
    'app_requests_total',
    'Total number of requests',
    ['method', 'endpoint', 'status']
)
REQUEST_LATENCY = Histogram(
    'app_request_latency_seconds',
    'Request latency in seconds',
    ['endpoint']
)
 
@app.route('/')
def home():
    start = time.time()
    REQUEST_COUNT.labels(method='GET', endpoint='/', status='200').inc()
    REQUEST_LATENCY.labels(endpoint='/').observe(time.time() - start)
    return 'Production Platform BCSAP1 v2. Launch is a success!!! 🚀', 200
 
@app.route('/health')
def health():
    return {'status': 'healthy'}, 200
 
@app.route('/metrics')
def metrics():
    # Prometheus scrapes this endpoint
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}
 
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
