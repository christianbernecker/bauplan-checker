# 🏗️ Bauplan-Checker als Home Assistant Add-on

## 🎯 Warum ein Add-on?
- ✅ **Vollständig unterstützt** von Home Assistant
- ✅ **Einfache Installation** über Add-on Store
- ✅ **Automatische Backups** inklusive
- ✅ **Updates über Home Assistant** möglich
- ✅ **Perfekte Integration** in Home Assistant UI

## 📋 Add-on Struktur

```
bauplan-checker-addon/
├── config.yaml          # Add-on Konfiguration
├── Dockerfile           # Container Definition
├── run.sh              # Startup Script
├── README.md           # Dokumentation
└── CHANGELOG.md        # Versionshistorie
```

## 🔧 Schritt-für-Schritt Anleitung

### **1. Add-on Repository erstellen**

```bash
# Auf Ihrem Mac
mkdir -p ~/bauplan-checker-addon
cd ~/bauplan-checker-addon
```

### **2. config.yaml erstellen**

```yaml
name: "Bauplan-Checker"
description: "KI-basierte DIN-Normen Compliance Prüfung für Baupläne"
version: "1.0.0"
slug: "bauplan_checker"
init: false

# Architektur-Unterstützung
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

# Startup-Konfiguration
startup: application
boot: auto

# Benutzer-Optionen
options:
  openai_api_key: ""
  log_level: "info"

schema:
  openai_api_key: "str"
  log_level: "list(debug|info|warning|error)"

# Umgebungsvariablen
environment:
  OPENAI_API_KEY: openai_api_key
  LOG_LEVEL: log_level

# Volume-Mapping
map:
  - share:rw
  - addon_config:rw

# Backup-Einstellungen
backup: exclude
```

### **3. Dockerfile anpassen**

```dockerfile
ARG BUILD_FROM
FROM $BUILD_FROM

# Labels
LABEL \
  io.hass.name="Bauplan-Checker" \
  io.hass.description="DIN-Normen Compliance Checker" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.type="addon" \
  io.hass.version="${BUILD_VERSION}"

# Python und Dependencies installieren
RUN apk add --no-cache \
    python3 \
    py3-pip \
    nodejs \
    npm \
    bash

# Working Directory
WORKDIR /app

# Bauplan-Checker Files kopieren
COPY . /app/

# Python Dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Frontend Build (falls nötig)
RUN cd /app/frontend && npm install && npm run build

# Startup Script
COPY run.sh /
RUN chmod a+x /run.sh

CMD ["/run.sh"]
```

### **4. run.sh Script**

```bash
#!/usr/bin/with-contenv bashio

# Konfiguration laden
OPENAI_API_KEY=$(bashio::config 'openai_api_key')
LOG_LEVEL=$(bashio::config 'log_level')

# Umgebungsvariablen setzen
export OPENAI_API_KEY="${OPENAI_API_KEY}"
export LOG_LEVEL="${LOG_LEVEL}"

# Backend starten (im Hintergrund)
cd /app/backend
python3 main.py &

# Frontend starten
cd /app/frontend
npm start
```

## 🚀 Installation

### **1. Lokales Add-on installieren**

```bash
# Add-on Dateien nach Home Assistant kopieren
scp -r ~/bauplan-checker-addon/ root@192.168.178.145:/addons/local/

# Home Assistant neustarten
ssh root@192.168.178.145 "ha supervisor reload"
```

### **2. Add-on in Web-UI installieren**
- Settings → Add-ons → Local Add-ons
- "Bauplan-Checker" sollte erscheinen
- Installation und Konfiguration

## 🔍 Debugging

```bash
# Add-on Logs anzeigen
ha addons logs bauplan_checker

# Container Status
docker ps | grep bauplan_checker
```

## 📈 Vorteile dieser Lösung

- ✅ **Offiziell unterstützt** - keine Hack-Lösungen
- ✅ **Einfache Updates** über Home Assistant
- ✅ **Backup-Integration** automatisch
- ✅ **Web-UI Integration** seamless
- ✅ **Konfiguration** über Home Assistant UI
- ✅ **Logs** über Home Assistant verfügbar

## 🎯 Nächste Schritte

1. **Add-on entwickeln** (1-2 Stunden)
2. **Testen** auf Home Assistant
3. **Veröffentlichen** im HACS oder eigenem Repository
4. **Community** zur Verfügung stellen 