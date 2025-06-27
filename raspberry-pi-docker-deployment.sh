#!/bin/bash

# ========================================
# BAUPLAN-CHECKER DOCKER DEPLOYMENT
# Raspberry Pi 5 mit Home Assistant OS
# ========================================

set -e  # Exit bei Fehler

echo "🚀 BAUPLAN-CHECKER DOCKER DEPLOYMENT"
echo "======================================"

# Farben für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ========================================
# 1. SYSTEM-VORBEREITUNG
# ========================================

print_status "System-Vorbereitung..."

# Arbeitsverzeichnis erstellen
WORK_DIR="/share/bauplan-checker"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

print_success "Arbeitsverzeichnis: $WORK_DIR"

# ========================================
# 2. DOCKER STATUS PRÜFEN
# ========================================

print_status "Docker Status prüfen..."

if ! command -v docker &> /dev/null; then
    print_error "Docker ist nicht installiert!"
    print_status "Führe zuerst ./raspberry-pi-docker-install.sh aus"
    exit 1
fi

if ! docker ps &> /dev/null; then
    print_warning "Docker Service starten..."
    service docker start
    sleep 3
fi

print_success "Docker ist verfügbar"

# ========================================
# 3. OPENAI API KEY SETUP
# ========================================

print_status "OpenAI API Key Setup..."

ENV_FILE="$WORK_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    print_warning "Erstelle .env Datei..."
    cat > "$ENV_FILE" << 'EOF'
# OpenAI API Configuration
OPENAI_API_KEY=YOUR_OPENAI_API_KEY_HERE

# Application Configuration
ENVIRONMENT=production
DEBUG=false
HOST=0.0.0.0
PORT=8000

# Raspberry Pi Configuration
PLATFORM=raspberry-pi
ARCHITECTURE=aarch64
EOF
    print_success ".env Datei erstellt"
else
    print_success ".env Datei bereits vorhanden"
fi

# ========================================
# 4. DOCKER IMAGE HERUNTERLADEN
# ========================================

print_status "Docker Image herunterladen..."

DOCKER_IMAGE="ghcr.io/christianbernecker/bauplan-checker:latest"

print_status "Lade Image: $DOCKER_IMAGE"
docker pull "$DOCKER_IMAGE"

print_success "Docker Image erfolgreich heruntergeladen"

# ========================================
# 5. ALTE CONTAINER STOPPEN
# ========================================

print_status "Alte Container stoppen..."

# Stoppe alle bauplan-checker Container
if docker ps -q --filter "name=bauplan-checker" | grep -q .; then
    print_warning "Stoppe laufende Container..."
    docker stop $(docker ps -q --filter "name=bauplan-checker")
    docker rm $(docker ps -aq --filter "name=bauplan-checker")
    print_success "Alte Container entfernt"
else
    print_status "Keine laufenden Container gefunden"
fi

# ========================================
# 6. VERZEICHNISSE ERSTELLEN
# ========================================

print_status "Verzeichnisse erstellen..."

mkdir -p "$WORK_DIR/uploads"
mkdir -p "$WORK_DIR/analysis_results"
mkdir -p "$WORK_DIR/din_norms"
mkdir -p "$WORK_DIR/logs"

# Berechtigungen setzen
chmod 755 "$WORK_DIR"
chmod 777 "$WORK_DIR/uploads"
chmod 777 "$WORK_DIR/analysis_results"
chmod 755 "$WORK_DIR/din_norms"
chmod 755 "$WORK_DIR/logs"

print_success "Verzeichnisse erstellt"

# ========================================
# 7. DOCKER CONTAINER STARTEN
# ========================================

print_status "Docker Container starten..."

CONTAINER_NAME="bauplan-checker-backend"

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file "$ENV_FILE" \
  -v "$WORK_DIR/uploads:/app/uploads" \
  -v "$WORK_DIR/analysis_results:/app/analysis_results" \
  -v "$WORK_DIR/din_norms:/app/din_norms" \
  -v "$WORK_DIR/logs:/app/logs" \
  --platform linux/arm64 \
  "$DOCKER_IMAGE"

print_success "Docker Container gestartet: $CONTAINER_NAME"

# ========================================
# 8. HEALTH CHECK
# ========================================

print_status "Health Check durchführen..."

sleep 10  # Container Zeit zum Starten geben

# Prüfe ob Container läuft
if docker ps --filter "name=$CONTAINER_NAME" --filter "status=running" | grep -q "$CONTAINER_NAME"; then
    print_success "Container läuft erfolgreich"
else
    print_error "Container ist nicht gestartet!"
    print_status "Container Logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# API Health Check
print_status "API Erreichbarkeit prüfen..."
for i in {1..30}; do
    if curl -f http://localhost:8000/ > /dev/null 2>&1; then
        print_success "API ist erreichbar!"
        break
    fi
    
    if [ $i -eq 30 ]; then
        print_error "API nicht erreichbar nach 30 Versuchen"
        print_status "Container Logs:"
        docker logs "$CONTAINER_NAME" --tail 50
        exit 1
    fi
    
    print_status "Warte auf API... ($i/30)"
    sleep 2
done

