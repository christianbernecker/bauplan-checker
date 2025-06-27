#!/bin/bash

# 🔧 Bauplan-Checker Python-Pfad Fix für Home Assistant OS
echo "🔧 Fixing Python path issues..."

cd /share/bauplan-checker

# 1. Python-Pfad finden
echo "🔍 Suche Python-Installation..."
PYTHON_PATH=""

# Mögliche Python-Pfade in Home Assistant OS
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
        PYTHON_PATH="$path"
        echo "✅ Python gefunden: $PYTHON_PATH"
        break
    fi
done

if [ -z "$PYTHON_PATH" ]; then
    echo "❌ Kein Python gefunden. Versuche alternatives Deployment..."
    # Alternative: Verwende das Home Assistant Python
    if [ -f "/usr/bin/python3.11" ]; then
        PYTHON_PATH="/usr/bin/python3.11"
    elif [ -f "/usr/bin/python3.10" ]; then
        PYTHON_PATH="/usr/bin/python3.10"
    elif [ -f "/usr/bin/python3.9" ]; then
        PYTHON_PATH="/usr/bin/python3.9"
    else
        echo "❌ Kein Python verfügbar. Verwende Cloud-Deployment."
        exit 1
    fi
fi

echo "🐍 Verwende Python: $PYTHON_PATH"
$PYTHON_PATH --version

# 2. Korrigiertes Start-Skript erstellen
echo "📝 Erstelle korrigiertes Start-Skript..."
cat > /share/bauplan-checker/start-backend-fixed.sh << EOF
#!/bin/bash
cd /share/bauplan-checker
export PYTHONPATH=/share/bauplan-checker

# Lade Umgebungsvariablen
if [ -f .env ]; then
    export \$(cat .env | grep -v '^#' | xargs)
fi

echo "🚀 Starte Bauplan-Checker Backend mit $PYTHON_PATH..."
echo "📁 Arbeitsverzeichnis: \$(pwd)"
echo "🔑 OpenAI Key: \${OPENAI_API_KEY:0:10}..."

# Backend im Hintergrund starten
nohup $PYTHON_PATH main.py > backend.log 2>&1 &
BACKEND_PID=\$!
echo \$BACKEND_PID > backend.pid

echo "✅ Backend gestartet (PID: \$BACKEND_PID)"
echo "📊 Log-Datei: /share/bauplan-checker/backend.log"
echo "🌐 Backend URL: http://\$(hostname -I | awk '{print \$1}'):8000"

# Warte kurz und prüfe Status
sleep 3
if ps -p \$BACKEND_PID > /dev/null; then
    echo "✅ Backend läuft erfolgreich"
else
    echo "❌ Backend-Start fehlgeschlagen. Prüfe Logs:"
    tail -10 backend.log
fi
EOF

chmod +x /share/bauplan-checker/start-backend-fixed.sh

# 3. Alten Prozess stoppen
echo "🛑 Stoppe alten Backend-Prozess..."
if [ -f backend.pid ]; then
    OLD_PID=$(cat backend.pid)
    kill $OLD_PID 2>/dev/null
    echo "Alter Prozess gestoppt"
fi

# Alle Python-Prozesse mit main.py stoppen
pkill -f "main.py" 2>/dev/null

# 4. Dependencies prüfen und installieren
echo "📦 Prüfe Python-Dependencies..."
$PYTHON_PATH -c "import fastapi" 2>/dev/null || {
    echo "⚠️ FastAPI nicht gefunden. Installiere Dependencies..."
    $PYTHON_PATH -m pip install --user fastapi==0.104.1 uvicorn==0.24.0 python-multipart==0.0.6 PyPDF2==3.0.1 openai==1.3.7 python-dotenv==1.0.0
}

# 5. Korrigiertes Test-Skript
cat > /share/bauplan-checker/test-backend-fixed.sh << EOF
#!/bin/bash
echo "🧪 Teste Backend mit korrigiertem Pfad..."
sleep 2
curl -s http://localhost:8000/ && echo "✅ Backend erreichbar" || echo "❌ Backend nicht erreichbar"
curl -s http://localhost:8000/health && echo "✅ Health Check OK" || echo "❌ Health Check fehlgeschlagen"

echo "📊 Backend-Logs (letzte 10 Zeilen):"
tail -10 /share/bauplan-checker/backend.log 2>/dev/null || echo "Keine Logs verfügbar"
EOF

chmod +x /share/bauplan-checker/test-backend-fixed.sh

echo ""
echo "🎉 Fix abgeschlossen!"
echo ""
echo "🔧 Verwende diese Befehle:"
echo "  Start:  ./start-backend-fixed.sh"
echo "  Test:   ./test-backend-fixed.sh"
echo "  Logs:   tail -f backend.log"
echo ""
echo "▶️ Starte jetzt das Backend:"
echo "./start-backend-fixed.sh" 