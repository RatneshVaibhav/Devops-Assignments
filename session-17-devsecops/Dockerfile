# Minimal, non-root image for the Lost & Found API.
# Alpine instead of slim: Trivy finds 0 HIGH/CRITICAL CVEs in python:3.12-alpine,
# 44 (all unfixed Debian packages) in python:3.12-slim - see README.
FROM python:3.12-alpine
ARG BUILD_SHA=local
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 BUILD_SHA=${BUILD_SHA}
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
 && adduser -D -H -u 10001 -s /sbin/nologin appuser
COPY app ./app
USER 10001
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--worker-tmp-dir", "/tmp", "--no-control-socket", "app.main:app"]
