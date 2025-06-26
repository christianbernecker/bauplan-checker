#!/bin/bash

# 🏗️ Bauplan-Checker Add-on Installation Script
# Für Home Assistant Terminal & SSH Add-on

echo "🏗️ Installing Bauplan-Checker Add-on..."

# Verzeichnisse erstellen
echo "📁 Creating directories..."
mkdir -p /addons/local/bauplan_checker

# Add-on Konfiguration erstellen
echo "⚙️ Creating config.yaml..."
cat > /addons/local/bauplan_checker/config.yaml << 'EOF'
name: "Bauplan-Checker"
description: "🏗️ KI-basierte DIN-Normen Compliance Prüfung für Baupläne mit OCR und AI-Analyse"
version: "1.0.0"
slug: "bauplan_checker"
init: false

# Architektur-Unterstützung (nur 64-bit für bessere Performance)
arch:
  - aarch64
  - amd64

# Port-Mapping
ports:
  3000/tcp: 3000
  8000/tcp: 8000

ports_description:
  3000/tcp: "Frontend Web Interface"
  8000/tcp: "Backend API"

# Web-UI Integration
webui: "http://[HOST]:[PORT:3000]"
panel_icon: "mdi:file-document-outline"
panel_title: "Bauplan-Checker"
panel_admin: true

# Startup-Konfiguration
startup: application
boot: auto

# Add-on Kategorien
stage: stable
advanced: false

# Benutzer-Optionen
options:
  openai_api_key: ""
  log_level: "info"
  max_monthly_budget: 20.0
  warn_at_budget: 15.0

schema:
  openai_api_key: "str"
  log_level: "list(debug|info|warning|error)"
  max_monthly_budget: "float(5.0,100.0)"
  warn_at_budget: "float(1.0,50.0)"

# Umgebungsvariablen
environment:
  OPENAI_API_KEY: openai_api_key
  LOG_LEVEL: log_level
  MAX_MONTHLY_BUDGET: max_monthly_budget
  WARN_AT_BUDGET: warn_at_budget
  ENVIRONMENT: production
  PYTHONPATH: /app

# Volume-Mapping für persistente Daten
map:
  - share:rw
  - addon_config:rw

# Backup-Einstellungen (Include für wichtige Daten)
backup: exclude

# Privilegien
privileged:
  - SYS_ADMIN

# Host-Netzwerk für bessere Integration
host_network: false
host_pid: false

# Zusätzliche Konfiguration
url: "https://github.com/christianbernecker/bauplan-checker"
codenotary: notarize@home-assistant.io

# Dokumentation
documentation: "https://github.com/christianbernecker/bauplan-checker/blob/main/README.md"
repository: "https://github.com/christianbernecker/bauplan-checker"

# Support-Informationen
support: "https://github.com/christianbernecker/bauplan-checker/issues"
EOF

