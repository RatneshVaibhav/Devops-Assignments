"""ShelfShare API."""

import json
import logging
import time

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response, status
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import Counter
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app import __version__
from app.config import get_settings
from app.db import get_db
from app.models import Book
from app.schemas import BookCreate, BookOut, BookUpdate, Reservation, Stats

settings = get_settings()
logging.basicConfig(level=settings.log_level, format="%(message)s")
log = logging.getLogger("shelfshare")

app = FastAPI(title="ShelfShare API", version=__version__,
              description="Campus textbook exchange - list a book, reserve a book.")
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins.split(","),
                   allow_methods=["*"], allow_headers=["*"])

BOOKS_LISTED = Counter("shelfshare_books_listed_total", "Books listed for exchange")
BOOKS_RESERVED = Counter("shelfshare_books_reserved_total", "Books reserved")
Instrumentator(excluded_handlers=["/health", "/ready", "/metrics"]).instrument(app).expose(
    app, include_in_schema=False)


@app.middleware("http")
async def access_log(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    if request.url.path not in ("/health", "/ready", "/metrics"):
        log.info(json.dumps({"method": request.method, "path": request.url.path,
                             "status": response.status_code,
                             "duration_ms": round((time.perf_counter() - start) * 1000, 2)}))
    return response


def _get_or_404(db: Session, book_id: int) -> Book:
    book = db.get(Book, book_id)
    if book is None:
        raise HTTPException(status_code=404, detail="book not found")
    return book


@app.get("/health", tags=["ops"])
def health():
    """Liveness: the process is up."""
    return {"status": "ok", "version": __version__, "build": settings.build_sha[:12]}


@app.get("/ready", tags=["ops"])
def ready(response: Response, db: Session = Depends(get_db)):
    """Readiness: the database answers."""
    try:
        db.execute(text("SELECT 1"))
    except Exception as exc:  # noqa: BLE001 - any DB error means "not ready"
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "database unavailable", "error": type(exc).__name__}
    return {"status": "ready"}


@app.get("/api/books", response_model=list[BookOut], tags=["books"])
def list_books(db: Session = Depends(get_db),
               status_filter: str | None = Query(default=None, alias="status"),
               q: str | None = None, course: str | None = None):
    stmt = select(Book).order_by(Book.created_at.desc())
    if status_filter:
        stmt = stmt.where(Book.status == status_filter)
    if course:
        stmt = stmt.where(Book.course_code == course.upper())
    if q:
        like = f"%{q.lower()}%"
        stmt = stmt.where(func.lower(Book.title).like(like) | func.lower(Book.author).like(like))
    return db.scalars(stmt).all()


@app.get("/api/books/stats", response_model=Stats, tags=["books"])
def stats(db: Session = Depends(get_db)):
    by_status = dict(db.execute(select(Book.status, func.count()).group_by(Book.status)).all())
    top = db.execute(select(Book.course_code, func.count().label("n")).group_by(Book.course_code)
                     .order_by(func.count().desc()).limit(5)).all()
    return {"total": sum(by_status.values()),
            "by_status": {s: by_status.get(s, 0) for s in ("available", "reserved", "exchanged")},
            "top_courses": [{"course_code": c, "books": n} for c, n in top]}


@app.get("/api/books/{book_id}", response_model=BookOut, tags=["books"])
def get_book(book_id: int, db: Session = Depends(get_db)):
    return _get_or_404(db, book_id)


@app.post("/api/books", response_model=BookOut, status_code=201, tags=["books"])
def create_book(payload: BookCreate, db: Session = Depends(get_db)):
    book = Book(**payload.model_dump())
    db.add(book)
    db.commit()
    db.refresh(book)
    BOOKS_LISTED.inc()
    return book


@app.put("/api/books/{book_id}", response_model=BookOut, tags=["books"])
def update_book(book_id: int, payload: BookUpdate, db: Session = Depends(get_db)):
    book = _get_or_404(db, book_id)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(book, field, value)
    if payload.status == "available":
        book.reserved_by = None
    db.commit()
    db.refresh(book)
    return book


@app.post("/api/books/{book_id}/reserve", response_model=BookOut, tags=["books"])
def reserve_book(book_id: int, payload: Reservation, db: Session = Depends(get_db)):
    book = _get_or_404(db, book_id)
    if book.status != "available":
        raise HTTPException(status_code=409, detail=f"book is already {book.status}")
    book.status = "reserved"
    book.reserved_by = payload.reserved_by
    db.commit()
    db.refresh(book)
    BOOKS_RESERVED.inc()
    return book


@app.delete("/api/books/{book_id}", status_code=204, tags=["books"])
def delete_book(book_id: int, db: Session = Depends(get_db)):
    db.delete(_get_or_404(db, book_id))
    db.commit()
    return Response(status_code=204)
