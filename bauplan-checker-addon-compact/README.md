# 🏗️ Bauplan-Checker Home Assistant Add-on

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/christianbernecker/bauplan-checker)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-Add--on-orange.svg)](https://www.home-assistant.io/addons/)

KI-basierte automatische Prüfung von Ingenieursplänen gegen deutsche DIN-Normen mit OpenAI GPT-4, React/Next.js Frontend und Python FastAPI Backend.

## ✨ Features

- 🤖 **KI-basierte Analyse** mit OpenAI GPT-4 Turbo
- 📋 **DIN-Normen Compliance** Checking
- 🔍 **OCR-Unterstützung** für gescannte Dokumente
- 📊 **Detaillierte Berichte** mit Verbesserungsvorschlägen
- 💰 **Budget-Überwachung** für API-Kosten
- 🔄 **Automatische Backups** über Home Assistant
- 🎨 **Moderne Web-UI** mit React/Next.js
- 📱 **Responsive Design** für alle Geräte

## 🚀 Installation

### 1. Add-on Repository hinzufügen

1. Öffnen Sie Home Assistant
2. Gehen Sie zu **Settings** → **Add-ons**
3. Klicken Sie auf **⋮** (drei Punkte) → **Repositories**
4. Fügen Sie diese URL hinzu:
   ```
   https://github.com/christianbernecker/bauplan-checker
   ```

### 2. Add-on installieren

1. Gehen Sie zu **Settings** → **Add-ons** → **Add-on Store**
2. Suchen Sie nach "**Bauplan-Checker**"
3. Klicken Sie auf **INSTALL**
4. Warten Sie auf die Installation (kann 5-10 Minuten dauern)

### 3. Konfiguration

Bevor Sie das Add-on starten, müssen Sie es konfigurieren:

1. Gehen Sie zu **Settings** → **Add-ons** → **Bauplan-Checker**
2. Klicken Sie auf **Configuration**
3. Fügen Sie Ihren **OpenAI API Key** hinzu:

```yaml
openai_api_key: "sk-your-openai-api-key-here"
log_level: "info"
max_monthly_budget: 20.0
warn_at_budget: 15.0
```

### 4. Starten

1. Klicken Sie auf **START**
2. Warten Sie auf die Meldung "Add-on started successfully"
3. Klicken Sie auf **OPEN WEB UI**

## ⚙️ Konfiguration

| Option | Beschreibung | Standard | Erforderlich |
|--------|--------------|----------|--------------|
| `openai_api_key` | Ihr OpenAI API Schlüssel | - | ✅ |
| `log_level` | Log-Level (debug/info/warning/error) | `info` | ❌ |
| `max_monthly_budget` | Maximales monatliches Budget in USD | `20.0` | ❌ |
| `warn_at_budget` | Warnung bei Budget-Erreichen in USD | `15.0` | ❌ |

## 📚 DIN-Normen hinzufügen

### Automatisch (empfohlen)

1. Laden Sie Ihre PDF-DIN-Normen in das Home Assistant Share-Verzeichnis:
   ```
   /share/bauplan-checker/din_norms/
   ```

2. Starten Sie das Add-on neu oder verwenden Sie den **"DIN-Normen verarbeiten"** Button in der Web-UI

### Manuell über Web-UI

1. Öffnen Sie die Bauplan-Checker Web-UI
2. Gehen Sie zu **Einstellungen** → **DIN-Normen**
3. Laden Sie Ihre PDF-Dateien hoch

## 🔧 Verwendung

### 1. Plan hochladen

1. Öffnen Sie die Web-UI
2. Klicken Sie auf **"Plan hochladen"**
3. Wählen Sie eine PDF-Datei (max. 50MB)
4. Warten Sie auf die OCR-Verarbeitung

### 2. DIN-Normen Prüfung

1. Klicken Sie auf **"Gegen DIN-Normen prüfen"**
2. Warten Sie auf die KI-Analyse (1-3 Minuten)
3. Betrachten Sie den detaillierten Bericht

### 3. Ergebnisse verwalten

- **Exportieren**: PDF-Berichte generieren
- **Feedback**: Bewertungen für Verbesserungen
- **Historie**: Alle Analysen einsehen

## 🗂️ Datenverzeichnisse

Das Add-on verwendet folgende Verzeichnisse:

- `/share/bauplan-checker/uploads/` - Hochgeladene Pläne
- `/share/bauplan-checker/din_norms/` - DIN-Normen PDFs  
- `/share/bauplan-checker/analysis_results/` - Analyseergebnisse
- `/share/bauplan-checker/system_prompts/` - Custom AI-Prompts
- `/addon_config/logs/` - Add-on Logs

## 📊 API-Endpoints

Das Add-on stellt eine REST-API zur Verfügung:

- `GET /health` - Health Check
- `POST /upload-plan` - Plan hochladen
- `POST /check-against-din/{plan_id}` - DIN-Prüfung starten
- `GET /plans` - Alle Pläne auflisten
- `GET /budget-status` - Budget-Status abfragen

## 🔍 Troubleshooting

### Add-on startet nicht

1. Überprüfen Sie die Logs: **Settings** → **Add-ons** → **Bauplan-Checker** → **Log**
2. Stellen Sie sicher, dass der OpenAI API Key korrekt ist
3. Prüfen Sie die verfügbaren Systemressourcen

### Langsame Performance

- **RAM**: Mindestens 4GB empfohlen
- **CPU**: Multi-Core Prozessor empfohlen
- **Speicher**: 5GB freier Speicherplatz

### Budget-Warnungen

- Überwachen Sie die Kosten im **Budget-Dashboard**
- Passen Sie `max_monthly_budget` in der Konfiguration an
- Nutzen Sie kleinere PDF-Dateien für Tests

## 🐛 Support

Bei Problemen oder Fragen:

1. **GitHub Issues**: [https://github.com/christianbernecker/bauplan-checker/issues](https://github.com/christianbernecker/bauplan-checker/issues)
2. **Home Assistant Community**: [https://community.home-assistant.io](https://community.home-assistant.io)
3. **Dokumentation**: [https://github.com/christianbernecker/bauplan-checker/wiki](https://github.com/christianbernecker/bauplan-checker/wiki)

## 📝 Changelog

### Version 1.0.0
- 🎉 Erste Veröffentlichung
- ✅ Vollständige Home Assistant Integration
- ✅ OpenAI GPT-4 Integration
- ✅ OCR-Unterstützung
- ✅ Budget-Überwachung
- ✅ Web-UI mit React/Next.js

## 🤝 Beitragen

Beiträge sind willkommen! Siehe [CONTRIBUTING.md](CONTRIBUTING.md) für Details.

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe [LICENSE](LICENSE) für Details.

---

**Entwickelt mit ❤️ für die Home Assistant Community** 