# Dockerfile erstellen
echo "🐳 Creating Dockerfile..."
cat > /addons/local/bauplan_checker/Dockerfile << 'EOF'
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
    git \
    && rm -rf /var/cache/apk/*

# Create app directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt /app/
RUN pip3 install --no-cache-dir -r requirements.txt

# Clone repository for backend and frontend
RUN git clone https://github.com/christianbernecker/bauplan-checker.git /tmp/bauplan-checker

# Copy backend files
RUN cp -r /tmp/bauplan-checker/backend/* /app/ && \
    cp /tmp/bauplan-checker/main.py /app/ && \
    cp /tmp/bauplan-checker/din_processor.py /app/ && \
    cp /tmp/bauplan-checker/technical_drawing_processor.py /app/

# Copy and build frontend
RUN cp -r /tmp/bauplan-checker/frontend /app/ && \
    cd /app/frontend && \
    npm ci --only=production && \
    npm run build

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

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose ports
EXPOSE 3000 8000

# Start with run script
CMD ["/run.sh"]
EOF

# run.sh erstellen
echo "🚀 Creating run.sh..."
cat > /addons/local/bauplan_checker/run.sh << 'EOF'
#!/usr/bin/with-contenv bashio

# Bash strict mode
set -euo pipefail

# Add-on Informationen
bashio::log.info "🏗️ Starting Bauplan-Checker Add-on v1.0.0"

# Konfiguration laden und validieren
if bashio::config.has_value 'openai_api_key'; then
    export OPENAI_API_KEY=$(bashio::config 'openai_api_key')
else
    bashio::log.fatal "❌ OpenAI API Key ist erforderlich! Bitte in den Add-on Optionen konfigurieren."
    exit 1
fi

export LOG_LEVEL=$(bashio::config 'log_level' 'info')
export MAX_MONTHLY_BUDGET=$(bashio::config 'max_monthly_budget' '20.0')
export WARN_AT_BUDGET=$(bashio::config 'warn_at_budget' '15.0')
export ENVIRONMENT="production"
export PYTHONPATH="/app"

# Log-Konfiguration anzeigen
bashio::log.info "📋 Konfiguration:"
bashio::log.info "  Log Level: ${LOG_LEVEL}"
bashio::log.info "  Max Monthly Budget: $${MAX_MONTHLY_BUDGET}"
bashio::log.info "  Warning Budget: $${WARN_AT_BUDGET}"

# Verzeichnisse vorbereiten
bashio::log.info "📁 Vorbereitung der Datenverzeichnisse..."

# Share-Verzeichnisse erstellen
mkdir -p /share/bauplan-checker/{uploads,din_norms,analysis_results,system_prompts}

# Lokale Verzeichnisse mit Share verlinken
ln -sf /share/bauplan-checker/uploads /app/uploads
ln -sf /share/bauplan-checker/analysis_results /app/analysis_results

# DIN-Normen kopieren falls vorhanden
if [ -d "/share/bauplan-checker/din_norms" ] && [ "$(ls -A /share/bauplan-checker/din_norms 2>/dev/null)" ]; then
    bashio::log.info "📚 Kopiere DIN-Normen aus Share-Verzeichnis..."
    cp -r /share/bauplan-checker/din_norms/* /app/din_norms/ 2>/dev/null || true
else
    bashio::log.info "📚 Keine DIN-Normen im Share-Verzeichnis gefunden"
fi

# System-Prompts kopieren
if [ -d "/share/bauplan-checker/system_prompts" ] && [ "$(ls -A /share/bauplan-checker/system_prompts 2>/dev/null)" ]; then
    bashio::log.info "📝 Kopiere System-Prompts aus Share-Verzeichnis..."
    cp -r /share/bauplan-checker/system_prompts/* /app/system_prompts/ 2>/dev/null || true
fi

# Standard System-Prompts erstellen falls nicht vorhanden
if [ ! -f "/app/system_prompts/din_analysis_prompt.md" ]; then
    bashio::log.info "📝 Erstelle Standard System-Prompts..."
    mkdir -p /app/system_prompts
    cat > /app/system_prompts/din_analysis_prompt.md << 'PROMPT_EOF'
# DIN-Normen Analyse Prompt

Du bist ein Experte für deutsche DIN-Normen im Bauwesen. Analysiere den gegebenen Bauplan-Text gegen die verfügbaren DIN-Normen und erstelle einen detaillierten Compliance-Bericht.

## Aufgaben:
1. Identifiziere relevante DIN-Normen für den Bauplan
2. Prüfe die Einhaltung der Normen
3. Liste Abweichungen und Verstöße auf
4. Gib konkrete Verbesserungsvorschläge

## Format:
- Verwende klare, professionelle Sprache
- Strukturiere die Antwort mit Überschriften
- Gib konkrete Norm-Referenzen an
- Priorisiere kritische Verstöße
PROMPT_EOF
fi

# Berechtigungen setzen
chmod -R 755 /share/bauplan-checker
chmod -R 755 /app

# Backend starten
bashio::log.info "🔧 Backend wird gestartet..."
cd /app
python3 main.py &
BACKEND_PID=$!

# Warten auf Backend
sleep 10
bashio::log.info "⏳ Warte auf Backend-Start..."
for i in {1..30}; do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        bashio::log.info "✅ Backend ist bereit!"
        break
    fi
    bashio::log.info "   Versuch ${i}/30..."
    sleep 2
done

# Frontend starten
bashio::log.info "🎨 Frontend wird gestartet..."
cd /app/frontend
npm start &
FRONTEND_PID=$!

# Warten auf Frontend
sleep 10
bashio::log.info "⏳ Warte auf Frontend-Start..."
for i in {1..20}; do
    if curl -sf http://localhost:3000 > /dev/null 2>&1; then
        bashio::log.info "✅ Frontend ist bereit!"
        break
    fi
    bashio::log.info "   Versuch ${i}/20..."
    sleep 3
done

# Status-Ausgabe
bashio::log.info "🎉 Bauplan-Checker Add-on erfolgreich gestartet!"
bashio::log.info "🌐 Frontend: http://homeassistant.local:3000"
bashio::log.info "🔧 Backend API: http://homeassistant.local:8000"
bashio::log.info "📊 Health Check: http://homeassistant.local:8000/health"

# Keep running und Monitor processes
while true; do
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        bashio::log.error "Backend process died, restarting..."
        cd /app
        python3 main.py &
        BACKEND_PID=$!
    fi
    
    if ! kill -0 $FRONTEND_PID 2>/dev/null; then
        bashio::log.error "Frontend process died, restarting..."
        cd /app/frontend
        npm start &
        FRONTEND_PID=$!
    fi
    
    sleep 30
done
EOF

# requirements.txt erstellen
echo "📦 Creating requirements.txt..."
cat > /addons/local/bauplan_checker/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
python-multipart==0.0.6
PyPDF2==3.0.1
pytesseract==0.3.10
Pillow==10.1.0
pdf2image==1.16.3
opencv-python==4.8.1.78
numpy==1.25.2
matplotlib==3.8.2
openai==1.3.7
python-dotenv==1.0.0
faiss-cpu==1.7.4
scikit-learn==1.3.2
psutil==5.9.6
aiofiles==0.23.0
asyncio==3.4.3
pathlib==1.0.1
tempfile==0.0.0
logging==0.0.0
datetime==0.0.0
typing==0.0.0
EOF

# README erstellen
echo "📝 Creating README.md..."
cat > /addons/local/bauplan_checker/README.md << 'EOF'
# 🏗️ Bauplan-Checker Home Assistant Add-on

KI-basierte automatische Prüfung von Ingenieursplänen gegen deutsche DIN-Normen.

## Features
- 🤖 KI-basierte Analyse mit OpenAI GPT-4
- 📋 DIN-Normen Compliance Checking
- 🔍 OCR-Unterstützung für gescannte Dokumente
- 💰 Budget-Überwachung für API-Kosten
- 🎨 Moderne Web-UI mit React/Next.js

## Konfiguration

```yaml
openai_api_key: "sk-your-openai-api-key-here"
log_level: "info"
max_monthly_budget: 20.0
warn_at_budget: 15.0
```

## Installation
1. Add-on installieren
2. OpenAI API Key konfigurieren
3. Add-on starten
4. Web-UI öffnen

## Support
GitHub: https://github.com/christianbernecker/bauplan-checker
EOF

# Berechtigungen setzen
chmod +x /addons/local/bauplan_checker/run.sh

echo "✅ Add-on Struktur erstellt!"
echo "📍 Pfad: /addons/local/bauplan_checker/"

# Supervisor reload
echo "🔄 Home Assistant Supervisor wird neu geladen..."
ha supervisor reload

echo "🎉 Installation abgeschlossen!"
echo ""
echo "📋 Nächste Schritte:"
echo "1. Gehen Sie zu Settings → Add-ons"
echo "2. Suchen Sie nach 'Bauplan-Checker' unter Local Add-ons"
echo "3. Klicken Sie auf INSTALL"
echo "4. Konfigurieren Sie Ihren OpenAI API Key"
echo "5. Starten Sie das Add-on"
echo ""
echo "🌐 Web-UI wird verfügbar sein unter: http://192.168.178.145:3000" 