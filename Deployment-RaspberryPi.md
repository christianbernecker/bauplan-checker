# 🍓 Bauplan-Checker Installation auf Raspberry Pi & Home Assistant

## Übersicht

Diese Anleitung beschreibt die Installation des Bauplan-Checkers auf:
1. **Raspberry Pi** (Standalone)
2. **Home Assistant Addon** 
3. **Docker auf Raspberry Pi**

---

## 🔧 **Option 1: Raspberry Pi Standalone Installation**

### Voraussetzungen
- Raspberry Pi 4 (4GB+ RAM empfohlen)
- Raspberry Pi OS (64-bit)
- Internetverbindung
- OpenAI API Key

### Schritt 1: System vorbereiten
```bash
# System aktualisieren
sudo apt update && sudo apt upgrade -y

# Docker installieren
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Docker Compose installieren
sudo pip3 install docker-compose
```

### Schritt 2: Bauplan-Checker installieren
```bash
# Repository klonen
git clone https://github.com/christianbernecker/bauplan-checker.git
cd bauplan-checker

# Environment konfigurieren
cp backend/env_example.txt backend/.env
nano backend/.env
```

**Wichtige Environment-Variablen:**
```bash
# In backend/.env
OPENAI_API_KEY=sk-your-openai-key-here
ENVIRONMENT=production
```

### Schritt 3: Mit Docker Compose starten
```bash
# Docker Container starten
docker-compose up -d

# Status prüfen
docker-compose ps
```

### Schritt 4: Zugriff testen
```bash
# Backend Test
curl http://localhost:8000/

# Frontend öffnen
# Im Browser: http://[raspberry-pi-ip]:3000
```

### Schritt 5: Autostart konfigurieren
```bash
# Systemd Service erstellen
sudo nano /etc/systemd/system/bauplan-checker.service
```

```ini
[Unit]
Description=Bauplan-Checker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/pi/bauplan-checker
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

```bash
# Service aktivieren
sudo systemctl enable bauplan-checker.service
sudo systemctl start bauplan-checker.service
```

---

## 🏠 **Option 2: Home Assistant Addon Installation**

### Schritt 1: Repository hinzufügen
1. **Home Assistant** → **Supervisor** → **Add-on Store**
2. **⋮** (drei Punkte) → **Repositories**
3. Repository URL hinzufügen:
   ```
   https://github.com/christianbernecker/bauplan-checker
   ```

### Schritt 2: Addon installieren
1. **Refresh** klicken
2. **Bauplan-Checker** Addon finden
3. **Install** klicken

### Schritt 3: Konfiguration
```yaml
# Addon Configuration
openai_api_key: "sk-your-openai-key-here"
log_level: "info"
ssl: false
certfile: ""
keyfile: ""
```

### Schritt 4: Addon starten
1. **Start** klicken
2. **Show in sidebar** aktivieren
3. **Auto-start** aktivieren

### Schritt 5: Zugriff
- **Web UI**: http://homeassistant.local:8123/hassio/addon/bauplan-checker/
- **Direkt**: http://[ha-ip]:3000

---

## 🐳 **Option 3: Docker Hub Installation (Einfachste)**

### Quick Start
```bash
# Neueste Version pullen und starten
docker run -d \
  --name bauplan-checker \
  -p 3000:3000 \
  -p 8000:8000 \
  -e OPENAI_API_KEY=your-key-here \
  --restart unless-stopped \
  ghcr.io/christianbernecker/bauplan-checker:latest
```

### Mit Persistenten Daten
```bash
# Datenverzeichnisse erstellen
mkdir -p ~/bauplan-checker/{uploads,analysis_results,din_norms}

# Mit Volume-Mounts starten
docker run -d \
  --name bauplan-checker \
  -p 3000:3000 \
  -p 8000:8000 \
  -e OPENAI_API_KEY=your-key-here \
  -v ~/bauplan-checker/uploads:/app/uploads \
  -v ~/bauplan-checker/analysis_results:/app/analysis_results \
  -v ~/bauplan-checker/din_norms:/app/din_norms \
  --restart unless-stopped \
  ghcr.io/christianbernecker/bauplan-checker:latest
