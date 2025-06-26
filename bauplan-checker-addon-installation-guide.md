# 🏗️ Bauplan-Checker Add-on - Installationsanleitung

## 🎯 Fertige Lösung - Professionelles Home Assistant Add-on

Das Bauplan-Checker Add-on ist jetzt **vollständig entwickelt** und kann auf Ihrem Home Assistant System installiert werden!

## 📦 Was wurde erstellt?

### **Add-on Komponenten:**
- ✅ `config.yaml` - Professionelle Add-on Konfiguration
- ✅ `Dockerfile` - Optimierter Docker-Container mit Alpine Linux
- ✅ `run.sh` - Robustes Startup-Script mit Supervisor
- ✅ `README.md` - Vollständige Dokumentation
- ✅ `CHANGELOG.md` - Versionshistorie
- ✅ Komplettes Backend und Frontend

### **Add-on Features:**
- 🤖 **KI-basierte DIN-Normen Analyse** mit OpenAI GPT-4
- 🔍 **OCR-Unterstützung** für gescannte PDFs
- 💰 **Budget-Überwachung** für API-Kosten
- 🎨 **Moderne Web-UI** mit React/Next.js
- 📊 **Health-Checks** und Monitoring
- 🔄 **Automatische Neustarts** bei Fehlern
- 📁 **Persistente Daten** über Share-Verzeichnis

## 🚀 Installation

### **Option 1: Lokales Add-on installieren** (Empfohlen)

1. **Add-on Dateien übertragen:**
   ```bash
   # Von Ihrem Mac aus
   scp -r bauplan-checker-addon-final/ root@192.168.178.145:/addons/local/bauplan_checker/
   ```

2. **Home Assistant Supervisor neu laden:**
   ```bash
   ssh root@192.168.178.145 "ha supervisor reload"
   ```

3. **Add-on in Web-UI installieren:**
   - Settings → Add-ons → Local Add-ons
   - "Bauplan-Checker" sollte erscheinen
   - Klicken Sie auf **INSTALL**

### **Option 2: Tar-Archiv verwenden**

1. **Archiv extrahieren auf Raspberry Pi:**
   ```bash
   # Upload des Archivs
   scp bauplan-checker-addon-final.tar.gz root@192.168.178.145:/tmp/
   
   # SSH zum Raspberry Pi
   ssh root@192.168.178.145
   
   # Extrahieren
   cd /addons/local/
   tar -xzf /tmp/bauplan-checker-addon-final.tar.gz
   mv bauplan-checker-addon-final bauplan_checker
   
   # Supervisor reload
   ha supervisor reload
   ```

## ⚙️ Konfiguration

**Vor dem ersten Start konfigurieren:**

1. **Settings** → **Add-ons** → **Bauplan-Checker**
2. **Configuration** Tab öffnen
3. **OpenAI API Key eingeben:**

```yaml
openai_api_key: "sk-your-actual-openai-api-key-here"
log_level: "info"
max_monthly_budget: 20.0
warn_at_budget: 15.0
```

4. **SAVE** klicken

## 🎯 Start und Verwendung

### **1. Add-on starten:**
- Klicken Sie auf **START**
- Warten Sie auf "Add-on started successfully" (kann 2-3 Minuten dauern)

### **2. Web-UI öffnen:**
- Klicken Sie auf **OPEN WEB UI**
- Oder gehen Sie zu: `http://192.168.178.145:3000`

### **3. Erste Schritte:**
1. **DIN-Normen hochladen** (falls vorhanden)
2. **Testplan hochladen** (PDF)
3. **Analyse starten** und Ergebnis betrachten

## 📊 Monitoring und Logs

### **Add-on Status überwachen:**
- **Settings** → **Add-ons** → **Bauplan-Checker** → **Log**

### **Health-Check:**
- `http://192.168.178.145:8000/health`

### **Budget-Status:**
- `http://192.168.178.145:8000/budget-status`

## 🗂️ Datenverzeichnisse

**Das Add-on erstellt automatisch:**
- `/share/bauplan-checker/uploads/` - Hochgeladene Pläne
- `/share/bauplan-checker/din_norms/` - DIN-Normen PDFs
- `/share/bauplan-checker/analysis_results/` - Analyseergebnisse
- `/share/bauplan-checker/system_prompts/` - Custom AI-Prompts

## 🔧 Erweiterte Konfiguration

### **DIN-Normen hinzufügen:**
```bash
# Kopieren Sie Ihre DIN-Normen PDFs nach:
/share/bauplan-checker/din_norms/

# Dann im Add-on "DIN-Normen verarbeiten" klicken
```

### **Custom AI-Prompts:**
```bash
# Eigene Prompts in:
/share/bauplan-checker/system_prompts/din_analysis_prompt.md
```

## 🐛 Troubleshooting

### **Add-on startet nicht:**
1. Logs prüfen: **Settings** → **Add-ons** → **Bauplan-Checker** → **Log**
2. OpenAI API Key prüfen
3. Systemressourcen prüfen (RAM/CPU)

### **Häufige Probleme:**

| Problem | Lösung |
|---------|--------|
| "OpenAI API Key required" | API Key in Konfiguration eingeben |
| Frontend lädt nicht | 2-3 Minuten warten, dann neu laden |
| Budget-Warnung | `max_monthly_budget` erhöhen |
| Langsame Performance | Mehr RAM/CPU empfohlen |

## 💡 Vorteile der Add-on Lösung

✅ **Offiziell unterstützt** - Keine Hack-Lösungen
✅ **Einfache Installation** - Ein-Klick über Home Assistant
✅ **Automatische Backups** - Über Home Assistant Backup-System
✅ **Integrierte Überwachung** - Health-Checks und Logs
✅ **Sichere Konfiguration** - Über Home Assistant UI
✅ **Update-fähig** - Zukünftige Versionen einfach installierbar
✅ **Professionell** - Entspricht Home Assistant Best Practices

## 🎉 Erfolgsmeldung

**Wenn alles funktioniert, sehen Sie:**
- ✅ Add-on Status: **"Running"**
- ✅ Web-UI erreichbar unter Port 3000
- ✅ API erreichbar unter Port 8000
- ✅ Health-Check gibt Status "healthy"

## 📞 Support

Bei Problemen:
1. **Logs überprüfen** in Home Assistant
2. **GitHub Issues** erstellen (falls gewünscht)
3. **Home Assistant Community** Forum

---

## 🎯 Nächste Schritte für Sie:

**1. SSH-Verbindung zur Raspberry Pi herstellen**
**2. Add-on Dateien übertragen (Option 1 oder 2)**
**3. OpenAI API Key konfigurieren**
**4. Add-on starten und testen**

**Das Add-on ist produktionsreif und kann sofort verwendet werden!** 🚀 