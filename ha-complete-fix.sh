#!/bin/bash

# 🏠 Bauplan-Checker: Komplette Home Assistant Installation
# Dieses Skript behebt alle Pfad- und Konfigurationsprobleme

echo "🏠 Bauplan-Checker: Vollständige Home Assistant Installation"
echo "============================================================="

set -e

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
echo "Hostname: $(hostname)"
echo "IP: $(hostname -I | awk '{print $1}')"
echo "HA Version: $(cat /etc/version 2>/dev/null || echo 'Unknown')"
echo ""

# 2. Richtige Add-on Verzeichnisse finden
print_status "Finde Add-on Verzeichnisse..."
ADDON_PATHS=$(find / -name "addons" -type d 2>/dev/null | grep -v proc)
echo "Gefundene Add-on Pfade:"
echo "$ADDON_PATHS"
echo ""

# 3. Standard Home Assistant Add-on Pfade versuchen
POSSIBLE_PATHS=(
    "/usr/share/hassio/addons/local"
    "/data/addons/local" 
    "/addons/local"
    "/mnt/data/supervisor/addons/local"
    "/var/lib/hassio/addons/local"
)

ADDON_PATH=""
for path in "${POSSIBLE_PATHS[@]}"; do
    if mkdir -p "$path/bauplan-checker" 2>/dev/null; then
        ADDON_PATH="$path"
        print_success "Add-on Pfad gefunden: $ADDON_PATH"
        break
    fi
done

if [ -z "$ADDON_PATH" ]; then
    print_error "Kein beschreibbarer Add-on Pfad gefunden!"
    print_status "Verfügbare Pfade:"
    echo "$ADDON_PATHS"
    exit 1
fi

# 4. Quelldateien finden
SOURCE_PATHS=(
    "/addons/local/bauplan-checker"
    "/tmp/bauplan-checker-addon"
    "/share/bauplan-checker"
    "/data/addons/local/local/bauplan-checker"
)

SOURCE_PATH=""
for path in "${SOURCE_PATHS[@]}"; do
    if [ -d "$path" ]; then
        SOURCE_PATH="$path"
        print_success "Quelldateien gefunden: $SOURCE_PATH"
        break
    fi
done

# 5. Dateien kopieren (falls Quelle gefunden)
if [ -n "$SOURCE_PATH" ] && [ -d "$SOURCE_PATH" ]; then
    print_status "Kopiere Add-on Dateien..."
    cp -r "$SOURCE_PATH"/* "$ADDON_PATH/bauplan-checker/" 2>/dev/null || true
fi

# 6. Archive entpacken (falls vorhanden)
ARCHIVE_PATHS=(
    "/tmp/bauplan-checker-homeassistant-addon.tar.gz"
    "/share/bauplan-checker/bauplan-checker-homeassistant-addon.tar.gz"
    "/share/bauplan-checker-homeassistant-addon.tar.gz"
)

for archive in "${ARCHIVE_PATHS[@]}"; do
    if [ -f "$archive" ]; then
        print_status "Entpacke Archiv: $archive"
        cd /tmp
        tar -xzf "$archive" 2>/dev/null || true
        if [ -d "/tmp/bauplan-checker-addon" ]; then
            cp -r /tmp/bauplan-checker-addon/* "$ADDON_PATH/bauplan-checker/"
            print_success "Archiv entpackt und installiert"
            break
        fi
    fi
done

# 7. Perfekte config.yaml erstellen
print_status "Erstelle optimale config.yaml..."
cat > "$ADDON_PATH/bauplan-checker/config.yaml" << 'EOF'
name: Bauplan-Checker
description: DIN-Normen Compliance Checker für Baupläne
version: 1.0.0
slug: bauplan_checker
init: false
arch:
  - aarch64
  - armv7
startup: services
boot: auto
map:
  - share:rw
ports:
  3000/tcp: 3000
  8000/tcp: 8000
ports_description:
  3000/tcp: Frontend Web-UI
  8000/tcp: Backend API
options:
  openai_api_key: ""
  log_level: info
  environment: production
schema:
  openai_api_key: str
  log_level: list(debug|info|warning|error)?
  environment: list(development|production)?
backup: hot
webui: http://[HOST]:[PORT:3000]
panel_icon: mdi:file-check
panel_title: Bauplan-Checker
panel_admin: true
EOF

# 8. Berechtigungen setzen
chmod -R 755 "$ADDON_PATH/bauplan-checker/"
chmod +x "$ADDON_PATH/bauplan-checker/run.sh" 2>/dev/null || true

# 9. Supervisor neustarten
print_status "Starte Supervisor neu..."
systemctl restart hassio-supervisor 2>/dev/null || ha supervisor restart

# 10. Warten und Status prüfen
sleep 10
print_status "Prüfe Installation..."

# 11. Add-on Status
print_status "Add-on Status:"
ha addons 2>/dev/null | grep -i bauplan || echo "Add-on wird geladen..."

# 12. Verzeichnisstruktur anzeigen
print_status "Installierte Dateien:"
ls -la "$ADDON_PATH/bauplan-checker/" | head -10

# 13. Abschluss
print_success "Installation abgeschlossen!"
echo ""
echo "🎉 NÄCHSTE SCHRITTE:"
echo "1. Home Assistant Web-UI → Settings → Add-ons"
echo "2. ⟳ Reload klicken"
echo "3. Local Add-ons → Bauplan-Checker"
echo "4. Install → Configuration → OpenAI API Key"
echo "5. Start"
echo ""
echo "🌐 Nach Start verfügbar:"
echo "- Frontend: http://$(hostname -I | awk '{print $1}'):3000"
echo "- Backend:  http://$(hostname -I | awk '{print $1}'):8000"
echo ""
echo "📁 Add-on installiert in: $ADDON_PATH/bauplan-checker/"
echo "📊 Freier Speicher: $(df -h $ADDON_PATH | tail -1 | awk '{print $4}')" 