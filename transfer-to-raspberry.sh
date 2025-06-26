#!/bin/bash

# Bauplan-Checker auf Raspberry Pi übertragen
# Übertragung aller Dateien auf einmal

set -e

# Farben für bessere Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Konfiguration
RASPBERRY_IP="192.168.178.145"  # Ihre Raspberry Pi IP
RASPBERRY_USER="pi"             # Standard Raspberry Pi User
REMOTE_PATH="/home/pi/bauplan-checker"

# Parameter prüfen
if [ "$1" != "" ]; then
    RASPBERRY_IP="$1"
fi

if [ "$2" != "" ]; then
    RASPBERRY_USER="$2"
fi

echo "🍓 Übertrage Bauplan-Checker auf Raspberry Pi..."
echo "Target: ${RASPBERRY_USER}@${RASPBERRY_IP}:${REMOTE_PATH}"
echo ""

# 1. Verbindung testen
print_status "Teste Verbindung zum Raspberry Pi..."
if ! ping -c 1 "$RASPBERRY_IP" > /dev/null 2>&1; then
    print_error "Raspberry Pi nicht erreichbar unter $RASPBERRY_IP"
    print_warning "Bitte IP-Adresse prüfen oder als Parameter übergeben:"
    print_warning "./transfer-to-raspberry.sh [IP-ADRESSE] [USERNAME]"
    exit 1
fi

if ! ssh -o ConnectTimeout=5 "${RASPBERRY_USER}@${RASPBERRY_IP}" "echo 'Verbindung OK'" 2>/dev/null; then
    print_error "SSH-Verbindung fehlgeschlagen!"
    print_warning "Bitte SSH-Keys einrichten oder Password-Auth aktivieren"
    print_warning "SSH-Key erstellen: ssh-keygen -t rsa"
    print_warning "Key kopieren: ssh-copy-id ${RASPBERRY_USER}@${RASPBERRY_IP}"
    exit 1
fi

print_success "Verbindung zum Raspberry Pi erfolgreich"

# 2. Remote-Verzeichnis erstellen
print_status "Erstelle Zielverzeichnis auf Raspberry Pi..."
ssh "${RASPBERRY_USER}@${RASPBERRY_IP}" "mkdir -p ${REMOTE_PATH}"

# 3. Temporäres Archiv erstellen (für schnellere Übertragung)
print_status "Erstelle temporäres Archiv..."
TEMP_ARCHIVE="/tmp/bauplan-checker-$(date +%Y%m%d_%H%M%S).tar.gz"

# Ausschluss-Muster für nicht benötigte Dateien
tar --exclude='.git' \
    --exclude='backend/venv' \
    --exclude='backend/__pycache__' \
    --exclude='backend/.env' \
    --exclude='frontend/node_modules' \
    --exclude='frontend/.next' \
    --exclude='logs/*' \
    --exclude='*.log' \
    --exclude='.DS_Store' \
    --exclude='backend/uploads/*' \
    --exclude='backend/analysis_results/*' \
    -czf "$TEMP_ARCHIVE" \
    -C .. \
    bauplan-checker/

print_success "Archiv erstellt: $(du -h "$TEMP_ARCHIVE" | cut -f1)"

# 4. Archiv übertragen
print_status "Übertrage Archiv zum Raspberry Pi..."
scp "$TEMP_ARCHIVE" "${RASPBERRY_USER}@${RASPBERRY_IP}:/tmp/"

# 5. Auf Raspberry Pi entpacken
print_status "Entpacke Archiv auf Raspberry Pi..."
ssh "${RASPBERRY_USER}@${RASPBERRY_IP}" "
    cd /home/${RASPBERRY_USER}
    tar -xzf /tmp/$(basename "$TEMP_ARCHIVE")
    rm /tmp/$(basename "$TEMP_ARCHIVE")
    
    # Verzeichnisse erstellen
    mkdir -p bauplan-checker/data/{uploads,din_norms,analysis_results,system_prompts}
    mkdir -p bauplan-checker/logs
    mkdir -p bauplan-checker/nginx/{ssl,logs}
    
    # Berechtigungen setzen
    chmod +x bauplan-checker/deploy-raspberry-pi.sh
    chmod +x bauplan-checker/health-check.sh 2>/dev/null || true
    chmod +x bauplan-checker/stop-staging.sh 2>/dev/null || true
