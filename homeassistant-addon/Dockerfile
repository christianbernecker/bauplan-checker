ARG BUILD_FROM
FROM $BUILD_FROM

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
    bash

# Set working directory
WORKDIR /app

# Copy and install Python dependencies
COPY backend/requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy backend
COPY backend/ ./backend/

# Copy and build frontend
COPY frontend/ ./frontend/
WORKDIR /app/frontend
RUN npm ci --only=production && npm run build

# Back to app directory
WORKDIR /app

# Create directories
RUN mkdir -p \
    /share/bauplan-checker/uploads \
    /share/bauplan-checker/din_norms \
    /share/bauplan-checker/analysis_results \
    /share/bauplan-checker/system_prompts \
    /addon_config/logs

# Copy startup script
COPY homeassistant-addon/run.sh /run.sh
RUN chmod a+x /run.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

CMD ["/run.sh"] 