ARG BUILD_FROM
FROM $BUILD_FROM

# Add-on Labels
LABEL \
  io.hass.name="Bauplan-Checker" \
  io.hass.description="🏗️ KI-basierte DIN-Normen Compliance Prüfung für Baupläne" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="addon" \
  io.hass.version="1.0.0" \
  maintainer="Christian Bernecker" \
  org.opencontainers.image.title="Bauplan-Checker" \
  org.opencontainers.image.description="DIN-Normen Compliance Checker für Baupläne" \
  org.opencontainers.image.source="https://github.com/christianbernecker/bauplan-checker" \
  org.opencontainers.image.licenses="MIT"

# Set environment variables
ENV LANG=C.UTF-8
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app
ENV NODE_ENV=production

# Install system dependencies
RUN apk update && apk add --no-cache \
    python3 \
    py3-pip \
    tesseract-ocr \
    tesseract-ocr-data-deu \
    tesseract-ocr-data-eng \
    poppler-utils \
    nodejs \
    npm \
    curl \
    bash \
    supervisor \
    py3-wheel \
    py3-setuptools \
    gcc \
    python3-dev \
    musl-dev \
    linux-headers \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy requirements first for better Docker layer caching
COPY requirements.txt /app/
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy backend source
COPY backend/ /app/backend/
COPY main.py /app/
COPY din_processor.py /app/
COPY technical_drawing_processor.py /app/

# Copy frontend source
COPY frontend/ /app/frontend/

# Build frontend
WORKDIR /app/frontend
RUN npm ci --only=production && npm run build

# Back to app directory
WORKDIR /app

# Create necessary directories with proper permissions
RUN mkdir -p \
    /share/bauplan-checker/uploads \
    /share/bauplan-checker/din_norms \
    /share/bauplan-checker/analysis_results \
    /share/bauplan-checker/system_prompts \
    /addon_config/logs \
    /app/uploads \
    /app/din_norms \
    /app/analysis_results \
    /app/system_prompts \
    && chmod -R 755 /share/bauplan-checker \
    && chmod -R 755 /addon_config \
    && chmod -R 755 /app

# Copy startup script
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose ports
EXPOSE 3000 8000

# Start with supervisor for process management
CMD ["/run.sh"] 