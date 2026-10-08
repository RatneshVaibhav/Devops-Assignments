"""campus-status - a small API instrumented for the Session 20 monitoring demo.

Metrics : Prometheus format on /metrics (requests, latency histogram, in-flight)
Logs    : one JSON line per request on stdout
Health  : /health (liveness) and /ready (readiness)
"""
import json
import logging
import os
import random
import time
import uuid

from flask import Flask, Response, g, jsonify, request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, Info, generate_latest

VERSION = os.environ.get("APP_VERSION", "1.0.0")
app = Flask(__name__)

REQUESTS = Counter("http_requests_total", "HTTP requests handled", ["method", "path", "status"])
LATENCY = Histogram("http_request_duration_seconds", "Request latency in seconds", ["path"],
                    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5))
IN_FLIGHT = Gauge("http_requests_in_flight", "Requests currently being served")
INFO = Info("campus_status", "Build information")
INFO.info({"version": VERSION})

log = logging.getLogger("campus-status")
logging.basicConfig(level=logging.INFO, format="%(message)s")


@app.before_request
def start_timer():
    g.start = time.perf_counter()
    g.request_id = request.headers.get("X-Request-ID", uuid.uuid4().hex[:12])
    IN_FLIGHT.inc()


@app.after_request
def record(response):
    IN_FLIGHT.dec()
    if request.path == "/metrics":
        return response
    elapsed = time.perf_counter() - g.start
    route = request.url_rule.rule if request.url_rule else "unmatched"
    REQUESTS.labels(request.method, route, response.status_code).inc()
    LATENCY.labels(route).observe(elapsed)
    log.info(json.dumps({
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "level": "error" if response.status_code >= 500 else "info",
        "request_id": g.request_id,
        "method": request.method,
        "path": request.path,
        "status": response.status_code,
        "duration_ms": round(elapsed * 1000, 2),
    }))
    response.headers["X-Request-ID"] = g.request_id
    return response


@app.get("/")
def index():
    return jsonify(service="campus-status", version=VERSION)


@app.get("/api/notices")
def notices():
    return jsonify(notices=["Library open till 11 pm", "Lab 4 closed on Friday"])


@app.get("/api/report")
def report():
    """CPU-heavy endpoint: busy-loops for ?ms= milliseconds (default 50)."""
    budget = min(int(request.args.get("ms", 50)), 2000) / 1000
    end = time.perf_counter() + budget
    n = 0
    while time.perf_counter() < end:
        n += 1
    return jsonify(report="generated", iterations=n)


@app.get("/api/flaky")
def flaky():
    """Fails with HTTP 500 for ?fail=1, or randomly at ERROR_RATE (0..1)."""
    if request.args.get("fail") == "1" or random.random() < float(os.environ.get("ERROR_RATE", "0")):
        return jsonify(error="upstream timetable service unavailable"), 500
    return jsonify(status="ok")


@app.get("/health")
def health():
    return jsonify(status="alive")


@app.get("/ready")
def ready():
    return jsonify(status="ready")


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)
