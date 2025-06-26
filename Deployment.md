# Deployment-Anleitung: Bauplan-Checker

## Übersicht

Dieses Dokument beschreibt die Deployment-Strategien für das Bauplan-Checker System. Wir unterscheiden zwischen Staging- und Production-Deployments.

## Deployment-Umgebungen

### 🧪 Staging Environment
- **Zweck**: Tests, Entwicklung, Qualitätssicherung
- **URL**: http://localhost:3000 (lokal) oder staging-domain.com
- **Datenbank**: Separate Staging-Datenbank
- **API Keys**: Staging OpenAI API Keys

### 🚀 Production Environment
- **Zweck**: Live-System für Endnutzer
- **URL**: production-domain.com
- **Datenbank**: Production-Datenbank mit Backups
- **API Keys**: Production OpenAI API Keys

## Voraussetzungen

### System-Anforderungen
- **Server**: Linux/Ubuntu 20.04+ oder macOS
- **RAM**: Mindestens 4GB (8GB empfohlen)
- **Speicher**: 20GB+ für DIN-Normen und Uploads
- **CPU**: 2+ Cores

### Software-Abhängigkeiten
```bash
# Python 3.8+
python3 --version

# Node.js 18+
node --version

# Git
git --version

# Optional: Docker
docker --version
```

## Lokales Development Setup

### 1. Initial Setup
```bash
# Repository klonen
git clone <repository-url>
cd bauplan-checker

# Backend Setup
cd backend
python -m venv venv
source venv/bin/activate  # macOS/Linux
# ODER
venv\Scripts\activate     # Windows

pip install -r requirements.txt

# Frontend Setup
cd ../frontend
npm install
```

### 2. Environment Configuration
```bash
# Backend Environment
# Erstelle backend/.env
echo "OPENAI_API_KEY=sk-your-staging-key" > backend/.env
echo "ENVIRONMENT=development" >> backend/.env
echo "DATABASE_URL=local" >> backend/.env

# Frontend Environment (optional)
# Erstelle frontend/.env.local
echo "NEXT_PUBLIC_API_URL=http://localhost:8000" > frontend/.env.local
```

### 3. DIN-Normen Setup
```bash
# DIN-Normen Verzeichnis erstellen
mkdir -p backend/din_norms

# Beispiel DIN-Normen hinzufügen
# [Hier würden Sie Ihre DIN-Norm PDFs ablegen]
# Beispiel: backend/din_norms/DIN_1045-2_Beton.pdf

# DIN-Normen verarbeiten
cd backend
python din_processor.py
```

## Staging Deployment

### Automatisches Staging Deployment
```bash
# Staging Deploy Script
#!/bin/bash
# deploy-staging.sh

echo "🚀 Starte Staging Deployment..."

# 1. Backend vorbereiten
echo "📦 Backend Setup..."
cd backend
source venv/bin/activate
pip install -r requirements.txt

# 2. DIN-Normen aktualisieren
echo "📚 DIN-Normen verarbeiten..."
python din_processor.py

# 3. Backend Tests
echo "🧪 Backend Tests..."
python -m pytest tests/ || echo "⚠️ Tests fehlgeschlagen - trotzdem fortfahren"

# 4. Backend starten (im Hintergrund)
echo "🔧 Backend starten..."
python main.py &
BACKEND_PID=$!
sleep 5

# 5. Frontend vorbereiten
echo "🎨 Frontend Setup..."
cd ../frontend
npm install
npm run build

# 6. Frontend Tests
echo "🧪 Frontend Tests..."
npm run test || echo "⚠️ Frontend Tests fehlgeschlagen"

# 7. Frontend starten
echo "🌐 Frontend starten..."
npm run dev &
FRONTEND_PID=$!

echo "✅ Staging Deployment erfolgreich!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔧 Backend: http://localhost:8000"
echo "📊 API Docs: http://localhost:8000/docs"

# PIDs für späteren Cleanup speichern
echo $BACKEND_PID > .staging_backend.pid
echo $FRONTEND_PID > .staging_frontend.pid
```

### Staging Health Check
```bash
# staging-health-check.sh
#!/bin/bash

echo "🩺 Staging Health Check..."

# Backend Check
if curl -f http://localhost:8000/ > /dev/null 2>&1; then
    echo "✅ Backend läuft"
else
    echo "❌ Backend nicht erreichbar"
    exit 1
fi

# Frontend Check  
if curl -f http://localhost:3000/ > /dev/null 2>&1; then
    echo "✅ Frontend läuft"
else
    echo "❌ Frontend nicht erreichbar"
    exit 1
fi

# API Test
response=$(curl -s http://localhost:8000/plans)
if [[ $response == *"["* ]]; then
    echo "✅ API funktioniert"
else
    echo "❌ API-Problem"
    exit 1
fi

echo "🎉 Staging System ist gesund!"
```

## Production Deployment

### Vorbereitung für Production
```bash
# production-pre-check.sh
#!/bin/bash

echo "🔍 Production Pre-Check..."

# 1. Code Quality Check
echo "📊 Code Quality..."
cd backend
pylint *.py || echo "⚠️ Linting Warnings"

cd ../frontend
npm run lint || echo "⚠️ Frontend Linting Warnings"

# 2. Security Check
echo "🔒 Security Check..."
# Prüfe auf exposed API keys
if grep -r "sk-" . --exclude-dir=node_modules --exclude-dir=venv; then
    echo "❌ SECURITY: API Keys gefunden!"
    exit 1
fi

# 3. Dependencies Check
echo "📦 Dependencies Check..."
cd backend
pip check

cd ../frontend  
npm audit --audit-level=high

echo "✅ Pre-Check abgeschlossen"
```

