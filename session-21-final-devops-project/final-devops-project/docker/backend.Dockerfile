# ShelfShare API - build context: final-devops-project/
# ---- dependencies in a throw-away stage
FROM python:3.12-alpine AS deps
WORKDIR /build
COPY application/backend/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- runtime: code + dependencies, non-root
FROM python:3.12-alpine
ARG BUILD_SHA=local
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 BUILD_SHA=${BUILD_SHA}
COPY --from=deps /install /usr/local
WORKDIR /srv
COPY application/backend/alembic.ini ./
COPY application/backend/alembic ./alembic
COPY application/backend/app ./app
RUN adduser -D -H -u 10001 appuser
USER 10001
EXPOSE 8000
# migrations first (serialised with a Postgres advisory lock), then the API
CMD ["sh", "-c", "alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --no-server-header"]
