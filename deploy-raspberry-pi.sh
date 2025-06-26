#!/bin/bash

# Bauplan-Checker Raspberry Pi Deployment Script
# Läuft auf Raspberry Pi mit Home Assistant Integration

set -e

echo "🏠🍓 Starte Bauplan-Checker Raspberry Pi Deployment..."

# Farben für bessere Ausgabe
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

# 1. System-Checks
print_status "Prüfe System-Voraussetzungen..."

if ! command -v docker &> /dev/null; then
    print_error "Docker ist nicht installiert!"
    print_status "Installiere Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_success "Docker installiert. Bitte neu anmelden und Script erneut ausführen."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_status "Installiere Docker Compose..."
    sudo pip3 install docker-compose
fi

# 2. Architektur prüfen
ARCH=$(uname -m)
print_status "System-Architektur: $ARCH"

if [[ "$ARCH" != "aarch64" && "$ARCH" != "armv7l" ]]; then
    print_warning "Dieses Script ist für Raspberry Pi optimiert, aber läuft auch auf $ARCH"
fi

# 3. Verzeichnisse erstellen
print_status "Erstelle Daten-Verzeichnisse..."
mkdir -p data/{uploads,din_norms,analysis_results,system_prompts}
mkdir -p logs
mkdir -p nginx/{ssl,logs}

# 4. .env Datei erstellen (falls nicht vorhanden)
if [ ! -f .env ]; then
    print_status "Erstelle .env Datei..."
    cat > .env << EOF
# OpenAI API Configuration
OPENAI_API_KEY=your_openai_api_key_here

# System Configuration
ENVIRONMENT=production
HOST=0.0.0.0
PORT=8000

# Home Assistant Integration
HASS_TOKEN=your_homeassistant_token_here
HASS_URL=http://homeassistant.local:8123

# Network Configuration
RASPBERRY_PI_IP=192.168.178.145
EOF
    print_warning "Bitte .env Datei mit Ihren API-Keys bearbeiten!"
    print_warning "OPENAI_API_KEY muss gesetzt werden!"
fi

# 5. OpenAI API Key prüfen
source .env
if [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
    print_error "OPENAI_API_KEY in .env Datei muss gesetzt werden!"
    exit 1
fi

# 6. DIN-Normen kopieren (falls vorhanden)
if [ -d "backend/din_norms" ] && [ "$(ls -A backend/din_norms/*.pdf 2>/dev/null)" ]; then
    print_status "Kopiere vorhandene DIN-Normen..."
    cp backend/din_norms/*.pdf data/din_norms/ 2>/dev/null || true
    cp backend/din_norms/*.json data/din_norms/ 2>/dev/null || true
    print_success "DIN-Normen kopiert"
fi

# 7. System-Prompts kopieren
if [ -d "backend/system_prompts" ]; then
    print_status "Kopiere System-Prompts..."
    cp backend/system_prompts/* data/system_prompts/ 2>/dev/null || true
fi

# 8. Nginx Konfiguration erstellen
print_status "Erstelle Nginx Konfiguration..."
cat > nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Optimierungen für Raspberry Pi
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;
    
    # Gzip Kompression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
    
    # Upstream für Backend
    upstream bauplan_backend {
        server bauplan-backend:8000;
    }
    
    # Upstream für Frontend
    upstream bauplan_frontend {
        server bauplan-frontend:3000;
    }
    
    # Main Server
    server {
        listen 80;
        server_name bauplan-checker.local;
        
        # Frontend
        location / {
            proxy_pass http://bauplan_frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # API Backend
        location /api/ {
            rewrite ^/api/(.*) /$1 break;
            proxy_pass http://bauplan_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 300s;
            proxy_connect_timeout 75s;
        }
        
        # Health Check für Home Assistant
        location /health {
            proxy_pass http://bauplan_backend/health;
            proxy_set_header Host $host;
            access_log off;
        }
        
        # Statistiken für Home Assistant  
        location /statistics {
            proxy_pass http://bauplan_backend/statistics;
            proxy_set_header Host $host;
        }
        
        # Static Files
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            proxy_pass http://bauplan_frontend;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
EOF

# 9. Docker Images erstellen
print_status "Baue Docker Images..."
if ! docker-compose build --no-cache; then
    print_error "Docker Build fehlgeschlagen!"
    exit 1
fi

# 10. Services starten
print_status "Starte Services..."
docker-compose down --remove-orphans
docker-compose up -d

# 11. Warten auf Services
print_status "Warte auf Services..."
sleep 30

# 12. Health Check
print_status "Prüfe Service-Status..."

check_service() {
    local service_name="$1"
    local url="$2"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            print_success "$service_name ist bereit"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name ist nicht erreichbar nach $max_attempts Versuchen"
    return 1
}

echo -n "Backend Check"
check_service "Backend" "http://localhost:8000/health"

echo -n "Frontend Check" 
check_service "Frontend" "http://localhost:3000"

# 13. DIN-Normen verarbeiten (falls vorhanden)
if [ "$(ls -A data/din_norms/*.pdf 2>/dev/null)" ]; then
    print_status "Verarbeite DIN-Normen..."
    docker-compose exec -T bauplan-checker-backend python3 -c "
from backend.din_processor import DINNormProcessor
processor = DINNormProcessor()
result = processor.process_din_pdfs()
print(f'✅ {result} DIN-Norm Chunks verarbeitet')
" || print_warning "DIN-Normen Verarbeitung übersprungen"
fi

# 14. Home Assistant Integration Info
print_success "🏠 Deployment abgeschlossen!"
echo ""
echo "======================================"
echo "🍓 RASPBERRY PI ZUGRIFF:"
echo "======================================"
echo "Frontend:     http://$(hostname -I | awk '{print $1}'):3000"
echo "Backend API:  http://$(hostname -I | awk '{print $1}'):8000"
echo "Health Check: http://$(hostname -I | awk '{print $1}'):8000/health"
echo "Statistiken:  http://$(hostname -I | awk '{print $1}'):8000/statistics"
echo ""
echo "======================================"
echo "🏠 HOME ASSISTANT INTEGRATION:"
echo "======================================"
echo "1. Kopiere home-assistant-config.yaml in Ihre configuration.yaml"
echo "2. Passe die IP-Adresse an: $(hostname -I | awk '{print $1}')"
echo "3. Ersetze 'mobile_app_your_device' mit Ihrem Geräte-Namen"
echo "4. Starten Sie Home Assistant neu"
echo ""
echo "Dashboard Entities:"
echo "- sensor.bauplan_checker_backend_status"
echo "- sensor.bauplan_checker_stats"
echo "- sensor.bauplan_checker_din_status"
echo "- binary_sensor.bauplan_checker_online"
echo ""
echo "======================================"
echo "📊 CONTAINER STATUS:"
docker-compose ps
echo "======================================"
echo ""
echo "Logs anzeigen:     docker-compose logs -f"
echo "Services stoppen:  docker-compose down"
echo "Services neustarten: docker-compose restart"
echo ""
print_success "Bauplan-Checker läuft erfolgreich auf Raspberry Pi!" 