FROM python:3.12.11-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DO_NOT_TRACK=1
RUN pip install --no-cache-dir 'psycopg[binary]==3.2.9'
WORKDIR /app
COPY docker/bootstrap/bootstrap.py ./bootstrap.py
COPY supabase/migrations ./migrations
COPY supabase/seed.sql ./seed.sql
CMD ["python", "bootstrap.py"]
