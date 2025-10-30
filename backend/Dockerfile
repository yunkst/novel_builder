# Multi-stage build for production optimization
FROM python:3.11-slim as builder

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Configure apt to use Aliyun mirror for faster downloads
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# Install system dependencies for building
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Configure PyPI to use Aliyun mirror
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/

# Copy configuration files
COPY pyproject.toml ./
RUN pip install --no-cache-dir -e .[dev]

# Production stage
FROM python:3.11-slim as production

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Configure apt to use Aliyun mirror for faster downloads
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources

# Install runtime system dependencies for Playwright
# Use the official Playwright recommended dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    # Base dependencies
    ca-certificates \
    build-essential \
    pkg-config \
    # Playwright browser dependencies (minimal working set)
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libxss1 \
    libgtk-3-0 \
    # Additional libraries that are commonly available
    libglib2.0-0 \
    libdbus-1-3 \
    libx11-6 \
    libxcb1 \
    libxext6 \
    libxrender1 \
    libxi6 \
    libxcursor1 \
    libxinerama1 \
    libxtst6 \
    libxt6 \
    libpng16-16 \
    libjpeg62-turbo \
    libtiff6 \
    # Font support
    fonts-liberation \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy installed packages from builder stage
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Install Playwright browsers and system dependencies as root
RUN python -m playwright install chromium
RUN python -m playwright install-deps chromium

# Copy application code
COPY ./app ./app

# Copy alembic config
COPY ./alembic.ini ./
COPY ./alembic ./alembic

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

# Start the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]