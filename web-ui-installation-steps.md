# 🏠 Bauplan-Checker Home Assistant Web-Installation

## SCHRITT 1: Add-on Dateien bereitstellen

### Option A: File Editor Upload
1. **Home Assistant Web-UI** öffnen
2. **Settings → Add-ons → Store**
3. **File editor** suchen und installieren
4. **File editor** öffnen
5. Upload: `bauplan-checker-homeassistant-addon.tar.gz`
6. Upload: `din-norms-package.tar.gz`

### Option B: Home Assistant Terminal (bereits offen!)
Im Terminal das Sie bereits haben:
```bash
mkdir -p /addons/local/bauplan-checker
mkdir -p /share/bauplan-checker
```

## SCHRITT 2: Installation über Web-UI

1. **Settings → Add-ons**
2. **⟳ Reload** (oben rechts)
3. **Local Add-ons** → **Bauplan-Checker**
4. **Install** klicken
5. **Configuration** Tab:
   ```yaml
   openai_api_key: "sk-proj-IHRE-API-KEY-HIER"
   log_level: "info"
   ```
6. **Start** klicken

## SCHRITT 3: Zugriff

- **Frontend**: http://192.168.178.87:3000
- **Backend API**: http://192.168.178.87:8000
- **In Home Assistant**: Sidebar → Bauplan-Checker

## SCHRITT 4: DIN-Normen hochladen

**File Editor** verwenden:
- Upload PDFs nach: `/share/bauplan-checker/din_norms/`
- Oder entpacken: `din-norms-package.tar.gz`

## ✅ FERTIG!
Das System ist dann als natives Home Assistant Add-on verfügbar!
