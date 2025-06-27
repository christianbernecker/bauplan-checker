#!/bin/bash

# 🔍 Bauplan-Checker Raspberry Pi Troubleshooting
echo "🔍 Bauplan-Checker Troubleshooting..."

echo "1️⃣ Container Status prüfen:"
docker ps -a | grep bauplan-checker

echo ""
echo "2️⃣ Container Logs anzeigen:"
docker logs bauplan-checker-backend

echo ""
echo "3️⃣ Port-Status prüfen:"
netstat -tulpn | grep 8000 || ss -tulpn | grep 8000

echo ""
echo "4️⃣ Container Details:"
docker inspect bauplan-checker-backend | grep -A 5 -B 5 "State\|Status\|Error"

echo ""
echo "5️⃣ Mögliche Lösungen:"
echo "   Option A: Container neustarten"
echo "   docker restart bauplan-checker-backend"
echo ""
echo "   Option B: Container mit Debug-Modus starten"
echo "   docker stop bauplan-checker-backend"
echo "   docker rm bauplan-checker-backend"
echo "   docker run -d --name bauplan-checker-backend -p 8000:8000 -e OPENAI_API_KEY=IHR-KEY -e LOG_LEVEL=DEBUG ghcr.io/christianbernecker/bauplan-checker:latest python main.py"
echo ""
echo "   Option C: Container interaktiv starten (zum Debuggen)"
echo "   docker run -it --rm -p 8000:8000 -e OPENAI_API_KEY=IHR-KEY ghcr.io/christianbernecker/bauplan-checker:latest /bin/bash"

echo ""
echo "6️⃣ Nach dem Fix testen:"
echo "   curl http://localhost:8000/"
echo "   curl http://192.168.2.19:8000/" 