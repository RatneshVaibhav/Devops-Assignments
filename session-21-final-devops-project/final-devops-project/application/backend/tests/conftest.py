"""Tests run against an in-memory SQLite database, never against Postgres."""

import os

os.environ["DATABASE_URL"] = "sqlite+pysqlite://"

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from app.db import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402

engine = create_engine("sqlite+pysqlite://", connect_args={"check_same_thread": False},
                       poolclass=StaticPool)
TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


@pytest.fixture
def client():
    Base.metadata.create_all(engine)

    def override_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
    Base.metadata.drop_all(engine)


@pytest.fixture
def book(client):
    payload = {"title": "Operating System Concepts", "author": "Silberschatz",
               "course_code": "CS301", "condition": "good", "owner_name": "Ratnesh"}
    return client.post("/api/books", json=payload).json()
