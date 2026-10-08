"""HTTP layer for the Lost & Found API."""

import os

from flask import Flask, jsonify, request

from app import __version__
from app.store import ItemStore, ValidationError

app = Flask(__name__)
store = ItemStore()


@app.after_request
def security_headers(response):
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = "default-src 'none'"
    return response


@app.get("/health")
def health():
    return jsonify(status="ok", version=__version__, build=os.environ.get("BUILD_SHA", "local")[:12])


@app.get("/api/items")
def list_items():
    items = store.search(query=request.args.get("q"), category=request.args.get("category"))
    return jsonify(items=items, count=len(items))


@app.post("/api/items")
def report_item():
    try:
        item = store.report(request.get_json(silent=True) or {})
    except ValidationError as exc:
        return jsonify(error=str(exc)), 400
    return jsonify(item), 201


@app.get("/api/items/<int:item_id>")
def get_item(item_id):
    item = store.get(item_id)
    if item is None:
        return jsonify(error="not found"), 404
    return jsonify(item)


@app.post("/api/items/<int:item_id>/claim")
def claim_item(item_id):
    body = request.get_json(silent=True) or {}
    try:
        item = store.claim(item_id, body.get("claimant"))
    except ValidationError as exc:
        return jsonify(error=str(exc)), 409 if "already" in str(exc) else 400
    if item is None:
        return jsonify(error="not found"), 404
    return jsonify(item)
