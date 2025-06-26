#!/usr/bin/with-contenv bashio

# Bash strict mode
set -euo pipefail

# Add-on Informationen
bashio::log.info "🏗️ Starting Bauplan-Checker Add-on v1.0.0"

# Konfiguration laden und validieren
if bashio::config.has_value 'openai_api_key'; then
    export OPENAI_API_KEY=$(bashio::config 'openai_api_key')
else
    bashio::log.fatal "❌ OpenAI API Key ist erforderlich! Bitte in den Add-on Optionen konfigurieren."
    exit 1
fi

export LOG_LEVEL=$(bashio::config 'log_level' 'info')
export MAX_MONTHLY_BUDGET=$(bashio::config 'max_monthly_budget' '20.0')
export WARN_AT_BUDGET=$(bashio::config 'warn_at_budget' '15.0')
export ENVIRONMENT="production"
export PYTHONPATH="/app"

# Log-Konfiguration anzeigen
bashio::log.info "📋 Konfiguration:"
bashio::log.info "  Log Level: ${LOG_LEVEL}"
bashio::log.info "  Max Monthly Budget: $${MAX_MONTHLY_BUDGET}"
bashio::log.info "  Warning Budget: $${WARN_AT_BUDGET}"

# Verzeichnisse vorbereiten
bashio::log.info "📁 Vorbereitung der Datenverzeichnisse..."

# Share-Verzeichnisse erstellen
mkdir -p /share/bauplan-checker/{uploads,din_norms,analysis_results,system_prompts}

# Lokale Verzeichnisse mit Share verlinken
ln -sf /share/bauplan-checker/uploads /app/uploads
ln -sf /share/bauplan-checker/analysis_results /app/analysis_results

# DIN-Normen kopieren falls vorhanden
if [ -d "/share/bauplan-checker/din_norms" ] && [ "$(ls -A /share/bauplan-checker/din_norms 2>/dev/null)" ]; then
    bashio::log.info "📚 Kopiere DIN-Normen aus Share-Verzeichnis..."
    cp -r /share/bauplan-checker/din_norms/* /app/din_norms/ 2>/dev/null || true
else
    bashio::log.info "📚 Keine DIN-Normen im Share-Verzeichnis gefunden"
fi

# System-Prompts kopieren
if [ -d "/share/bauplan-checker/system_prompts" ] && [ "$(ls -A /share/bauplan-checker/system_prompts 2>/dev/null)" ]; then
    bashio::log.info "📝 Kopiere System-Prompts aus Share-Verzeichnis..."
    cp -r /share/bauplan-checker/system_prompts/* /app/system_prompts/ 2>/dev/null || true
fi

# Standard System-Prompts erstellen falls nicht vorhanden
if [ ! -f "/app/system_prompts/din_analysis_prompt.md" ]; then
    bashio::log.info "📝 Erstelle Standard System-Prompts..."
    mkdir -p /app/system_prompts
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

# Berechtigungen setzen
chmod -R 755 /share/bauplan-checker
chmod -R 755 /app

# Backend-Funktion
start_backend() {
    bashio::log.info "🔧 Backend wird gestartet..."
    cd /app
    exec python3 main.py
}

# Frontend-Funktion  
start_frontend() {
    bashio::log.info "🎨 Frontend wird gestartet..."
    cd /app/frontend
    exec npm start
}

# Prozess-Management mit Supervisor
cat > /etc/supervisor/conf.d/bauplan-checker.conf << EOF
[supervisord]
nodaemon=true
logfile=/addon_config/logs/supervisor.log
pidfile=/addon_config/logs/supervisor.pid

[program:backend]
command=python3 main.py
directory=/app
autostart=true
autorestart=true
stderr_logfile=/addon_config/logs/backend.log
stdout_logfile=/addon_config/logs/backend.log
environment=OPENAI_API_KEY="${OPENAI_API_KEY}",LOG_LEVEL="${LOG_LEVEL}",MAX_MONTHLY_BUDGET="${MAX_MONTHLY_BUDGET}",WARN_AT_BUDGET="${WARN_AT_BUDGET}",ENVIRONMENT="${ENVIRONMENT}",PYTHONPATH="${PYTHONPATH}"

[program:frontend]
command=npm start
directory=/app/frontend
autostart=true
autorestart=true
stderr_logfile=/addon_config/logs/frontend.log
stdout_logfile=/addon_config/logs/frontend.log
EOF

# Warten auf Backend-Start
wait_for_backend() {
    local max_attempts=30
    local attempt=1
    
    bashio::log.info "⏳ Warte auf Backend-Start..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
            bashio::log.info "✅ Backend ist bereit!"
            return 0
        fi
        
        bashio::log.info "   Versuch ${attempt}/${max_attempts}..."
        sleep 2
        ((attempt++))
    done
    
    bashio::log.error "❌ Backend konnte nicht gestartet werden!"
    return 1
}

# Warten auf Frontend-Start
wait_for_frontend() {
    local max_attempts=20
    local attempt=1
    
    bashio::log.info "⏳ Warte auf Frontend-Start..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -sf http://localhost:3000 > /dev/null 2>&1; then
            bashio::log.info "✅ Frontend ist bereit!"
            return 0
        fi
        
        bashio::log.info "   Versuch ${attempt}/${max_attempts}..."
        sleep 3
        ((attempt++))
    done
    
    bashio::log.warning "⚠️ Frontend möglicherweise noch nicht bereit"
    return 0
}

# Cleanup-Funktion für graceful shutdown
cleanup() {
    bashio::log.info "🛑 Stoppe Bauplan-Checker Add-on..."
    supervisorctl stop all
    exit 0
}

# Signal Handler
trap cleanup SIGTERM SIGINT

# Log-Verzeichnis erstellen
mkdir -p /addon_config/logs

# Supervisor starten
bashio::log.info "🚀 Starte Prozess-Management..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/bauplan-checker.conf &

# Auf Services warten
sleep 5
wait_for_backend
wait_for_frontend

# Status-Ausgabe
bashio::log.info "🎉 Bauplan-Checker Add-on erfolgreich gestartet!"
bashio::log.info "🌐 Frontend: http://homeassistant.local:3000"
bashio::log.info "🔧 Backend API: http://homeassistant.local:8000"
bashio::log.info "📊 Health Check: http://homeassistant.local:8000/health"

# Keep running
wait 