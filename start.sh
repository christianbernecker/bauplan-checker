#!/bin/bash
set -e

echo "🏗️ Starting Bauplan-Checker Production Container..."

# Environment validation
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ ERROR: OPENAI_API_KEY environment variable is required!"
    exit 1
fi

# Setup directories and permissions
echo "📁 Setting up directories..."
mkdir -p /app/{uploads,din_norms,analysis_results,system_prompts}
chmod -R 755 /app

# Create default system prompt if not exists
if [ ! -f "/app/system_prompts/din_analysis_prompt.md" ]; then
    echo "📝 Creating default system prompt..."
    cat > /app/system_prompts/din_analysis_prompt.md << 'EOF'
# DIN-Normen Analyse Prompt

Du bist ein Experte für deutsche DIN-Normen im Bauwesen. Analysiere den gegebenen Bauplan-Text gegen die verfügbaren DIN-Normen und erstelle einen detaillierten Compliance-Bericht.

## Aufgaben:
1. Identifiziere relevante DIN-Normen für den Bauplan
2. Prüfe die Einhaltung der Normen
3. Liste Abweichungen und Verstöße auf
4. Gib konkrete Verbesserungsvorschläge

## Format:
- Verwende klare, professionelle Sprache
- Strukturiere die Antwort mit Überschriften
- Gib konkrete Norm-Referenzen an
- Priorisiere kritische Verstöße
EOF
fi

# Process DIN norms if available
if [ -d "/app/din_norms" ] && [ "$(ls -A /app/din_norms/*.pdf 2>/dev/null)" ]; then
    echo "📚 Processing DIN norms..."
    cd /app
    python3 din_processor.py || echo "⚠️ DIN processing failed, continuing..."
fi

# Start backend
echo "🔧 Starting backend..."
cd /app
python3 main.py &
BACKEND_PID=$!

# Wait for backend to be ready
echo "⏳ Waiting for backend..."
for i in {1..30}; do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo "✅ Backend is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Backend failed to start"
        exit 1
    fi
    sleep 2
done

# Start frontend
echo "🎨 Starting frontend..."
cd /app/frontend
npm start &
FRONTEND_PID=$!

# Wait for frontend to be ready
echo "⏳ Waiting for frontend..."
for i in {1..20}; do
    if curl -sf http://localhost:3000 > /dev/null 2>&1; then
        echo "✅ Frontend is ready!"
        break
    fi
    if [ $i -eq 20 ]; then
        echo "❌ Frontend failed to start"
        exit 1
    fi
    sleep 3
done

echo "🎉 Bauplan-Checker is running!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔧 Backend: http://localhost:8000"

# Monitor processes and restart if needed
while true; do
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        echo "⚠️ Backend died, restarting..."
        cd /app
        python3 main.py &
        BACKEND_PID=$!
    fi
    
    if ! kill -0 $FRONTEND_PID 2>/dev/null; then
        echo "⚠️ Frontend died, restarting..."
        cd /app/frontend
        npm start &
        FRONTEND_PID=$!
    fi
    
    sleep 30
done 