#!/bin/bash

# 🐍 Python Installation auf Home Assistant OS
echo "🐍 Versuche Python-Installation auf Home Assistant OS..."

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

# 2. Prüfe verfügbare Package Manager
print_status "Prüfe Package Manager..."

if command -v apk &> /dev/null; then
    print_success "Alpine Package Manager (apk) gefunden"
    PACKAGE_MANAGER="apk"
elif command -v apt &> /dev/null; then
    print_success "APT Package Manager gefunden"
    PACKAGE_MANAGER="apt"
elif command -v yum &> /dev/null; then
    print_success "YUM Package Manager gefunden"
    PACKAGE_MANAGER="yum"
elif command -v dnf &> /dev/null; then
    print_success "DNF Package Manager gefunden"
    PACKAGE_MANAGER="dnf"
else
    print_error "Kein Package Manager gefunden"
    PACKAGE_MANAGER="none"
fi

# 3. Versuche Python-Installation
if [ "$PACKAGE_MANAGER" != "none" ]; then
    print_status "Versuche Python-Installation mit $PACKAGE_MANAGER..."
    
    case $PACKAGE_MANAGER in
        "apk")
            print_status "Alpine: Installiere Python..."
            apk update 2>/dev/null || print_warning "apk update fehlgeschlagen"
            apk add python3 py3-pip 2>/dev/null || print_warning "Python-Installation fehlgeschlagen"
            ;;
        "apt")
            print_status "Debian/Ubuntu: Installiere Python..."
            apt update 2>/dev/null || print_warning "apt update fehlgeschlagen"
            apt install -y python3 python3-pip 2>/dev/null || print_warning "Python-Installation fehlgeschlagen"
            ;;
        "yum")
            print_status "RHEL/CentOS: Installiere Python..."
            yum install -y python3 python3-pip 2>/dev/null || print_warning "Python-Installation fehlgeschlagen"
            ;;
        "dnf")
            print_status "Fedora: Installiere Python..."
            dnf install -y python3 python3-pip 2>/dev/null || print_warning "Python-Installation fehlgeschlagen"
            ;;
    esac
fi

# 4. Prüfe Python nach Installation
print_status "Prüfe Python-Installation..."
PYTHON_FOUND=""

# Verschiedene Python-Pfade testen
PYTHON_PATHS=(
    "/usr/bin/python3"
    "/usr/local/bin/python3"
    "/opt/python/bin/python3"
    "/usr/bin/python"
    "python3"
    "python"
)

for path in "${PYTHON_PATHS[@]}"; do
    if command -v "$path" &> /dev/null; then
        PYTHON_FOUND="$path"
        print_success "Python gefunden: $PYTHON_FOUND"
        $PYTHON_FOUND --version
        break
    fi
done

# 5. Falls Python gefunden: Dependencies installieren
if [ -n "$PYTHON_FOUND" ]; then
    print_status "Installiere Python-Dependencies..."
    
    # pip prüfen/installieren
    if ! $PYTHON_FOUND -m pip --version &> /dev/null; then
        print_status "Installiere pip..."
        case $PACKAGE_MANAGER in
            "apk") apk add py3-pip ;;
            "apt") apt install -y python3-pip ;;
            "yum") yum install -y python3-pip ;;
            "dnf") dnf install -y python3-pip ;;
        esac
    fi
    
    # FastAPI Dependencies installieren
    print_status "Installiere FastAPI und Dependencies..."
    $PYTHON_FOUND -m pip install --user fastapi==0.104.1 uvicorn==0.24.0 python-multipart==0.0.6 PyPDF2==3.0.1 openai==1.3.7 python-dotenv==1.0.0
    
    if [ $? -eq 0 ]; then
        print_success "Dependencies erfolgreich installiert!"
        
        # Korrigiertes Start-Skript erstellen
        cd /share/bauplan-checker 2>/dev/null || mkdir -p /share/bauplan-checker && cd /share/bauplan-checker
        
        cat > start-backend-python.sh << EOF
#!/bin/bash
cd /share/bauplan-checker
export PYTHONPATH=/share/bauplan-checker

# Lade Umgebungsvariablen
if [ -f .env ]; then
    export \$(cat .env | grep -v '^#' | xargs)
fi

echo "🚀 Starte Bauplan-Checker Backend mit $PYTHON_FOUND..."
echo "📁 Arbeitsverzeichnis: \$(pwd)"
echo "🔑 OpenAI Key: \${OPENAI_API_KEY:0:10}..."

# Backend starten
nohup $PYTHON_FOUND main.py > backend.log 2>&1 &
BACKEND_PID=\$!
echo \$BACKEND_PID > backend.pid

echo "✅ Backend gestartet (PID: \$BACKEND_PID)"
echo "📊 Log-Datei: /share/bauplan-checker/backend.log"
echo "🌐 Backend URL: http://\$(hostname -I | awk '{print \$1}'):8000"

# Status prüfen
sleep 3
if ps -p \$BACKEND_PID > /dev/null; then
    echo "✅ Backend läuft erfolgreich"
else
    echo "❌ Backend-Start fehlgeschlagen. Prüfe Logs:"
    tail -10 backend.log
fi
EOF
        
        chmod +x start-backend-python.sh
        print_success "Start-Skript erstellt: ./start-backend-python.sh"
        
    else
        print_error "Dependency-Installation fehlgeschlagen"
    fi
    
else
    print_error "Python konnte nicht installiert werden"
    echo ""
    print_warning "ALTERNATIVE LÖSUNGEN:"
    echo "1. 🌐 Cloud-Deployment (Railway.app)"
    echo "2. 🐳 Docker auf anderem System"
    echo "3. 🏠 Home Assistant Add-on (falls verfügbar)"
    echo ""
    echo "Empfehlung: Verwenden Sie Cloud-Deployment für beste Ergebnisse"
fi

# 6. Zusammenfassung
echo ""
print_status "ZUSAMMENFASSUNG:"
echo "Package Manager: $PACKAGE_MANAGER"
echo "Python gefunden: ${PYTHON_FOUND:-'Nein'}"
echo ""

if [ -n "$PYTHON_FOUND" ]; then
    echo "🎉 ERFOLG! Python ist verfügbar."
    echo "Nächste Schritte:"
    echo "1. Backend-Code herunterladen"
    echo "2. ./start-backend-python.sh ausführen"
else
    echo "❌ Python nicht verfügbar auf diesem System"
    echo "Empfehlung: Cloud-Deployment verwenden"
fi 