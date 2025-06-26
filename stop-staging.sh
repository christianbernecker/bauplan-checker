#!/bin/bash

# Bauplan-Checker Staging Stop Script
# Sauberes Beenden der Staging-Services

echo "🛑 Stoppe Bauplan-Checker Staging-System..."

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Backend stoppen
if [ -f "backend/.staging_backend.pid" ]; then
    BACKEND_PID=$(cat backend/.staging_backend.pid)
    if ps -p $BACKEND_PID > /dev/null 2>&1; then
        log_info "Stoppe Backend (PID: $BACKEND_PID)..."
        kill $BACKEND_PID
        sleep 2
        if ps -p $BACKEND_PID > /dev/null 2>&1; then
            log_warning "Force-Kill Backend..."
            kill -9 $BACKEND_PID 2>/dev/null || true
        fi
        log_success "Backend gestoppt"
    else
        log_info "Backend bereits gestoppt"
    fi
    rm -f backend/.staging_backend.pid
else
    log_info "Keine Backend-PID gefunden"
fi

# Frontend stoppen
if [ -f "frontend/.staging_frontend.pid" ]; then
    FRONTEND_PID=$(cat frontend/.staging_frontend.pid)
    if ps -p $FRONTEND_PID > /dev/null 2>&1; then
        log_info "Stoppe Frontend (PID: $FRONTEND_PID)..."
        kill $FRONTEND_PID
        sleep 2
        if ps -p $FRONTEND_PID > /dev/null 2>&1; then
            log_warning "Force-Kill Frontend..."
            kill -9 $FRONTEND_PID 2>/dev/null || true
        fi
        log_success "Frontend gestoppt"
    else
        log_info "Frontend bereits gestoppt"
    fi
    rm -f frontend/.staging_frontend.pid
else
    log_info "Keine Frontend-PID gefunden"
fi

# Alle Python-Prozesse mit main.py stoppen
log_info "Stoppe alle main.py Prozesse..."
pkill -f "python main.py" 2>/dev/null || true
pkill -f "python3 main.py" 2>/dev/null || true

# Alle npm dev Prozesse stoppen
log_info "Stoppe alle npm dev Prozesse..."
pkill -f "npm run dev" 2>/dev/null || true

# Ports prüfen
log_info "Prüfe Ports..."
if lsof -ti:8000 > /dev/null 2>&1; then
    log_warning "Port 8000 noch belegt"
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true
fi

if lsof -ti:3000 > /dev/null 2>&1; then
    log_warning "Port 3000 noch belegt"
    lsof -ti:3000 | xargs kill -9 2>/dev/null || true
fi

log_success "✅ Staging-System erfolgreich gestoppt!"
echo ""
echo "🔄 Zum erneuten Starten: ./deploy-staging.sh" 