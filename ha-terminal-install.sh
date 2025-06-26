#!/bin/bash

# 🏠 Bauplan-Checker Installation über Home Assistant Terminal
# Dieses Skript im Home Assistant Web Terminal ausführen

set -e

echo "🏠 Bauplan-Checker Installation für Home Assistant"
echo "=================================================="

# Farben für bessere Ausgabe
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Systeminfo
print_status "System-Information:"
echo "Hostname: $(hostname)"
echo "IP-Adresse: $(hostname -I)"
echo "Home Assistant Version: $(cat /etc/version 2>/dev/null || echo 'Unknown')"
echo ""

# 2. Verzeichnisse erstellen
print_status "Erstelle Verzeichnisse..."
mkdir -p /addons/local/bauplan-checker
mkdir -p /share/bauplan-checker/{uploads,din_norms,analysis_results,logs}
mkdir -p /tmp/bauplan-install

# 3. Download vom Mac (falls Netzwerk-Transfer möglich)
print_status "Bereite Installation vor..."

# 4. Manual Installation Instructions
print_warning "MANUELLE ÜBERTRAGUNG ERFORDERLICH:"
echo ""
echo "Da die Dateien zu groß für Web-Upload sind, nutzen Sie eine dieser Methoden:"
echo ""
echo "METHOD 1: USB-Stick"
echo "- Kopieren Sie auf USB: bauplan-checker-homeassistant-addon.tar.gz"
echo "- USB in Raspberry Pi einlegen"
echo "- Dann diese Befehle hier ausführen:"
echo ""
echo "  # USB mounten (ersetzen Sie sdXY mit Ihrem USB)"
echo "  mount /dev/sda1 /mnt 2>/dev/null || mount /dev/sdb1 /mnt"
echo "  cp /mnt/bauplan-checker-homeassistant-addon.tar.gz /tmp/"
echo "  umount /mnt"
echo ""
echo "METHOD 2: Netzwerk-Share (Samba)"
echo "- Samba Add-on installieren in Home Assistant"
echo "- Datei in /share/ Verzeichnis kopieren"
echo ""
echo "METHOD 3: Direkte Übertragung"
print_status "Wenn Sie bereits die Dateien haben, fahren Sie mit der Installation fort..."

# 5. Installation (wenn Dateien vorhanden)
if [ -f "/tmp/bauplan-checker-homeassistant-addon.tar.gz" ]; then
    print_status "Installiere Bauplan-Checker..."
    
    # Entpacken
    cd /tmp
    tar -xzf bauplan-checker-homeassistant-addon.tar.gz
    
    # Dateien verschieben
    cp -r bauplan-checker-addon/* /addons/local/bauplan-checker/
    
    # Berechtigungen setzen
    chmod +x /addons/local/bauplan-checker/run.sh
    
    # Add-on Konfiguration anpassen
    cat > /addons/local/bauplan-checker/config.yaml << 'EOF'
{
  "name": "Bauplan-Checker",
  "description": "DIN-Normen Compliance Checker für Baupläne",
  "version": "1.0.0",
  "slug": "bauplan_checker",
  "init": false,
  "arch": ["aarch64", "armv7"],
  "startup": "services",
  "boot": "auto",
  "map": [
    "share:rw",
    "addons:rw"
  ],
  "ports": {
    "8000/tcp": 8000,
    "3000/tcp": 3000
  },
  "ports_description": {
    "8000/tcp": "Backend API",
    "3000/tcp": "Frontend Web-UI"
  },
  "options": {
    "openai_api_key": "",
    "log_level": "info"
  },
  "schema": {
    "openai_api_key": "str",
    "log_level": "list(debug|info|warning|error)?"
  }
}
EOF

    print_success "Add-on Dateien installiert!"
    print_status "Supervisor wird neugestartet..."
    
    # Supervisor neustarten
    systemctl restart hassio-supervisor 2>/dev/null || true
    
    print_success "Installation abgeschlossen!"
    echo ""
    echo "🎉 NÄCHSTE SCHRITTE:"
    echo "1. Gehen Sie zu: Settings → Add-ons"
    echo "2. Klicken Sie: ⟳ (Reload)"
    echo "3. Local Add-ons → Bauplan-Checker"
    echo "4. Configuration → OpenAI API Key eingeben"
    echo "5. Install → Start"
    
else
    print_warning "Datei nicht gefunden: /tmp/bauplan-checker-homeassistant-addon.tar.gz"
    echo ""
    echo "📋 ÜBERTRAGUNG ERFORDERLICH:"
    echo "Bitte übertragen Sie die Dateien zuerst mit einer der oben genannten Methoden."
fi

# 6. System-Status
print_status "System-Status:"
echo "Freier Speicher: $(df -h /addons | tail -1 | awk '{print $4}')"
echo "Add-ons Verzeichnis: $(ls -la /addons/local/ 2>/dev/null | wc -l) Add-ons"
echo ""

print_success "Installations-Skript abgeschlossen!" 