# 🏠 Bauplan-Checker auf Raspberry Pi mit Home Assistant

## Überblick
Diese Anleitung zeigt, wie Sie das Bauplan-Checker System auf Ihrem Raspberry Pi mit Home Assistant implementieren und im gesamten Netzwerk verfügbar machen.

## 📋 Voraussetzungen

### Hardware
- Raspberry Pi 4 (4GB RAM empfohlen)
- Mindestens 32GB SD-Karte (Class 10)
- Stabile Internetverbindung

### Software
- Home Assistant OS oder Home Assistant Container
- SSH-Zugang zum Raspberry Pi
- Docker (optional, aber empfohlen)

## 🚀 Installation Methoden

### Methode 1: Docker Container (Empfohlen)

#### 1. Docker-Setup auf Raspberry Pi
```bash
# Docker installieren (falls nicht vorhanden)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Docker Compose installieren
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

#### 2. Bauplan-Checker Container erstellen
```dockerfile
# Dockerfile für Raspberry Pi
FROM python:3.11-slim

# System-Dependencies
RUN apt-get update && apt-get install -y \
    tesseract-ocr \
    tesseract-ocr-deu \
    poppler-utils \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python Dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App Code
COPY backend/ ./backend/
COPY frontend/build ./frontend/

# Expose Ports
EXPOSE 8000 3000

# Start Script
COPY start-docker.sh .
RUN chmod +x start-docker.sh

CMD ["./start-docker.sh"]
```

#### 3. Docker Compose Setup
```yaml
# docker-compose.yml
version: '3.8'

services:
  bauplan-checker:
    build: .
    container_name: bauplan-checker
    ports:
      - "8000:8000"    # Backend API
      - "3000:3000"    # Frontend
    volumes:
      - ./data/uploads:/app/backend/uploads
      - ./data/din_norms:/app/backend/din_norms
      - ./data/analysis_results:/app/backend/analysis_results
      - ./data/system_prompts:/app/backend/system_prompts
    environment:
      - ENVIRONMENT=production
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    restart: unless-stopped
    networks:
      - bauplan-network
    
  # Optional: Reverse Proxy für HTTPS
  nginx:
    image: nginx:alpine
    container_name: bauplan-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - bauplan-checker
    restart: unless-stopped
    networks:
      - bauplan-network

networks:
  bauplan-network:
    driver: bridge

volumes:
  bauplan-data:
```

### Methode 2: Native Installation

#### 1. System vorbereiten
```bash
# System aktualisieren
sudo apt update && sudo apt upgrade -y

# Dependencies installieren
sudo apt install -y \
    python3 python3-pip python3-venv \
    tesseract-ocr tesseract-ocr-deu \
    poppler-utils \
    nodejs npm \
    git

# User für Bauplan-Checker erstellen
sudo useradd -m -s /bin/bash bauplan
sudo usermod -aG sudo bauplan
```

#### 2. App installieren
```bash
# Als bauplan user
sudo su - bauplan

# Repository klonen
git clone https://github.com/IHR_REPO/bauplan-checker.git
cd bauplan-checker

# Backend Setup
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Frontend Setup
cd ../frontend
npm install
npm run build

# Systemd Service erstellen
sudo nano /etc/systemd/system/bauplan-checker.service
```

#### 3. Systemd Service Konfiguration
```ini
[Unit]
Description=Bauplan-Checker Backend
After=network.target

[Service]
Type=simple
User=bauplan
Group=bauplan
WorkingDirectory=/home/bauplan/bauplan-checker/backend
Environment=PATH=/home/bauplan/bauplan-checker/backend/venv/bin
ExecStart=/home/bauplan/bauplan-checker/backend/venv/bin/python main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Service aktivieren
sudo systemctl daemon-reload
sudo systemctl enable bauplan-checker
sudo systemctl start bauplan-checker
```

## 🏠 Home Assistant Integration

### 1. Add-on Entwicklung (Erweitert)

#### addon_config.yaml
```yaml
name: "Bauplan-Checker"
description: "DIN-Normen Compliance Checker für Baupläne"
version: "1.0.0"
slug: "bauplan_checker"
init: false
arch:
  - armv7
  - aarch64
ports:
  8000/tcp: 8000
  3000/tcp: 3000
options:
  openai_api_key: ""
schema:
  openai_api_key: str
```

### 2. Home Assistant Dashboard Integration

#### Configuration.yaml Ergänzung
```yaml
# Home Assistant Integration
panel_iframe:
  bauplan_checker:
    title: "Bauplan-Checker"
    icon: mdi:file-document-outline
    url: "http://192.168.178.145:3000"
    require_admin: true

# Sensor für Systemstatus
sensor:
  - platform: rest
    name: bauplan_checker_status
    resource: http://192.168.178.145:8000/health
    value_template: '{{ value_json.status }}'
    scan_interval: 30