# ========================================
# 9. MANAGEMENT SKRIPTE ERSTELLEN
# ========================================

print_status "Management-Skripte erstellen..."

# Start Script
cat > "$WORK_DIR/start-docker-backend.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starte Bauplan-Checker Backend..."
docker start bauplan-checker-backend
echo "✅ Backend gestartet!"
echo "🌐 API: http://localhost:8000"
echo "📊 Docs: http://localhost:8000/docs"
EOF

# Stop Script
cat > "$WORK_DIR/stop-docker-backend.sh" << 'EOF'
#!/bin/bash
echo "🛑 Stoppe Bauplan-Checker Backend..."
docker stop bauplan-checker-backend
echo "✅ Backend gestoppt!"
EOF

# Status Script
cat > "$WORK_DIR/status-docker-backend.sh" << 'EOF'
#!/bin/bash
echo "📊 BAUPLAN-CHECKER STATUS"
echo "========================="

# Container Status
if docker ps --filter "name=bauplan-checker-backend" --filter "status=running" | grep -q "bauplan-checker-backend"; then
    echo "✅ Container: LÄUFT"
else
    echo "❌ Container: GESTOPPT"
fi

# API Status
if curl -f http://localhost:8000/ > /dev/null 2>&1; then
    echo "✅ API: ERREICHBAR"
else
    echo "❌ API: NICHT ERREICHBAR"
fi

# Resource Usage
echo ""
echo "📈 RESOURCE USAGE:"
docker stats bauplan-checker-backend --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo ""
echo "📋 CONTAINER INFO:"
docker ps --filter "name=bauplan-checker-backend" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF

# Logs Script
cat > "$WORK_DIR/logs-docker-backend.sh" << 'EOF'
#!/bin/bash
echo "📋 BAUPLAN-CHECKER LOGS"
echo "======================="
docker logs bauplan-checker-backend --tail 100 -f
EOF

# Test Script
cat > "$WORK_DIR/test-docker-backend.sh" << 'EOF'
#!/bin/bash
echo "🧪 BAUPLAN-CHECKER API TEST"
echo "==========================="

# Basic API Test
echo "1. API Ping Test:"
curl -s http://localhost:8000/ | head -n 5

echo -e "\n2. Health Check:"
curl -s http://localhost:8000/health 2>/dev/null || echo "Health endpoint nicht verfügbar"

echo -e "\n3. Plans Endpoint:"
curl -s http://localhost:8000/plans | head -n 10

echo -e "\n4. Container Status:"
docker ps --filter "name=bauplan-checker-backend"

echo -e "\n✅ Test abgeschlossen!"
EOF

# Skripte ausführbar machen
chmod +x "$WORK_DIR"/*.sh

print_success "Management-Skripte erstellt"

# ========================================
# 10. DEPLOYMENT ZUSAMMENFASSUNG
# ========================================

echo ""
echo "🎉 DEPLOYMENT ERFOLGREICH ABGESCHLOSSEN!"
echo "========================================"
echo ""
echo "📍 Installation Details:"
echo "   • Arbeitsverzeichnis: $WORK_DIR"
echo "   • Container Name: $CONTAINER_NAME"
echo "   • Docker Image: $DOCKER_IMAGE"
echo ""
echo "🌐 Verfügbare Endpoints:"
echo "   • API: http://localhost:8000"
echo "   • API Docs: http://localhost:8000/docs"
echo "   • Health: http://localhost:8000/health"
echo ""
echo "🛠️ Management Befehle:"
echo "   • Status prüfen: ./status-docker-backend.sh"
echo "   • Logs anzeigen: ./logs-docker-backend.sh"
echo "   • Backend stoppen: ./stop-docker-backend.sh"
echo "   • Backend starten: ./start-docker-backend.sh"
echo "   • API testen: ./test-docker-backend.sh"
echo ""
echo "📁 Wichtige Verzeichnisse:"
echo "   • Uploads: $WORK_DIR/uploads"
echo "   • Ergebnisse: $WORK_DIR/analysis_results"
echo "   • DIN-Normen: $WORK_DIR/din_norms"
echo "   • Logs: $WORK_DIR/logs"
echo ""

# Container Status anzeigen
docker ps --filter "name=$CONTAINER_NAME"

echo ""
print_success "Bauplan-Checker Backend läuft erfolgreich auf dem Raspberry Pi!"
print_status "Nächster Schritt: Frontend auf GitHub Pages aktivieren"

# ========================================
# 11. AUTO-START SETUP (OPTIONAL)
# ========================================

read -p "Soll der Container automatisch beim Boot starten? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Auto-Start wird konfiguriert..."
    
    # Docker Container ist bereits mit --restart unless-stopped gestartet
    # Zusätzlich systemd Service erstellen
    
    cat > /etc/systemd/system/bauplan-checker.service << EOF
[Unit]
Description=Bauplan-Checker Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/docker start bauplan-checker-backend
ExecStop=/usr/bin/docker stop bauplan-checker-backend
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable bauplan-checker.service
    
    print_success "Auto-Start konfiguriert!"
else
    print_status "Auto-Start übersprungen"
fi

echo ""
print_success "🎯 Deployment vollständig abgeschlossen!" 