from flask import Flask, request
from whitenoise import WhiteNoise
from prometheus_flask_exporter.multiprocess import GunicornInternalPrometheusMetrics

app = Flask(__name__)
app.wsgi_app = WhiteNoise(app.wsgi_app, root="/public", index_file=True)
metrics = GunicornInternalPrometheusMetrics(app)

@app.route("/test")
def main():
    return "1234"