# 🚀 Bauplan-Checker Raspberry Pi Deployment Anleitung

## 🎉 Docker Installation erfolgreich!

Basierend auf der erfolgreichen Docker-Installation auf deinem Raspberry Pi 5 mit Home Assistant OS, hier die komplette Deployment-Anleitung:

## 📋 Voraussetzungen (✅ Erfüllt)

- ✅ Raspberry Pi 5 mit Home Assistant OS
- ✅ SSH-Zugang (Advanced SSH & Web Terminal Add-on)
- ✅ Docker erfolgreich installiert
- ✅ OpenAI API Key verfügbar
- ✅ GitHub Container Registry Image bereit

## 🐳 Backend Deployment (Docker)

### 1. Docker Backend auf Raspberry Pi starten

```bash
# Zum Raspberry Pi SSH verbinden
# Dann das Docker-Deployment-Skript ausführen:

cd /share
./raspberry-pi-docker-deployment.sh
```

**Das Skript führt automatisch aus:**
- ✅ Docker Status prüfen
- ✅ OpenAI API Key konfigurieren
- ✅ Docker Image herunterladen (`ghcr.io/christianbernecker/bauplan-checker:latest`)
- ✅ Container mit korrekten Einstellungen starten
- ✅ Health Check durchführen
- ✅ Management-Skripte erstellen

### 2. Backend Management

Nach dem Deployment stehen dir folgende Befehle zur Verfügung:

```bash
cd /share/bauplan-checker

# Status prüfen
./status-docker-backend.sh

# Logs anzeigen
./logs-docker-backend.sh

# Backend stoppen
./stop-docker-backend.sh

# Backend starten
./start-docker-backend.sh

# API testen
./test-docker-backend.sh
```

### 3. Backend Endpoints

- **API**: http://192.168.2.19:8000
- **API Dokumentation**: http://192.168.2.19:8000/docs
- **Health Check**: http://192.168.2.19:8000/health

## 🌐 Frontend Deployment (GitHub Pages)

### 1. Frontend Build (✅ Abgeschlossen)

Das Frontend wurde bereits erfolgreich gebaut und zu GitHub gepusht:
- ✅ Next.js Build erstellt
- ✅ Statische Dateien in `frontend/docs/` generiert
- ✅ GitHub Repository aktualisiert

### 2. GitHub Pages aktivieren

**Manuelle Schritte:**

1. **GitHub Repository öffnen:**
   ```
   https://github.com/christianbernecker/bauplan-checker
   ```

2. **Settings Tab klicken**

3. **Zu "Pages" Sektion scrollen**

4. **GitHub Pages konfigurieren:**
   - **Source**: Deploy from a branch
   - **Branch**: main
   - **Folder**: /frontend/docs
   - **Save** klicken

5. **2-5 Minuten warten** auf Deployment

6. **Frontend wird verfügbar sein unter:**
   ```
   https://christianbernecker.github.io/bauplan-checker/
   ```

## 🔧 Vollständige Systemarchitektur

```
GitHub Pages Frontend  →  Raspberry Pi Backend  →  OpenAI API
(React/Next.js)           (Docker Container)        (GPT-4)
     ↓                           ↓                      ↓
Static Website            FastAPI Server         AI Analysis
```

## 🧪 System testen

### 1. Backend Test
```bash
# Auf dem Raspberry Pi:
curl http://localhost:8000/
curl http://localhost:8000/health
```

### 2. Frontend Test
```bash
# Im Browser öffnen:
https://christianbernecker.github.io/bauplan-checker/
```

### 3. End-to-End Test
1. Frontend im Browser öffnen
2. PDF-Bauplan hochladen
3. Basis-Analyse starten
4. DIN-Normen-Prüfung durchführen
5. Ergebnis prüfen

## 📊 Monitoring & Logs

### Docker Container Status
```bash
cd /share/bauplan-checker
./status-docker-backend.sh
```

### Live Logs verfolgen
```bash
cd /share/bauplan-checker
./logs-docker-backend.sh
```

