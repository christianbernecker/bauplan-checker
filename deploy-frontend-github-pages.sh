#!/bin/bash

# ========================================
# BAUPLAN-CHECKER FRONTEND DEPLOYMENT
# GitHub Pages Deployment
# ========================================

set -e  # Exit bei Fehler

echo "🌐 BAUPLAN-CHECKER FRONTEND DEPLOYMENT"
echo "======================================"

# Farben für bessere Lesbarkeit
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# ========================================
# 1. VORBEREITUNG
# ========================================

print_status "Frontend Deployment vorbereiten..."

# Zum Frontend-Verzeichnis wechseln
cd frontend

# Node.js Version prüfen
if ! command -v node &> /dev/null; then
    print_error "Node.js ist nicht installiert!"
    exit 1
fi

print_success "Node.js Version: $(node --version)"

# ========================================
# 2. DEPENDENCIES INSTALLIEREN
# ========================================

print_status "Dependencies installieren..."

npm install

print_success "Dependencies installiert"

# ========================================
# 3. NEXT.JS KONFIGURATION PRÜFEN
# ========================================

print_status "Next.js Konfiguration prüfen..."

# Prüfe ob next.config.ts korrekt konfiguriert ist
if grep -q "output: 'export'" next.config.ts; then
    print_success "Next.js für statischen Export konfiguriert"
else
    print_warning "Next.js Konfiguration anpassen..."
    
    cat > next.config.ts << 'EOF'
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: 'export',
  trailingSlash: true,
  images: {
    unoptimized: true
  },
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://192.168.2.19:8000'
  }
};

export default nextConfig;
EOF
    
    print_success "Next.js Konfiguration aktualisiert"
fi

# ========================================
# 4. ENVIRONMENT KONFIGURATION
# ========================================

print_status "Environment Konfiguration..."

# Erstelle .env.local für lokale Entwicklung
cat > .env.local << 'EOF'
# API Configuration
NEXT_PUBLIC_API_URL=http://192.168.2.19:8000

# GitHub Pages Configuration
NEXT_PUBLIC_BASE_PATH=
NEXT_PUBLIC_ASSET_PREFIX=

# Development Configuration
NEXT_PUBLIC_ENVIRONMENT=production
EOF

print_success "Environment Konfiguration erstellt"

# ========================================
# 5. BUILD DURCHFÜHREN
# ========================================

print_status "Frontend Build starten..."

# Clean previous build
rm -rf out/
rm -rf docs/
rm -rf .next/

print_status "Build-Verzeichnisse bereinigt"

# Build ausführen
npm run build

if [ $? -eq 0 ]; then
    print_success "Build erfolgreich abgeschlossen"
else
    print_error "Build fehlgeschlagen!"
    exit 1
fi

# ========================================
# 6. STATISCHE DATEIEN VORBEREITEN
# ========================================

print_status "Statische Dateien für GitHub Pages vorbereiten..."

# out/ Verzeichnis zu docs/ kopieren (GitHub Pages Standard)
if [ -d "out" ]; then
    cp -r out/ docs/
    print_success "Statische Dateien nach docs/ kopiert"
else
    print_error "out/ Verzeichnis nicht gefunden!"
    exit 1
fi

# .nojekyll Datei erstellen (verhindert Jekyll-Processing)
touch docs/.nojekyll
print_success ".nojekyll Datei erstellt"

# ========================================
# 7. GIT VORBEREITUNG
# ========================================

print_status "Git Repository vorbereiten..."

cd ..  # Zurück zum Root-Verzeichnis

# Git Status prüfen
if ! git status &> /dev/null; then
    print_error "Kein Git Repository gefunden!"
    exit 1
fi

# docs/ zu Git hinzufügen
git add frontend/docs/
git add frontend/next.config.ts
git add frontend/.env.local

print_success "Dateien zu Git hinzugefügt"

