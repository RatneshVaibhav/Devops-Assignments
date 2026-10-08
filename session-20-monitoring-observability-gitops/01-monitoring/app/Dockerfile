FROM python:3.12-alpine
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && adduser -D -H -u 10001 appuser
COPY main.py .
USER 10001
EXPOSE 8000
# one worker with threads: prometheus_client keeps metrics per process
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "8", "--worker-tmp-dir", "/tmp", "--no-control-socket", "main:app"]
