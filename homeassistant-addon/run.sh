#!/usr/bin/with-contenv bashio

# Parse configuration
export OPENAI_API_KEY=$(bashio::config 'openai_api_key')
export LOG_LEVEL=$(bashio::config 'log_level')

# Log configuration
bashio::log.info "Starting Bauplan-Checker..."
bashio::log.info "Log level: ${LOG_LEVEL}"

if [ -z "$OPENAI_API_KEY" ]; then
    bashio::log.error "OpenAI API Key is required! Please configure it in the add-on options."
    exit 1
fi

# Copy DIN norms from share if available
if [ -d "/share/bauplan-checker/din_norms" ]; then
    bashio::log.info "Copying DIN norms from share directory..."
    cp -r /share/bauplan-checker/din_norms/* /app/backend/din_norms/ 2>/dev/null || true
fi

# Copy system prompts
if [ -d "/share/bauplan-checker/system_prompts" ]; then
    cp -r /share/bauplan-checker/system_prompts/* /app/backend/system_prompts/ 2>/dev/null || true
fi

# Start backend in background
bashio::log.info "Starting backend API server..."
cd /app/backend
python3 main.py &
BACKEND_PID=$!

# Wait for backend to be ready
sleep 5
until curl -sf http://localhost:8000/health > /dev/null; do
    bashio::log.info "Waiting for backend to be ready..."
    sleep 2
done

bashio::log.info "Backend ready! Starting frontend..."

# Start frontend
cd /app/frontend
npm start &
FRONTEND_PID=$!

# Wait for frontend
sleep 5
until curl -sf http://localhost:3000 > /dev/null; do
    bashio::log.info "Waiting for frontend to be ready..."
    sleep 2
done

bashio::log.info "Bauplan-Checker is ready!"
bashio::log.info "Frontend: http://homeassistant.local:3000"
bashio::log.info "Backend API: http://homeassistant.local:8000"

# Keep container running and monitor processes
while true; do
    # Check if backend is still running
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        bashio::log.error "Backend process died, restarting..."
        cd /app/backend
        python3 main.py &
        BACKEND_PID=$!
    fi
    
    # Check if frontend is still running
    if ! kill -0 $FRONTEND_PID 2>/dev/null; then
        bashio::log.error "Frontend process died, restarting..."
        cd /app/frontend
        npm start &
        FRONTEND_PID=$!
    fi
    
    sleep 30
done 