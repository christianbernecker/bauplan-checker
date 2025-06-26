# Changelog

## [1.0.0] - 2025-01-26

### 🎉 Erste Veröffentlichung

#### Hinzugefügt
- ✅ **Home Assistant Add-on** - Vollständige Integration in Home Assistant
- ✅ **OpenAI GPT-4 Integration** - KI-basierte DIN-Normen Analyse
- ✅ **OCR-Unterstützung** - Erkennung von gescannten PDF-Dokumenten
- ✅ **React/Next.js Frontend** - Moderne Web-Benutzeroberfläche
- ✅ **Python FastAPI Backend** - Robuste API-Architektur
- ✅ **Budget-Überwachung** - Kontrolle der OpenAI API-Kosten
- ✅ **DIN-Normen Verwaltung** - Upload und Verarbeitung von PDF-Normen
- ✅ **Detaillierte Berichte** - Compliance-Prüfung mit Verbesserungsvorschlägen
- ✅ **Health-Checks** - Monitoring der Add-on Gesundheit
- ✅ **Supervisor Integration** - Prozess-Management für Stabilität
- ✅ **Persistente Daten** - Speicherung in Home Assistant Share-Verzeichnis
- ✅ **Responsive Design** - Optimiert für Desktop, Tablet und Mobile

#### Technische Features
- 🐳 **Docker-Container** mit Alpine Linux
- 🔄 **Automatische Neustarts** bei Prozess-Fehlern
- 📊 **Health-Check Endpoints** für Monitoring
- 🗃️ **Share-Integration** für persistente Daten
- 🔐 **Sichere Konfiguration** über Home Assistant UI
- 📝 **Umfangreiches Logging** für Debugging

#### Unterstützte Formate
- 📄 **PDF-Dokumente** (bis 50MB)
- 🔍 **OCR für gescannte PDFs** mit Tesseract
- 🏗️ **Technische Zeichnungen** Erkennung
- 📋 **DIN-Normen PDFs** als Referenz

#### API-Endpoints
- `GET /health` - System-Status
- `POST /upload-plan` - Plan hochladen
- `POST /check-against-din/{plan_id}` - DIN-Prüfung
- `GET /plans` - Plan-Übersicht
- `GET /budget-status` - Budget-Monitoring
- `POST /process-din-norms` - DIN-Normen verarbeiten

#### Konfiguration
- `openai_api_key` - OpenAI API Schlüssel (erforderlich)
- `log_level` - Log-Level (debug/info/warning/error)
- `max_monthly_budget` - Maximales monatliches Budget
- `warn_at_budget` - Budget-Warnschwelle

#### Systemanforderungen
- **Architektur**: aarch64 oder amd64 (64-bit)
- **RAM**: Mindestens 4GB empfohlen
- **Speicher**: 5GB freier Speicherplatz
- **Home Assistant**: Version 2023.1 oder höher

---

**Entwickelt mit ❤️ für die Home Assistant Community** 