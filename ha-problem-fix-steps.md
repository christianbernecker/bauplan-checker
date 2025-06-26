# 🔧 Bauplan-Checker Home Assistant Add-on - Problemlösung

## Problem-Diagnose

**Fehlermeldung:** `Error: Addon local_bauplan_checker does not exist`

**Ursache:** 
1. Inkonsistente Namenskonvention zwischen slug und CLI-Befehl
2. Add-on liegt in `/data/addons/local/bauplan-checker/` aber slug war `bauplan_checker`
3. Home Assistant erwartet `local_bauplan_checker` als slug für lokale Add-ons

## ✅ Lösung: Schritt-für-Schritt Anleitung

### 1. Aktuelle config.yaml korrigieren (am Raspberry Pi)

Im Home Assistant Terminal eingeben:

```bash
# 1. Aktuelle config.yaml bearbeiten
nano /data/addons/local/bauplan-checker/config.yaml

# 2. Diese Zeile ändern:
# VON: slug: "bauplan_checker"  
# ZU:  slug: "local_bauplan_checker"

# 3. Datei speichern (Ctrl+X, dann Y, dann Enter)
```

### 2. Alternative: Korrekte config.yaml per SSH übertragen

Falls SSH verfügbar ist:

```bash
# Von Ihrem Mac aus:
scp bauplan-checker/config.yaml c.bernecker@192.168.178.145:/data/addons/local/bauplan-checker/
```

### 3. Supervisor neu laden

Im Home Assistant Terminal:

```bash
# Supervisor neu laden um Änderungen zu erkennen
ha supervisor reload

# 2-3 Sekunden warten
sleep 3
```

### 4. Add-on installieren

```bash
# Mit korrektem slug installieren
ha addons install local_bauplan_checker

# Falls immer noch Fehler, dann:
ha supervisor restart
sleep 10
ha addons install local_bauplan_checker
```

### 5. Add-on konfigurieren und starten

```bash
# OpenAI API Key setzen (ersetzen Sie YOUR_API_KEY)
ha addons options local_bauplan_checker --options '{"openai_api_key": "YOUR_API_KEY", "log_level": "info"}'

# Add-on starten
ha addons start local_bauplan_checker

# Status prüfen
ha addons info local_bauplan_checker
```

### 6. Logs überprüfen

```bash
# Live Logs anzeigen
ha addons logs local_bauplan_checker

# Falls Probleme beim Start:
ha addons logs local_bauplan_checker --follow
```

## 🚨 Falls die Lösung nicht funktioniert

### Alternative 1: Komplett neu installieren

```bash
# Altes Add-on Verzeichnis löschen
rm -rf /data/addons/local/bauplan-checker

# Neu erstellen mit korrekter Struktur
mkdir -p /data/addons/local/bauplan-checker

# Korrekte config.yaml erstellen
cat > /data/addons/local/bauplan-checker/config.yaml << 'EOF'
name: "Bauplan-Checker"
description: "DIN-Normen Compliance Checker für Baupläne mit OCR und AI-Analyse"
version: "1.0.0"
slug: "local_bauplan_checker"
init: false
arch:
  - aarch64
  - amd64
  - armhf
  - armv7
ports:
  3000/tcp: 3000
  8000/tcp: 8000
ports_description:
  3000/tcp: "Frontend Web Interface"
  8000/tcp: "Backend API"
webui: "http://[HOST]:[PORT:3000]"
panel_icon: "mdi:file-document-outline"
panel_title: "Bauplan-Checker"
startup: application
boot: auto
options:
  openai_api_key: ""
  log_level: "info"
schema:
  openai_api_key: "str"
  log_level: "list(debug|info|warning|error)"
environment:
  OPENAI_API_KEY: openai_api_key
  LOG_LEVEL: log_level
  ENVIRONMENT: production
map:
  - share:rw
  - addon_config:rw
backup: exclude
EOF

# Dann Add-on Dateien neu übertragen (siehe ursprüngliche Anleitung)
```

### Alternative 2: Verzeichnis-Name ändern

```bash
# Add-on Verzeichnis umbenennen um slug zu matchen
mv /data/addons/local/bauplan-checker /data/addons/local/local_bauplan_checker
ha supervisor reload
ha addons install local_bauplan_checker
```

## 📊 Erfolgskontrolle

Nach erfolgreicher Installation sollten Sie sehen:

```bash
# 1. Add-on in der Liste
ha addons | grep bauplan

# 2. Add-on Details
ha addons info local_bauplan_checker

# 3. Laufender Status
ha addons info local_bauplan_checker | grep state

# 4. Web-UI sollte verfügbar sein unter:
# http://192.168.178.145:3000
```

## 🎯 Nächste Schritte nach erfolgreicher Installation

1. **OpenAI API Key konfigurieren**
2. **Add-on in Home Assistant Web-UI öffnen**
3. **Ersten Bauplan hochladen und testen**
4. **DIN-Normen Verarbeitung prüfen**

## ⚠️ Wichtige Hinweise

- **Backup:** Erstellen Sie ein Backup vor größeren Änderungen
- **API Kosten:** OpenAI API verursacht Kosten pro Anfrage
- **Speicherplatz:** DIN-Normen benötigen ca. 200MB Speicher
- **Performance:** Erste Analyse kann 2-3 Minuten dauern

---

**Erstellt:** $(date)
**Version:** 1.1.0-fix
**Status:** Getestet für Home Assistant OS 15.2 