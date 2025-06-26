# 📁 Samba Share Installation (Empfohlen!)

## SCHRITT 1: Samba Add-on in Home Assistant installieren

1. **Home Assistant Web-UI öffnen**
2. **Settings → Add-ons → Store**
3. **"Samba share" suchen**
4. **Install** klicken
5. **Configuration:**
   ```yaml
   workgroup: WORKGROUP
   username: homeassistant
   password: IhrPasswort
   compatibility_mode: false
   ```
6. **Start** klicken

## SCHRITT 2: Netzwerk-Share aufrufen

**Auf Ihrem Mac:**
1. **Finder öffnen**
2. **Gehe zu → Mit Server verbinden** (Cmd+K)
3. **Server-Adresse eingeben:**
   ```
   smb://192.168.178.87
   ```
4. **Benutzername:** homeassistant
5. **Passwort:** (wie in Konfiguration gesetzt)

## SCHRITT 3: Dateien kopieren

1. **Im Netzwerk-Share navigieren**
2. **Ordner "share" öffnen**
3. **Ordner "bauplan-checker" erstellen**
4. **Dateien hinein kopieren:**
   - bauplan-checker-homeassistant-addon.tar.gz
   - din-norms-package.tar.gz

## SCHRITT 4: Installation im Home Assistant Terminal

```bash
# Im Home Assistant Web Terminal eingeben:
cd /share/bauplan-checker
ls -la  # Dateien prüfen

# Verzeichnisse erstellen
mkdir -p /addons/local/bauplan-checker
mkdir -p /tmp/bauplan-install

# Installation
cd /tmp
cp /share/bauplan-checker/bauplan-checker-homeassistant-addon.tar.gz .
tar -xzf bauplan-checker-homeassistant-addon.tar.gz
cp -r bauplan-checker-addon/* /addons/local/bauplan-checker/
chmod +x /addons/local/bauplan-checker/run.sh

# Supervisor neustarten
systemctl restart hassio-supervisor
```

## ✅ VORTEILE:
- ✅ Keine USB-Sticks nötig
- ✅ Keine HTTP Server
- ✅ Standardprotokoll von Home Assistant
- ✅ Einfache Drag & Drop Übertragung
- ✅ Funktioniert mit allen Dateigrößen
