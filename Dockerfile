# ── Build stage: install Python dependencies ──────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install/deps -r requirements.txt

# ── Runtime stage ─────────────────────────────────────────────────────────
FROM python:3.12-slim

# Non-root user for least-privilege execution
RUN adduser --disabled-password --gecos "" ddns
WORKDIR /app

# Pull in installed packages from the build stage
COPY --from=builder /install/deps /usr/local
COPY ddns.py .

# Ensure the script is executable (good practice even when called via python)
RUN chmod 755 ddns.py
USER ddns

# Simple liveness probe: process is running
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD pgrep -f ddns.py || exit 1
ENTRYPOINT ["python", "-u", "ddns.py"]
