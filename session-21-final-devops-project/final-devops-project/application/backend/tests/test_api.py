def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_ready_checks_the_database(client):
    assert client.get("/ready").json() == {"status": "ready"}


def test_create_and_get_book(client, book):
    assert book["id"] > 0 and book["status"] == "available"
    res = client.get(f"/api/books/{book['id']}")
    assert res.status_code == 200
    assert res.json()["title"] == "Operating System Concepts"


def test_create_validates_course_code(client):
    res = client.post("/api/books", json={"title": "Some book", "author": "Someone",
                                          "course_code": "cs-301", "owner_name": "Ratnesh"})
    assert res.status_code == 422


def test_list_filters_by_status_and_text(client, book):
    client.post("/api/books", json={"title": "Computer Networks", "author": "Tanenbaum",
                                    "course_code": "CS305", "owner_name": "Aditi"})
    client.post(f"/api/books/{book['id']}/reserve", json={"reserved_by": "Kabir"})
    assert len(client.get("/api/books").json()) == 2
    assert [b["title"] for b in client.get("/api/books?status=available").json()] == ["Computer Networks"]
    assert len(client.get("/api/books?q=silber").json()) == 1


def test_update_book(client, book):
    res = client.put(f"/api/books/{book['id']}", json={"condition": "worn"})
    assert res.status_code == 200
    assert res.json()["condition"] == "worn"


def test_reserve_only_once(client, book):
    first = client.post(f"/api/books/{book['id']}/reserve", json={"reserved_by": "Kabir"})
    assert first.status_code == 200 and first.json()["reserved_by"] == "Kabir"
    second = client.post(f"/api/books/{book['id']}/reserve", json={"reserved_by": "Meera"})
    assert second.status_code == 409


def test_delete_book(client, book):
    assert client.delete(f"/api/books/{book['id']}").status_code == 204
    assert client.get(f"/api/books/{book['id']}").status_code == 404


def test_stats(client, book):
    client.post(f"/api/books/{book['id']}/reserve", json={"reserved_by": "Kabir"})
    data = client.get("/api/books/stats").json()
    assert data["total"] == 1
    assert data["by_status"] == {"available": 0, "reserved": 1, "exchanged": 0}
    assert data["top_courses"] == [{"course_code": "CS301", "books": 1}]


def test_metrics_endpoint(client, book):
    body = client.get("/metrics").text
    assert "shelfshare_books_listed_total" in body
    assert "http_requests_total" in body
