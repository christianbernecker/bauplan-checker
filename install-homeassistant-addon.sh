#!/bin/bash

# Home Assistant Add-on Installation Script
# Für lokale Installation ohne SSH

set -e

echo "🏠 Bauplan-Checker Home Assistant Add-on Installation"
echo "=================================================="

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

# 1. Add-on Verzeichnis erstellen
print_status "Erstelle Add-on Paket..."
ADDON_DIR="bauplan-checker-addon"
rm -rf "$ADDON_DIR"
mkdir -p "$ADDON_DIR"

# 2. Add-on Dateien kopieren
print_status "Kopiere Add-on Konfiguration..."
cp homeassistant-addon/config.yaml "$ADDON_DIR/"
cp homeassistant-addon/Dockerfile "$ADDON_DIR/"
cp homeassistant-addon/run.sh "$ADDON_DIR/"

# 3. Backend kopieren
print_status "Kopiere Backend Dateien..."
cp -r backend/ "$ADDON_DIR/"

# 4. Frontend kopieren
print_status "Kopiere Frontend Dateien..."
cp -r frontend/ "$ADDON_DIR/"

# 5. README für Add-on erstellen
print_status "Erstelle Add-on Dokumentation..."
cat > "$ADDON_DIR/README.md" << 'EOF'
# Bauplan-Checker Home Assistant Add-on

## Installation

1. Kopieren Sie diesen Ordner nach `/addons/bauplan-checker/`
2. Starten Sie Home Assistant neu
3. Gehen Sie zu Settings → Add-ons → Local Add-ons
4. Installieren Sie "Bauplan-Checker"
5. Konfigurieren Sie Ihren OpenAI API Key
6. Starten Sie das Add-on

## Konfiguration

```yaml
openai_api_key: "sk-proj-XXXXXXXXXXXXXXXX"
log_level: "info"
```

## Zugriff

- Frontend: http://homeassistant.local:3000
- Backend API: http://homeassistant.local:8000

## DIN-Normen

Kopieren Sie PDF-Dateien nach `/share/bauplan-checker/din_norms/`
EOF

# 6. Installation Package erstellen
print_status "Erstelle Installations-Archiv..."
tar -czf "bauplan-checker-homeassistant-addon.tar.gz" "$ADDON_DIR"

# 7. Installations-Anweisungen
print_success "Add-on Paket erstellt!"
echo ""
echo "=================================================="
echo "🏠 INSTALLATION ANWEISUNGEN:"
echo "=================================================="
echo ""
echo "METHODE 1: Datei-Manager (Empfohlen)"
echo "1. Entpacken Sie: bauplan-checker-homeassistant-addon.tar.gz"
echo "2. Kopieren Sie den Ordner 'bauplan-checker-addon' nach:"
echo "   /usr/share/hassio/addons/local/"
echo "   (oder wo immer Ihre Add-ons gespeichert sind)"
echo ""
echo "METHODE 2: Home Assistant Terminal"
echo "1. Laden Sie bauplan-checker-homeassistant-addon.tar.gz in /tmp/"
echo "2. Im HA Terminal:"
echo "   cd /addons"
echo "   tar -xzf /tmp/bauplan-checker-homeassistant-addon.tar.gz"
echo "   mv bauplan-checker-addon bauplan-checker"
echo ""
echo "METHODE 3: Samba/SSH (falls verfügbar)"
echo "scp bauplan-checker-homeassistant-addon.tar.gz root@192.168.178.87:/tmp/"
echo ""
echo "=================================================="
echo "🔧 NACH DER INSTALLATION:"
echo "=================================================="
echo "1. Home Assistant → Settings → Add-ons"
echo "2. Reload (oben rechts)"
echo "3. Local Add-ons → Bauplan-Checker"
echo "4. Install → Configuration → OpenAI API Key setzen"
echo "5. Start"
echo ""
echo "DIN-Normen kopieren nach:"
echo "/share/bauplan-checker/din_norms/"
echo ""
print_success "Installation bereit!"

# 8. DIN-Normen Paket erstellen (falls vorhanden)
if [ -d "backend/din_norms" ] && [ "$(ls -A backend/din_norms/*.pdf 2>/dev/null)" ]; then
    print_status "Erstelle DIN-Normen Paket..."
    tar -czf "din-norms-package.tar.gz" -C backend din_norms/
    print_success "DIN-Normen Paket erstellt: din-norms-package.tar.gz"
    echo "Entpacken in Home Assistant nach: /share/bauplan-checker/"
fi

echo ""
echo "Erstellte Dateien:"
ls -la bauplan-checker-*.tar.gz din-norms-*.tar.gz 2>/dev/null || true 