### Resource Usage
```bash
docker stats bauplan-checker-backend
```

## 🔒 Sicherheit & Konfiguration

### OpenAI API Key
- ✅ Sicher in `/share/bauplan-checker/.env` gespeichert
- ✅ Nicht in Git-Repository
- ✅ Nur vom Docker Container lesbar

### Netzwerk
- ✅ Backend läuft auf Port 8000
- ✅ Nur lokales Netzwerk (192.168.2.19)
- ✅ Frontend über HTTPS (GitHub Pages)

## 🚨 Troubleshooting

### Backend startet nicht
```bash
# Container Logs prüfen
docker logs bauplan-checker-backend

# Container neu starten
docker restart bauplan-checker-backend
```

### API nicht erreichbar
```bash
# Port prüfen
netstat -tlnp | grep 8000

# Firewall prüfen (falls vorhanden)
iptables -L
```

### Frontend zeigt Fehler
1. Browser Developer Tools öffnen (F12)
2. Console auf Fehler prüfen
3. Network Tab auf API-Calls prüfen
4. Backend-Status prüfen

## 🔄 Updates & Wartung

### Backend Update
```bash
# Neues Docker Image ziehen
docker pull ghcr.io/christianbernecker/bauplan-checker:latest

# Container neu starten mit neuem Image
docker stop bauplan-checker-backend
docker rm bauplan-checker-backend
./raspberry-pi-docker-deployment.sh
```

### Frontend Update
```bash
# Auf dem Mac/Entwicklungsrechner:
./deploy-frontend-github-pages.sh
```

## 📈 Performance Optimierung

### Raspberry Pi
- **RAM**: 8GB empfohlen für AI-Workloads
- **Storage**: SSD für bessere Performance
- **Cooling**: Aktive Kühlung bei dauerhafter Nutzung

### Docker Container
- **Memory Limit**: 2GB gesetzt
- **CPU Limit**: 2 Cores
- **Auto-Restart**: Bei Fehlern

## 🎯 Nächste Schritte

1. **✅ Backend läuft** - Docker Container auf Raspberry Pi
2. **🔄 Frontend aktivieren** - GitHub Pages Settings
3. **🧪 System testen** - End-to-End Test durchführen
4. **📊 Monitoring einrichten** - Logs regelmäßig prüfen
5. **🔒 Backup erstellen** - DIN-Normen und Konfiguration

## 💡 Lessons Learned

### Was funktioniert hat:
- ✅ **Docker auf Home Assistant OS**: Alpine Package Manager (apk) funktioniert perfekt
- ✅ **GitHub Container Registry**: Schneller als Docker Hub
- ✅ **Multi-Architecture Images**: ARM64 Support wichtig
- ✅ **Statische Frontend Deployment**: GitHub Pages ist stabil

### Wichtige Erkenntnisse:
- 🎯 **Home Assistant Add-ons waren problematisch** - Docker direkter Ansatz besser
- 🎯 **Python-Installation funktionierte** - aber Docker eleganter
- 🎯 **OpenAI API Key Management** - Sichere .env Dateien essentiell
- 🎯 **Build-Optimierung** - Von 1+ Stunde auf 25 Sekunden reduziert

## 🆘 Support

Bei Problemen:
1. **Logs prüfen**: `./logs-docker-backend.sh`
2. **Status prüfen**: `./status-docker-backend.sh`
3. **Container neu starten**: `docker restart bauplan-checker-backend`
4. **GitHub Issues**: Für Bugs und Feature Requests

---

## 🎉 Herzlichen Glückwunsch!

Du hast erfolgreich den Bauplan-Checker als moderne Docker-Anwendung auf deinem Raspberry Pi 5 mit Home Assistant OS deployed! 

**System-URLs:**
- 🌐 **Frontend**: https://christianbernecker.github.io/bauplan-checker/
- 🔧 **Backend**: http://192.168.2.19:8000
- 📊 **API Docs**: http://192.168.2.19:8000/docs

Das System ist jetzt bereit für den produktiven Einsatz! 🚀 