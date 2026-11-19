# Production Multi-Stage Dockerfile for FastAPI Backend
FROM python:3.12-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Final minimal runtime image
FROM python:3.12-slim as runner

WORKDIR /app

# Install runtime libpq for PostgreSQL connectivity
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy installed packages from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Create non-root application user
RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g appgroup -s /bin/bash appuser

# Copy application source code
COPY --chown=appuser:appgroup . /app

# Create upload directories with appropriate permissions
RUN mkdir -p /app/uploads/thumbnails && \
    chown -R appuser:appgroup /app/uploads

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://127.0.0.1:8000/api/v1/health || exit 1

CMD ["sh", "-c", "alembic upgrade head && uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2"]
