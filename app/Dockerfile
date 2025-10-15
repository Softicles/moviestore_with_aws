# Dockerfile
FROM python:3.12-slim

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# System deps (psycopg2 build, etc.); drop if SQLite initially
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev curl && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir gunicorn

COPY . .

# Collect static at build time (if you have whitenoise/static setup)
RUN python manage.py collectstatic --noinput || true

EXPOSE 8000
# USE environment for DB secrets via SSM/Secrets Manager at runtime (recommended)
CMD ["gunicorn", "movies.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
