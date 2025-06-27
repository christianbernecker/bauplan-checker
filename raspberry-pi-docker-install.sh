#!/bin/bash

# 🐳 Docker Installation auf Home Assistant OS
echo "🐳 Versuche Docker-Installation auf Home Assistant OS..."

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. System-Info
print_status "System-Information:"
echo "OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')"
echo "Architektur: $(uname -m)"
echo "Kernel: $(uname -r)"
echo ""

# 2. Prüfe ob Docker bereits vorhanden
print_status "Prüfe vorhandene Docker-Installation..."
if command -v docker &> /dev/null; then
    print_success "Docker bereits installiert!"
    docker --version
    docker ps 2>/dev/null && print_success "Docker läuft bereits" || print_warning "Docker läuft nicht"
    exit 0
fi

# 3. Prüfe Package Manager
print_status "Prüfe Package Manager..."
if command -v apk &> /dev/null; then
    print_success "Alpine Package Manager (apk) gefunden"
    PACKAGE_MANAGER="apk"
elif command -v apt &> /dev/null; then
    print_success "APT Package Manager gefunden"
    PACKAGE_MANAGER="apt"
else
    print_error "Kein unterstützter Package Manager gefunden"
    exit 1
fi

# 4. Docker Installation versuchen
print_status "Versuche Docker-Installation mit $PACKAGE_MANAGER..."

case $PACKAGE_MANAGER in
    "apk")
        print_status "Alpine: Installiere Docker..."
        # Update package index
        apk update || print_warning "apk update fehlgeschlagen"
        
        # Install Docker
        apk add docker docker-compose || {
            print_error "Docker-Installation über apk fehlgeschlagen"
            print_status "Versuche alternative Installation..."
            
            # Alternative: Docker via script
            print_status "Lade Docker-Installationsskript..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            chmod +x get-docker.sh
            sh get-docker.sh || print_error "Docker-Script-Installation fehlgeschlagen"
            rm get-docker.sh
        }
        ;;
    "apt")
        print_status "Debian/Ubuntu: Installiere Docker..."
        apt update || print_warning "apt update fehlgeschlagen"
        
        # Install prerequisites
        apt install -y ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Set up the repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        ;;
esac

# 5. Docker-Service starten
print_status "Starte Docker-Service..."
if command -v systemctl &> /dev/null; then
    systemctl enable docker 2>/dev/null || print_warning "systemctl enable fehlgeschlagen"
    systemctl start docker 2>/dev/null || print_warning "systemctl start fehlgeschlagen"
elif command -v service &> /dev/null; then
    service docker start 2>/dev/null || print_warning "service start fehlgeschlagen"
elif command -v rc-service &> /dev/null; then
    # Alpine Linux
    rc-update add docker boot 2>/dev/null || print_warning "rc-update add fehlgeschlagen"
    rc-service docker start 2>/dev/null || print_warning "rc-service start fehlgeschlagen"
fi

# 6. Docker-Installation prüfen
print_status "Prüfe Docker-Installation..."
sleep 3

if command -v docker &> /dev/null; then
    print_success "Docker erfolgreich installiert!"
    docker --version
    
    # Test Docker
    print_status "Teste Docker..."
    if docker ps &> /dev/null; then
        print_success "Docker läuft erfolgreich!"
        
        # Teste mit Hello World
        print_status "Teste Docker mit Hello World Container..."
        docker run --rm hello-world && print_success "Docker Test erfolgreich!" || print_warning "Docker Test fehlgeschlagen"
        
    else
        print_warning "Docker installiert, aber läuft nicht. Versuche manuellen Start..."
        dockerd &
        sleep 5
        docker ps &> /dev/null && print_success "Docker läuft jetzt!" || print_error "Docker konnte nicht gestartet werden"
    fi
    
else
    print_error "Docker-Installation fehlgeschlagen"
    exit 1
fi

# 7. Benutzerrechte (falls möglich)
print_status "Konfiguriere Docker-Benutzerrechte..."
if command -v usermod &> /dev/null; then
    usermod -aG docker root 2>/dev/null || print_warning "usermod fehlgeschlagen"
fi

# 8. Bauplan-Checker Docker-Befehle erstellen
print_status "Erstelle Bauplan-Checker Docker-Skripte..."
mkdir -p /share/bauplan-checker

# Docker-Start-Skript
cat > /share/bauplan-checker/start-docker-backend.sh << 'EOF'
#!/bin/bash
cd /share/bauplan-checker

echo "🐳 Starte Bauplan-Checker mit Docker..."

# Stoppe vorhandene Container
docker stop bauplan-checker-backend 2>/dev/null || true
docker rm bauplan-checker-backend 2>/dev/null || true

# Erstelle Datenverzeichnisse
mkdir -p uploads din_norms analysis_results

# Starte Container
docker run -d \
  --name bauplan-checker-backend \
  -p 8000:8000 \
  -e OPENAI_API_KEY=${OPENAI_API_KEY:-"IHR-OPENAI-KEY-HIER"} \
  -e ENVIRONMENT=production \
  -e HOST=0.0.0.0 \
  -e PORT=8000 \
  -v $(pwd)/uploads:/app/uploads \
  -v $(pwd)/analysis_results:/app/analysis_results \
  -v $(pwd)/din_norms:/app/din_norms \
  --restart unless-stopped \
  ghcr.io/christianbernecker/bauplan-checker:latest python main.py

# Status prüfen
sleep 5
docker ps | grep bauplan-checker && echo "✅ Container läuft!" || echo "❌ Container-Start fehlgeschlagen"

echo "🌐 Backend URL: http://$(hostname -I | awk '{print $1}'):8000"
echo "📊 Container Logs: docker logs bauplan-checker-backend"
EOF

chmod +x /share/bauplan-checker/start-docker-backend.sh

# Docker-Test-Skript
cat > /share/bauplan-checker/test-docker-backend.sh << 'EOF'
#!/bin/bash
echo "🧪 Teste Docker Backend..."

# Container Status
echo "📊 Container Status:"
docker ps | grep bauplan-checker || echo "❌ Container läuft nicht"

# Health Check
echo "🩺 Health Check:"
curl -s http://localhost:8000/ && echo "✅ Backend erreichbar" || echo "❌ Backend nicht erreichbar"
curl -s http://localhost:8000/health && echo "✅ Health Check OK" || echo "❌ Health Check fehlgeschlagen"

# Container Logs
echo "📝 Container Logs (letzte 10 Zeilen):"
docker logs --tail 10 bauplan-checker-backend 2>/dev/null || echo "Keine Logs verfügbar"
EOF

chmod +x /share/bauplan-checker/test-docker-backend.sh

# 9. Zusammenfassung
echo ""
print_success "🎉 Docker-Installation abgeschlossen!"
echo ""
echo "🐳 DOCKER BEFEHLE:"
echo "  Status:     docker ps"
echo "  Logs:       docker logs bauplan-checker-backend"
echo "  Stop:       docker stop bauplan-checker-backend"
echo "  Remove:     docker rm bauplan-checker-backend"
echo ""
echo "🚀 BAUPLAN-CHECKER BEFEHLE:"
echo "  Start:      ./start-docker-backend.sh"
echo "  Test:       ./test-docker-backend.sh"
echo ""
echo "⚠️ WICHTIG: Setzen Sie Ihren OpenAI API Key:"
echo "export OPENAI_API_KEY=sk-proj-..."
echo ""
echo "🌐 Nach dem Start verfügbar:"
echo "  Backend:    http://$(hostname -I | awk '{print $1}'):8000"
echo "  API Docs:   http://$(hostname -I | awk '{print $1}'):8000/docs" 