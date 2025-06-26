#!/bin/bash

# Bauplan-Checker Staging Deployment Script
# Automatisches Deployment für Tests und Entwicklung

set -e  # Exit bei Fehler

echo "🚀 Starte Staging Deployment für Bauplan-Checker..."
echo "=================================================="

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktionen
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Vorprüfungen
log_info "Führe Vorprüfungen durch..."

# Python Version prüfen
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version)
    log_success "Python gefunden: $PYTHON_VERSION"
else
    log_error "Python3 nicht gefunden!"
    exit 1
fi

# Node.js Version prüfen
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    log_success "Node.js gefunden: $NODE_VERSION"
else
    log_error "Node.js nicht gefunden!"
    exit 1
fi

# 2. Backend Setup
log_info "📦 Backend Setup..."
cd backend

# Virtual Environment erstellen falls nicht vorhanden
if [ ! -d "venv" ]; then
    log_info "Erstelle Python Virtual Environment..."
    python3 -m venv venv
fi

# Virtual Environment aktivieren
log_info "Aktiviere Virtual Environment..."
source venv/bin/activate

# Dependencies installieren
log_info "Installiere Python Dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Environment prüfen
if [ ! -f ".env" ]; then
    log_warning ".env Datei nicht gefunden!"
    if [ -f "env_example.txt" ]; then
        log_info "Erstelle .env aus Beispiel-Datei..."
        cp env_example.txt .env
        log_warning "Bitte tragen Sie Ihren OPENAI_API_KEY in die .env Datei ein!"
    fi
fi

# Verzeichnisse erstellen
log_info "Erstelle notwendige Verzeichnisse..."
mkdir -p uploads
mkdir -p din_norms
mkdir -p analysis_results

# DIN-Normen Status prüfen
DIN_COUNT=$(find din_norms -name "*.pdf" 2>/dev/null | wc -l)
if [ "$DIN_COUNT" -eq 0 ]; then
    log_warning "Keine DIN-Norm PDFs in din_norms/ gefunden"
    log_info "Bitte fügen Sie DIN-Norm PDFs hinzu für vollständige Funktionalität"
else
    log_success "$DIN_COUNT DIN-Norm PDFs gefunden"
    log_info "Verarbeite DIN-Normen..."
    python din_processor.py || log_warning "DIN-Normen Verarbeitung mit Fehlern"
fi

# Backend Tests (falls vorhanden)
log_info "🧪 Backend Tests..."
if [ -d "tests" ]; then
    python -m pytest tests/ -v || log_warning "Tests fehlgeschlagen - trotzdem fortfahren"
else
    log_info "Keine Tests gefunden"
fi

# Backend im Hintergrund starten
log_info "🔧 Backend starten..."
python main.py &
BACKEND_PID=$!
echo $BACKEND_PID > .staging_backend.pid

# Warten bis Backend bereit ist
log_info "Warte auf Backend..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        log_success "Backend ist bereit!"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "Backend konnte nicht gestartet werden"
        kill $BACKEND_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# 3. Frontend Setup
log_info "🎨 Frontend Setup..."
cd ../frontend

# Dependencies installieren
log_info "Installiere Node.js Dependencies..."
npm install

# Frontend Build
log_info "Baue Frontend..."
npm run build

# Frontend Tests (falls vorhanden)
if [ -f "package.json" ] && grep -q "\"test\"" package.json; then
    log_info "🧪 Frontend Tests..."
    npm run test -- --passWithNoTests || log_warning "Frontend Tests fehlgeschlagen"
fi

# Frontend im Hintergrund starten
log_info "🌐 Frontend starten..."
npm run dev &
FRONTEND_PID=$!
echo $FRONTEND_PID > .staging_frontend.pid

# Warten bis Frontend bereit ist
log_info "Warte auf Frontend..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null 2>&1; then
        log_success "Frontend ist bereit!"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "Frontend konnte nicht gestartet werden"
        kill $FRONTEND_PID 2>/dev/null || true
        kill $BACKEND_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

# 4. Health Checks
log_info "🩺 System Health Checks..."

# Backend Health Check
if curl -s http://localhost:8000/health | grep -q "healthy"; then
    log_success "✅ Backend Health Check erfolgreich"
else
    log_warning "⚠️ Backend Health Check fehlgeschlagen"
fi

# Frontend Health Check
if curl -s http://localhost:3000 > /dev/null; then
    log_success "✅ Frontend Health Check erfolgreich"
else
    log_warning "⚠️ Frontend Health Check fehlgeschlagen"
fi

# API Test
if curl -s http://localhost:8000/plans | grep -q "\["; then
    log_success "✅ API funktioniert"
else
    log_warning "⚠️ API-Problem erkannt"
fi

# 5. Deployment-Informationen
cd ..
echo ""
echo "🎉 Staging Deployment abgeschlossen!"
echo "======================================"
echo ""
log_success "🌐 Frontend:     http://localhost:3000"
log_success "🔧 Backend:      http://localhost:8000"
log_success "📊 API Docs:     http://localhost:8000/docs"
echo ""
echo "📋 PIDs:"
echo "   Backend PID:  $BACKEND_PID"
echo "   Frontend PID: $FRONTEND_PID"
echo ""
echo "🛑 Zum Stoppen:"
echo "   ./stop-staging.sh"
echo ""

# 6. System-Informationen
log_info "📊 System-Status:"
echo "   - Backend läuft auf Port 8000"
echo "   - Frontend läuft auf Port 3000"
echo "   - DIN-Normen: $DIN_COUNT PDFs"
echo "   - Environment: $(grep ENVIRONMENT backend/.env 2>/dev/null || echo 'development')"
echo ""

# 7. Nächste Schritte
echo "🔄 Nächste Schritte:"
echo "   1. Öffnen Sie http://localhost:3000 im Browser"
echo "   2. Testen Sie den PDF-Upload"
echo "   3. Prüfen Sie die DIN-Normen-Funktionalität"
echo "   4. Geben Sie Feedback für kontinuierliche Verbesserung"
echo ""

# 8. Log-Files
LOG_DIR="logs"
mkdir -p $LOG_DIR
echo "Backend-PID: $BACKEND_PID, Frontend-PID: $FRONTEND_PID" > $LOG_DIR/staging_deployment.log
echo "Deployment-Zeit: $(date)" >> $LOG_DIR/staging_deployment.log

log_success "Deployment erfolgreich abgeschlossen! 🚀"

# Automatisches Monitoring starten (optional)
if command -v watch &> /dev/null; then
    echo ""
    log_info "💡 Tipp: Starten Sie 'watch -n 5 ./health-check.sh' für kontinuierliches Monitoring"
fi 