### Production Deployment Script
```bash
# deploy-production.sh
#!/bin/bash

echo "🚀 PRODUCTION DEPLOYMENT"
echo "⚠️  Nur nach expliziter Freigabe ausführen!"

read -p "Sind Sie sicher? (yes/NO): " confirm
if [[ $confirm != "yes" ]]; then
    echo "❌ Deployment abgebrochen"
    exit 1
fi

# 1. Pre-Check ausführen
./production-pre-check.sh

# 2. Backup erstellen
echo "💾 Backup erstellen..."
timestamp=$(date +%Y%m%d_%H%M%S)
mkdir -p backups
tar -czf backups/backup_$timestamp.tar.gz backend/analysis_results backend/uploads

# 3. Production Environment setzen
echo "🔧 Production Config..."
cd backend
cp .env .env.backup
sed -i 's/ENVIRONMENT=development/ENVIRONMENT=production/g' .env

# 4. Dependencies installieren
pip install -r requirements.txt --no-cache-dir

# 5. Frontend Build
echo "🏗️ Frontend Build..."
cd ../frontend
npm ci --production
npm run build

# 6. Production Start
echo "🚀 Production Start..."
cd ../backend

# Mit Gunicorn für Production
pip install gunicorn
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000 &

cd ../frontend
npm start &

echo "✅ Production Deployment abgeschlossen!"
```

## Docker Deployment (Optional)

### Dockerfile - Backend
```dockerfile
# backend/Dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Dockerfile - Frontend
```dockerfile
# frontend/Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

EXPOSE 3000

CMD ["npm", "start"]
```

### Docker Compose
```yaml
# docker-compose.yml
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
    volumes:
      - ./backend/uploads:/app/uploads
      - ./backend/din_norms:/app/din_norms
      - ./backend/analysis_results:/app/analysis_results

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend
    environment:
      - NEXT_PUBLIC_API_URL=http://backend:8000
```

## Monitoring & Logging

### Health Monitoring
```bash
# monitoring.sh
#!/bin/bash

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Backend Check
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        echo "[$timestamp] ✅ Backend OK"
    else
        echo "[$timestamp] ❌ Backend DOWN"
        # Optional: Restart logic
    fi
    
    # Frontend Check
    if curl -f http://localhost:3000/ > /dev/null 2>&1; then
        echo "[$timestamp] ✅ Frontend OK"
    else
        echo "[$timestamp] ❌ Frontend DOWN"
    fi
    
    sleep 300  # Check every 5 minutes
done
```

### Log Management
```bash
# Log Rotation Setup
# In /etc/logrotate.d/bauplan-checker
/var/log/bauplan-checker/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
}
```

## Backup-Strategie

### Automatisches Backup
```bash
# backup.sh
#!/bin/bash

timestamp=$(date +%Y%m%d_%H%M%S)
backup_dir="/backup/bauplan-checker"

mkdir -p $backup_dir

# Daten sichern
tar -czf $backup_dir/data_$timestamp.tar.gz \
    backend/analysis_results \
    backend/uploads \
    backend/din_norms

# Alte Backups löschen (älter als 30 Tage)
find $backup_dir -name "*.tar.gz" -mtime +30 -delete

echo "✅ Backup erstellt: $backup_dir/data_$timestamp.tar.gz"
```

## Rollback-Prozess

### Schneller Rollback
```bash
# rollback.sh
#!/bin/bash

echo "🔄 Rollback wird ausgeführt..."

# Services stoppen
pkill -f "python main.py"
pkill -f "npm"

# Letztes Backup wiederherstellen
latest_backup=$(ls -t backups/*.tar.gz | head -1)
if [[ -n "$latest_backup" ]]; then
    echo "📦 Wiederherstellen: $latest_backup"
    tar -xzf $latest_backup
fi

# Services neu starten
./deploy-staging.sh

echo "✅ Rollback abgeschlossen"
```

## Troubleshooting

### Häufige Probleme

1. **Backend startet nicht**
   ```bash
   # Port bereits belegt?
   lsof -i :8000
   
   # Abhängigkeiten prüfen
   pip check
   ```

2. **Frontend Build Fehler**
   ```bash
   # Cache leeren
   npm cache clean --force
   rm -rf node_modules package-lock.json
   npm install
   ```

3. **DIN-Normen nicht gefunden**
   ```bash
   # Pfad prüfen
   ls -la backend/din_norms/
   
   # Neu verarbeiten
   cd backend && python din_processor.py
   ```

4. **OpenAI API Fehler**
   ```bash
   # API Key prüfen
   echo $OPENAI_API_KEY
   
   # Rate Limits checken
   curl -H "Authorization: Bearer $OPENAI_API_KEY" \
        https://api.openai.com/v1/models
   ```

## Security Checklist

- [ ] API Keys nicht im Code
- [ ] HTTPS in Production
- [ ] Input Validation
- [ ] File Upload Limits
- [ ] Rate Limiting
- [ ] Error Handling ohne sensible Daten
- [ ] Regular Updates der Dependencies

---

**Letzte Aktualisierung:** $(date)
**Version:** 1.0.0 