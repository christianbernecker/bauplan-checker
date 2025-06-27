#!/bin/bash

# 🍓 Bauplan-Checker: Direktes Python Deployment auf Raspberry Pi
# Kein Docker erforderlich - läuft direkt auf Home Assistant OS

echo "🍓 Bauplan-Checker: Python Deployment auf Raspberry Pi"
echo "===================================================="

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

# 1. Verzeichnisse erstellen
print_status "Erstelle Arbeitsverzeichnisse..."
mkdir -p /share/bauplan-checker/{backend,uploads,din_norms,analysis_results,logs}
cd /share/bauplan-checker

# 2. Python-Umgebung prüfen
print_status "Prüfe Python-Installation..."
python3 --version || print_error "Python3 nicht verfügbar"
pip3 --version || print_error "pip3 nicht verfügbar"

# 3. Backend-Dateien herunterladen (von GitHub)
print_status "Lade Backend-Code herunter..."
if command -v wget &> /dev/null; then
    wget -O backend.tar.gz https://github.com/christianbernecker/bauplan-checker/archive/main.tar.gz
    tar -xzf backend.tar.gz --strip-components=2 bauplan-checker-main/backend/
elif command -v curl &> /dev/null; then
    curl -L -o backend.tar.gz https://github.com/christianbernecker/bauplan-checker/archive/main.tar.gz
    tar -xzf backend.tar.gz --strip-components=2 bauplan-checker-main/backend/
else
    print_error "Weder wget noch curl verfügbar. Manuelle Installation erforderlich."
    echo "Kopieren Sie die Backend-Dateien manuell nach /share/bauplan-checker/"
    exit 1
fi

# 4. Python-Dependencies installieren
print_status "Installiere Python-Abhängigkeiten..."
cd /share/bauplan-checker
pip3 install --user fastapi==0.104.1 uvicorn==0.24.0 python-multipart==0.0.6 PyPDF2==3.0.1 openai==1.3.7 python-dotenv==1.0.0

# 5. Umgebungsvariablen setzen
print_status "Konfiguriere Umgebung..."
cat > /share/bauplan-checker/.env << EOF
OPENAI_API_KEY=IHR-OPENAI-KEY-HIER
ENVIRONMENT=production
HOST=0.0.0.0
PORT=8000
LOG_LEVEL=INFO
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000,http://192.168.2.19:3000
EOF

print_warning "⚠️ WICHTIG: Bearbeiten Sie /share/bauplan-checker/.env und setzen Sie Ihren echten OpenAI API Key!"

# 6. Systemd Service erstellen (falls möglich)
print_status "Erstelle Startup-Service..."
cat > /tmp/bauplan-checker.service << EOF
[Unit]
Description=Bauplan-Checker Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/share/bauplan-checker
Environment=PATH=/usr/local/bin:/usr/bin:/bin
ExecStart=/usr/bin/python3 main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Service installieren (falls systemctl verfügbar)
if command -v systemctl &> /dev/null; then
    cp /tmp/bauplan-checker.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable bauplan-checker.service
    print_success "Service installiert. Starten mit: systemctl start bauplan-checker"
else
    print_warning "systemctl nicht verfügbar. Manueller Start erforderlich."
fi

# 7. Startup-Skript erstellen
print_status "Erstelle Startup-Skript..."
cat > /share/bauplan-checker/start-backend.sh << 'EOF'
#!/bin/bash
cd /share/bauplan-checker
export PYTHONPATH=/share/bauplan-checker
source .env
echo "🚀 Starte Bauplan-Checker Backend..."
python3 main.py &
echo $! > backend.pid
echo "✅ Backend gestartet (PID: $(cat backend.pid))"
echo "🌐 Backend verfügbar: http://$(hostname -I | awk '{print $1}'):8000"
EOF

chmod +x /share/bauplan-checker/start-backend.sh

# 8. Stop-Skript erstellen
cat > /share/bauplan-checker/stop-backend.sh << 'EOF'
#!/bin/bash
cd /share/bauplan-checker
if [ -f backend.pid ]; then
    PID=$(cat backend.pid)
    kill $PID 2>/dev/null
    rm backend.pid
    echo "🛑 Backend gestoppt"
else
    echo "❌ Keine PID-Datei gefunden"
fi
EOF

chmod +x /share/bauplan-checker/stop-backend.sh

# 9. Test-Skript erstellen
cat > /share/bauplan-checker/test-backend.sh << 'EOF'
#!/bin/bash
echo "🧪 Teste Backend..."
curl -s http://localhost:8000/ && echo "✅ Backend läuft" || echo "❌ Backend nicht erreichbar"
curl -s http://localhost:8000/health && echo "✅ Health Check OK" || echo "❌ Health Check fehlgeschlagen"
EOF

chmod +x /share/bauplan-checker/test-backend.sh

# 10. Installation abschließen
print_success "Installation abgeschlossen!"
echo ""
echo "🎉 NÄCHSTE SCHRITTE:"
echo "1. Bearbeiten Sie: /share/bauplan-checker/.env (OpenAI API Key)"
echo "2. Starten Sie: /share/bauplan-checker/start-backend.sh"
echo "3. Testen Sie: /share/bauplan-checker/test-backend.sh"
echo ""
echo "📁 Alle Dateien in: /share/bauplan-checker/"
echo "🌐 Backend URL: http://$(hostname -I | awk '{print $1}'):8000"
echo "📊 API Docs: http://$(hostname -I | awk '{print $1}'):8000/docs"
echo ""
echo "🔧 Befehle:"
echo "  Start:  ./start-backend.sh"
echo "  Stop:   ./stop-backend.sh"
echo "  Test:   ./test-backend.sh" 