```

### 3. Automation Beispiele
```yaml
# automation.yaml
- alias: "Bauplan-Checker Notification"
  trigger:
    - platform: webhook
      webhook_id: bauplan_analysis_complete
  action:
    - service: notify.mobile_app
      data:
        title: "Bauplan-Analyse abgeschlossen"
        message: "Ihr Bauplan wurde erfolgreich gegen DIN-Normen geprüft"
```

## 🌐 Netzwerk-Konfiguration

### 1. Statische IP konfigurieren
```bash
# /etc/dhcpcd.conf
interface eth0
static ip_address=192.168.178.145/24
static routers=192.168.178.1
static domain_name_servers=192.168.178.1 8.8.8.8
```

### 2. Firewall Setup
```bash
# UFW Firewall
sudo ufw allow 22      # SSH
sudo ufw allow 8123    # Home Assistant
sudo ufw allow 8000    # Bauplan Backend
sudo ufw allow 3000    # Bauplan Frontend
sudo ufw enable
```

### 3. Nginx Reverse Proxy (Optional)
```nginx
# /etc/nginx/sites-available/bauplan-checker
server {
    listen 80;
    server_name bauplan.local 192.168.178.145;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🔧 Performance-Optimierungen für Raspberry Pi

### 1. Memory Management
```bash
# /boot/config.txt Ergänzungen
gpu_mem=128
arm_freq=1800
over_voltage=6

# Swap erweitern
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=2048
sudo dphys-swapfile setup
sudo dphys-swapfile swapon
```

### 2. Python Optimierungen
```python
# backend/config.py
import os

# Raspberry Pi spezifische Einstellungen
RASPBERRY_PI_MODE = True
MAX_WORKERS = 2  # Begrenzte CPU Cores
CHUNK_SIZE = 100  # Kleinere Chunks für weniger RAM
OCR_DPI = 150     # Reduzierte DPI für schnellere Verarbeitung
CACHE_ENABLED = True  # Aggressive Caching
```

## 📱 Mobile Zugriff einrichten

### 1. DynDNS Setup (optional)
```bash
# NoIP oder DuckDNS für externen Zugriff
echo 'url="https://duckdns.org/update?domains=IHRDOMAIN&token=IHRTOKEN&ip="' | sudo tee /usr/local/bin/duck.sh
sudo chmod 700 /usr/local/bin/duck.sh
echo '*/5 * * * * /usr/local/bin/duck.sh >/dev/null 2>&1' | sudo crontab
```

### 2. HTTPS mit Let's Encrypt
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d bauplan.ihrdomain.duckdns.org
```

## 🔒 Sicherheit

### 1. SSH Härten
```bash
# /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Port 2222
```

### 2. Fail2Ban installieren
```bash
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
```

## 📊 Monitoring & Wartung

### 1. Log Rotation
```bash
# /etc/logrotate.d/bauplan-checker
/home/bauplan/bauplan-checker/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    create 644 bauplan bauplan
}
```

### 2. Backup Script
```bash
#!/bin/bash
# backup-bauplan.sh
BACKUP_DIR="/home/bauplan/backups"
DATE=$(date +%Y%m%d_%H%M%S)

tar -czf "$BACKUP_DIR/bauplan_backup_$DATE.tar.gz" \
  /home/bauplan/bauplan-checker/backend/din_norms \
  /home/bauplan/bauplan-checker/backend/analysis_results \
  /home/bauplan/bauplan-checker/backend/system_prompts
```

## 🚀 Deployment Checklist

- [ ] Raspberry Pi Setup und Update
- [ ] Docker oder Native Installation
- [ ] OpenAI API Key konfiguriert
- [ ] DIN-Normen PDFs hochgeladen
- [ ] Home Assistant Integration getestet
- [ ] Netzwerk-Zugriff verifiziert
- [ ] Backup-Strategie implementiert
- [ ] Monitoring eingerichtet
- [ ] SSL/HTTPS konfiguriert (optional)

## 📞 Support & Troubleshooting

### Häufige Probleme:
1. **RAM-Mangel**: Swap erhöhen, Chunk-Größe reduzieren
2. **OCR langsam**: DPI reduzieren, weniger Sprachen
3. **Netzwerk-Probleme**: Firewall prüfen, statische IP setzen
4. **SSL-Fehler**: Zertifikate erneuern, Nginx-Config prüfen

### Log-Dateien:
- System: `/var/log/syslog`
- Bauplan-Checker: `/home/bauplan/bauplan-checker/logs/`
- Nginx: `/var/log/nginx/`
- Home Assistant: `/config/home-assistant.log`

Das System ist nach dieser Anleitung vollständig in Ihr Home Assistant integriert und im gesamten Netzwerk verfügbar! 🏠🚀 