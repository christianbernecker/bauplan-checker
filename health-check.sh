#!/bin/bash

# Bauplan-Checker Health Check Script
# Kontinuierliches Monitoring des Systems

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "🩺 Bauplan-Checker Health Check - $TIMESTAMP"
echo "================================================"

# Backend Check
echo -n "Backend (Port 8000): "
if curl -s http://localhost:8000/health > /dev/null 2>&1; then
    HEALTH_RESPONSE=$(curl -s http://localhost:8000/health | jq -r '.status' 2>/dev/null || echo "unknown")
    if [ "$HEALTH_RESPONSE" = "healthy" ]; then
        echo -e "${GREEN}✅ Healthy${NC}"
    else
        echo -e "${YELLOW}⚠️ Running but not healthy${NC}"
    fi
else
    echo -e "${RED}❌ Not responding${NC}"
fi

# Frontend Check
echo -n "Frontend (Port 3000): "
if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not responding${NC}"
fi

# API Endpoints Check
echo -n "API /plans endpoint: "
if curl -s http://localhost:8000/plans | jq . > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Working${NC}"
else
    echo -e "${RED}❌ Error${NC}"
fi

# DIN-Normen Check
echo -n "DIN-Normen: "
DIN_COUNT=$(find backend/din_norms -name "*.pdf" 2>/dev/null | wc -l)
if [ "$DIN_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ $DIN_COUNT PDFs gefunden${NC}"
else
    echo -e "${YELLOW}⚠️ Keine DIN-Normen PDFs${NC}"
fi

# Disk Space Check
echo -n "Disk Space: "
DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${GREEN}✅ ${DISK_USAGE}% used${NC}"
else
    echo -e "${RED}⚠️ ${DISK_USAGE}% used (niedrig)${NC}"
fi

# Memory Check
echo -n "Memory: "
if command -v free > /dev/null 2>&1; then
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", ($3/$2)*100}')
    echo -e "${GREEN}${MEM_USAGE}% used${NC}"
elif command -v vm_stat > /dev/null 2>&1; then
    # macOS
    echo -e "${BLUE}macOS - Details mit 'vm_stat'${NC}"
fi

# Process Check
echo -n "Backend Process: "
if pgrep -f "python.*main.py" > /dev/null; then
    PID=$(pgrep -f "python.*main.py")
    echo -e "${GREEN}✅ PID $PID${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
fi

echo -n "Frontend Process: "
if pgrep -f "npm.*dev" > /dev/null || pgrep -f "next.*dev" > /dev/null; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
fi

# Recent Activity
echo ""
echo "📊 Recent Activity:"
if [ -d "backend/analysis_results" ]; then
    RECENT_FILES=$(find backend/analysis_results -name "*.json" -mtime -1 | wc -l)
    echo "   Analysen heute: $RECENT_FILES"
fi

if [ -d "backend/uploads" ]; then
    UPLOAD_COUNT=$(find backend/uploads -name "*.pdf" | wc -l)
    echo "   Hochgeladene PDFs: $UPLOAD_COUNT"
fi

echo ""
echo "🔄 Letzte Aktualisierung: $TIMESTAMP"

# Optionale Alerts
if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
    echo ""
    echo -e "${RED}🚨 ALERT: Backend nicht erreichbar!${NC}"
    echo "   Mögliche Lösungen:"
    echo "   - ./deploy-staging.sh erneut ausführen"
    echo "   - Backend-Logs prüfen"
fi

if ! curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo ""
    echo -e "${RED}🚨 ALERT: Frontend nicht erreichbar!${NC}"
    echo "   Mögliche Lösungen:"
    echo "   - ./deploy-staging.sh erneut ausführen"
    echo "   - npm run dev manuell starten"
fi 