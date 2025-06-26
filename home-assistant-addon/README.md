# 🏗️ Bauplan-Checker Home Assistant Add-on

## Über das Add-on

Der Bauplan-Checker ist eine professionelle KI-basierte Lösung zur automatischen Prüfung von Ingenieursplänen gegen deutsche DIN-Normen. Das Add-on nutzt modernste AI-Technologie zur Analyse von PDF-Bauplänen und erstellt detaillierte Compliance-Berichte.

## Features

- 🤖 **KI-basierte Analyse** mit OpenAI GPT-4
- 📋 **DIN-Normen Compliance** Checking gegen deutsche Standards
- 🔍 **OCR-Unterstützung** für gescannte PDF-Dokumente
- 💰 **Budget-Überwachung** für API-Kosten
- 🎨 **Moderne Web-UI** mit React/Next.js
- 📊 **Detaillierte Berichte** mit konkreten Verbesserungsvorschlägen
- 🔄 **Automatische Updates** über GitHub Container Registry

## Installation

1. **Add-on Repository hinzufügen** (falls lokale Installation):
   - Gehen Sie zu **Settings → Add-ons → Add-on Store**
   - Klicken Sie auf die drei Punkte (⋮) → **Repositories**
   - Fügen Sie hinzu: `https://github.com/christianbernecker/bauplan-checker`

2. **Add-on installieren**:
   - Suchen Sie nach "Bauplan-Checker" im Add-on Store
   - Klicken Sie auf **INSTALL**
   - Warten Sie, bis die Installation abgeschlossen ist

3. **Konfiguration**:
   ```yaml
   openai_api_key: "sk-your-openai-api-key-here"
   log_level: "info"
   max_monthly_budget: 20.0
   warn_at_budget: 15.0
   ```

4. **Add-on starten**:
   - Klicken Sie auf **START**
   - Das Add-on erscheint in der Seitenleiste

## Konfiguration

### OpenAI API Key
Erstellen Sie einen API Key bei [OpenAI](https://platform.openai.com/api-keys) und tragen Sie ihn in die Add-on Konfiguration ein.

### Budget-Überwachung
- `max_monthly_budget`: Maximales monatliches Budget in USD (Standard: 20.0)
- `warn_at_budget`: Warnung bei Erreichen dieses Betrags in USD (Standard: 15.0)

### Log Level
- `debug`: Ausführliche Debug-Informationen
- `info`: Standard-Informationen (empfohlen)
- `warning`: Nur Warnungen und Fehler
- `error`: Nur Fehler

## Verwendung

1. **Web-UI öffnen**:
   - Klicken Sie auf das Bauplan-Checker Icon in der Seitenleiste
   - Oder besuchen Sie direkt: `http://your-home-assistant:3000`

2. **PDF hochladen**:
   - Ziehen Sie eine PDF-Datei in den Upload-Bereich
   - Oder klicken Sie auf "Datei auswählen"

3. **Analyse starten**:
   - Das System analysiert automatisch den Text
   - Die DIN-Normen-Prüfung wird durchgeführt
   - Ein detaillierter Bericht wird erstellt

4. **Ergebnisse anzeigen**:
   - Compliance-Status
   - Identifizierte Probleme
   - Konkrete Verbesserungsvorschläge
   - Relevante DIN-Normen-Referenzen

## DIN-Normen hinzufügen

Kopieren Sie DIN-Normen PDFs in das Home Assistant Share-Verzeichnis:
```
/share/bauplan-checker/din_norms/
```

Unterstützte Formate:
- Digitale PDFs (bevorzugt)
- Gescannte PDFs (mit OCR-Verarbeitung)

## Troubleshooting

### Add-on startet nicht
- Prüfen Sie den OpenAI API Key
- Überprüfen Sie die Logs: **Add-ons → Bauplan-Checker → Logs**
- Stellen Sie sicher, dass Ports 3000 und 8000 nicht belegt sind

### Lange Ladezeiten
- Erste Installation kann 5-10 Minuten dauern
- Überprüfen Sie die Internetverbindung
- Bei ARM64-Systemen (Raspberry Pi) kann der Build länger dauern

### API-Fehler
- Überprüfen Sie Ihr OpenAI-Guthaben
- Prüfen Sie die Budget-Einstellungen
- Kontrollieren Sie die API-Key-Berechtigung

## Support

- **GitHub Repository**: https://github.com/christianbernecker/bauplan-checker
- **Issues**: https://github.com/christianbernecker/bauplan-checker/issues
- **Dokumentation**: Siehe Repository README

## Lizenz

MIT License - Siehe LICENSE Datei im Repository

## Changelog

### Version 1.0.0
- Initiale Veröffentlichung
- Multi-Architektur Support (AMD64/ARM64)
- Pre-built Container Image
- Vollständige Home Assistant Integration 