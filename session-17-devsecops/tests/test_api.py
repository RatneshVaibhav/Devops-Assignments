import pytest

from app.main import app, store


@pytest.fixture
def client():
    store.__init__()          # fresh store per test
    app.config["TESTING"] = True
    with app.test_client() as c:
        yield c


def report(client, **overrides):
    body = {"title": "Black Lenovo charger", "category": "electronics", "location": "Library 2nd floor"}
    body.update(overrides)
    return client.post("/api/items", json=body)


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "ok"


def test_security_headers(client):
    res = client.get("/health")
    assert res.headers["X-Content-Type-Options"] == "nosniff"
    assert res.headers["X-Frame-Options"] == "DENY"


def test_report_and_get_item(client):
    res = report(client)
    assert res.status_code == 201
    item_id = res.get_json()["id"]
    assert client.get(f"/api/items/{item_id}").get_json()["title"] == "Black Lenovo charger"


def test_report_requires_title(client):
    res = report(client, title="  ")
    assert res.status_code == 400


def test_report_rejects_unknown_category(client):
    assert report(client, category="pets").status_code == 400


def test_report_rejects_markup_in_location(client):
    assert report(client, location="<script>alert(1)</script>").status_code == 400


def test_search_by_text_and_category(client):
    report(client)
    report(client, title="Blue umbrella", category="other", location="Main gate")
    assert client.get("/api/items?q=lenovo").get_json()["count"] == 1
    assert client.get("/api/items?category=other").get_json()["count"] == 1


def test_claim_once_only(client):
    item_id = report(client).get_json()["id"]
    first = client.post(f"/api/items/{item_id}/claim", json={"claimant": "Ratnesh"})
    assert first.status_code == 200 and first.get_json()["status"] == "claimed"
    second = client.post(f"/api/items/{item_id}/claim", json={"claimant": "Someone else"})
    assert second.status_code == 409


def test_missing_item_is_404(client):
    assert client.get("/api/items/999").status_code == 404