# ========================================
# 8. COMMIT UND PUSH
# ========================================

print_status "Änderungen committen und pushen..."

# Commit erstellen
COMMIT_MSG="🌐 Frontend Build für GitHub Pages - $(date '+%Y-%m-%d %H:%M:%S')"
git commit -m "$COMMIT_MSG" || print_warning "Keine Änderungen zum Committen"

# Push zu GitHub
git push origin main

print_success "Änderungen zu GitHub gepusht"

# ========================================
# 9. GITHUB PAGES AKTIVIERUNG
# ========================================

print_status "GitHub Pages Aktivierung..."

echo ""
echo "📋 MANUELLE SCHRITTE FÜR GITHUB PAGES:"
echo "======================================"
echo ""
echo "1. Gehe zu GitHub Repository:"
echo "   https://github.com/christianbernecker/bauplan-checker"
echo ""
echo "2. Klicke auf 'Settings' Tab"
echo ""
echo "3. Scrolle zu 'Pages' Sektion"
echo ""
echo "4. Konfiguriere GitHub Pages:"
echo "   • Source: Deploy from a branch"
echo "   • Branch: main"
echo "   • Folder: /frontend/docs"
echo ""
echo "5. Klicke 'Save'"
echo ""
echo "6. Warte 2-5 Minuten auf Deployment"
echo ""
echo "7. Frontend wird verfügbar sein unter:"
echo "   https://christianbernecker.github.io/bauplan-checker/"
echo ""

# ========================================
# 10. LOKALER TEST
# ========================================

print_status "Lokalen Test-Server starten..."

cd frontend

# Lokaler Server für Test
print_status "Starte lokalen Server für Test..."
print_status "Frontend wird getestet unter: http://localhost:3000"
print_status "API Backend sollte laufen unter: http://192.168.2.19:8000"

echo ""
echo "🧪 LOKALER TEST:"
echo "==============="
echo "• Frontend: http://localhost:3000"
echo "• Backend API: http://192.168.2.19:8000"
echo "• API Docs: http://192.168.2.19:8000/docs"
echo ""

# Kurzer Test ob API erreichbar ist
if curl -f http://192.168.2.19:8000/ > /dev/null 2>&1; then
    print_success "✅ Backend API ist erreichbar"
else
    print_warning "⚠️ Backend API nicht erreichbar - starte zuerst das Backend"
fi

# ========================================
# 11. DEPLOYMENT ZUSAMMENFASSUNG
# ========================================

echo ""
echo "🎉 FRONTEND DEPLOYMENT ABGESCHLOSSEN!"
echo "===================================="
echo ""
echo "📍 Build Details:"
echo "   • Build-Verzeichnis: frontend/docs/"
echo "   • Statische Dateien: ✅ Erstellt"
echo "   • Git Push: ✅ Abgeschlossen"
echo ""
echo "🌐 URLs (nach GitHub Pages Aktivierung):"
echo "   • Frontend: https://christianbernecker.github.io/bauplan-checker/"
echo "   • Backend: http://192.168.2.19:8000"
echo ""
echo "🛠️ Nächste Schritte:"
echo "   1. GitHub Pages in Repository-Settings aktivieren"
echo "   2. 2-5 Minuten auf Deployment warten"
echo "   3. Frontend-URL im Browser öffnen"
echo "   4. Bauplan-Upload testen"
echo ""
echo "📋 Test-Befehle:"
echo "   • Lokaler Test: npm run dev"
echo "   • Build-Test: npm run build"
echo "   • Backend-Status: curl http://192.168.2.19:8000/"
echo ""

# Optional: Lokalen Dev-Server starten
read -p "Soll der lokale Entwicklungsserver gestartet werden? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Starte lokalen Entwicklungsserver..."
    npm run dev
else
    print_success "Frontend Deployment abgeschlossen!"
fi

echo ""
print_success "🎯 Frontend bereit für GitHub Pages!" 