```

---

## 📊 **Performance-Optimierung für Raspberry Pi**

### Memory Management
```bash
# In docker-compose.yml
services:
  bauplan-checker:
    image: ghcr.io/christianbernecker/bauplan-checker:latest
    mem_limit: 1g
    memswap_limit: 1g
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
```

### CPU-Optimierung
```bash
# Für Raspberry Pi 4
docker run \
  --cpus="2.0" \
  --memory="1g" \
  # ... weitere Parameter
```

### Swap aktivieren (falls nötig)
```bash
# Swap-Datei erstellen (2GB)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Permanent aktivieren
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 🔐 **Sicherheits-Konfiguration**

### Firewall Setup
```bash
# UFW installieren und konfigurieren
sudo apt install ufw
sudo ufw allow ssh
sudo ufw allow 3000  # Frontend
sudo ufw allow 8000  # Backend API
sudo ufw enable
```

### SSL/TLS mit Let's Encrypt (Optional)
```bash
# Certbot installieren
sudo apt install certbot

# Zertifikat anfordern
sudo certbot certonly --standalone -d your-domain.com

# Nginx Reverse Proxy
sudo apt install nginx
```

**Nginx Konfiguration:**
```nginx
# /etc/nginx/sites-available/bauplan-checker
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## 📱 **Home Assistant Integration**

### Sensor-Integration
```yaml
# configuration.yaml
rest:
  - resource: "http://localhost:8000/health"
    name: "Bauplan Checker Status"
    scan_interval: 60
    value_template: "{{ value_json.status }}"
    
  - resource: "http://localhost:8000/stats"
    name: "Bauplan Checker Stats"
    scan_interval: 300
    json_attributes:
      - total_analyses
      - success_rate
      - last_analysis
```

### Automation Beispiel
```yaml
# automation.yaml
- alias: "Bauplan Checker Down Alert"
  trigger:
    - platform: state
      entity_id: sensor.bauplan_checker_status
      to: "offline"
      for: "00:05:00"
  action:
    - service: notify.mobile_app_your_phone
      data:
        title: "⚠️ Bauplan-Checker offline"
        message: "Der Bauplan-Checker ist seit 5 Minuten nicht erreichbar."
```

---

## 🔧 **Troubleshooting**

### Häufige Probleme

**1. Container startet nicht:**
```bash
# Logs prüfen
docker logs bauplan-checker

# Memory prüfen
free -h
```

**2. Port bereits belegt:**
```bash
# Ports prüfen
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :8000

# Alternativen Ports verwenden
docker run -p 3001:3000 -p 8001:8000 ...
```

**3. OpenAI API Fehler:**
```bash
# API Key testen
curl -H "Authorization: Bearer sk-your-key" \
  https://api.openai.com/v1/models
```

**4. Performance-Probleme:**
```bash
# Container-Resources prüfen
docker stats bauplan-checker

# Raspberry Pi Temperatur
vcgencmd measure_temp
```

### Log-Monitoring
```bash
# Container-Logs live verfolgen
docker logs -f bauplan-checker

# System-Logs
journalctl -u bauplan-checker.service -f
```

---

## 🚀 **Updates**

### Container Update
```bash
# Neue Version pullen
docker pull ghcr.io/christianbernecker/bauplan-checker:latest

# Container neu starten
docker stop bauplan-checker
docker rm bauplan-checker

# Mit neuer Version starten
docker run -d \
  --name bauplan-checker \
  -p 3000:3000 \
  -p 8000:8000 \
  -e OPENAI_API_KEY=your-key-here \
  --restart unless-stopped \
  ghcr.io/christianbernecker/bauplan-checker:latest
```

### Automatische Updates
```bash
# Watchtower für Auto-Updates
docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --interval 86400 \
  bauplan-checker
```

---

## ✅ **Installation erfolgreich!**

Nach erfolgreicher Installation erreichen Sie den Bauplan-Checker unter:
- **Frontend**: http://[raspberry-pi-ip]:3000
- **API**: http://[raspberry-pi-ip]:8000
- **API Docs**: http://[raspberry-pi-ip]:8000/docs

**Viel Erfolg mit Ihrem Bauplan-Checker! 🎉** 