"

# 6. DIN-Normen übertragen (falls vorhanden)
if [ -d "backend/din_norms" ] && [ "$(ls -A backend/din_norms/*.pdf 2>/dev/null)" ]; then
    print_status "Übertrage DIN-Normen (separat für bessere Performance)..."
    scp backend/din_norms/*.pdf "${RASPBERRY_USER}@${RASPBERRY_IP}:${REMOTE_PATH}/data/din_norms/"
    scp backend/din_norms/*.json "${RASPBERRY_USER}@${RASPBERRY_IP}:${REMOTE_PATH}/data/din_norms/" 2>/dev/null || true
    print_success "DIN-Normen übertragen"
fi

# 7. Lokales Archiv löschen
rm "$TEMP_ARCHIVE"

# 8. .env Datei erstellen/warnen
print_status "Prüfe .env Konfiguration..."
ssh "${RASPBERRY_USER}@${RASPBERRY_IP}" "
    cd ${REMOTE_PATH}
    if [ ! -f .env ]; then
        echo 'Erstelle .env Template...'
        cat > .env << 'EOF'
# OpenAI API Configuration (MUSS ANGEPASST WERDEN!)
OPENAI_API_KEY=your_openai_api_key_here

# System Configuration
ENVIRONMENT=production
HOST=0.0.0.0
PORT=8000

# Home Assistant Integration
HASS_TOKEN=your_homeassistant_token_here
HASS_URL=http://homeassistant.local:8123

# Network Configuration (automatisch erkannt)
RASPBERRY_PI_IP=$(hostname -I | awk '{print \$1}')
EOF
    fi
"

# 9. Erfolg-Meldung
print_success "🎉 Übertragung abgeschlossen!"
echo ""
echo "=================================================="
echo "🍓 NÄCHSTE SCHRITTE AUF RASPBERRY PI:"
echo "=================================================="
echo "1. SSH zum Raspberry Pi:"
echo "   ssh ${RASPBERRY_USER}@${RASPBERRY_IP}"
echo ""
echo "2. In Projekt-Verzeichnis wechseln:"
echo "   cd ${REMOTE_PATH}"
echo ""
echo "3. .env Datei bearbeiten:"
echo "   nano .env"
echo "   (OPENAI_API_KEY setzen!)"
echo ""
echo "4. Deployment starten:"
echo "   ./deploy-raspberry-pi.sh"
echo ""
echo "=================================================="
echo "📊 ÜBERTRAGENE DATEIEN:"
ssh "${RASPBERRY_USER}@${RASPBERRY_IP}" "
    cd ${REMOTE_PATH}
    echo 'Hauptverzeichnis:'
    ls -la | grep -E '^(d|-)' | head -10
    echo ''
    echo 'Data-Verzeichnisse:'
    ls -la data/
    echo ''
    echo 'DIN-Normen:'
    ls -la data/din_norms/ | wc -l
    echo ' Dateien in din_norms/'
"
echo "=================================================="

print_success "Bauplan-Checker bereit für Raspberry Pi Deployment!"
print_warning "Vergessen Sie nicht, den OpenAI API Key in .env zu setzen!"

# Optional: Direkt SSH-Verbindung öffnen
read -p "Möchten Sie sich direkt per SSH verbinden? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Öffne SSH-Verbindung..."
    ssh "${RASPBERRY_USER}@${RASPBERRY_IP}" "cd ${REMOTE_PATH} && bash"
fi 