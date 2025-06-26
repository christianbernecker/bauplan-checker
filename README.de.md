# Bauplan-Checker: Automatische Prüfung von Ingenieurplänen

## Projektübersicht

Das Bauplan-Checker System ist eine moderne Web-Applikation zur automatischen Prüfung von Bauplänen gegen DIN-Normen. Das System ermöglicht es Ingenieuren, PDF-Pläne hochzuladen und diese mithilfe von KI-Technologie gegen relevante DIN-Normen zu validieren.

## Hauptfunktionen

### ✨ Kernfeatures
- **PDF-Upload**: Einfacher Upload von Bauplan-PDFs über Drag & Drop
- **DIN-Normen-Prüfung**: Automatische Validierung gegen hinterlegte DIN-Normen
- **KI-Analyse**: Intelligente Textanalyse mit OpenAI GPT-4
- **Lernfähigkeit**: System lernt aus Feedback zu guten/schlechten Plänen
- **Feedback-System**: Bewertung und Kommentierung von Prüfergebnissen

### 🏗️ Technologie-Stack

**Frontend:**
- React/Next.js 14 mit TypeScript
- Tailwind CSS für modernes Design
- react-dropzone für PDF-Upload
- Responsive Design für alle Geräte

**Backend:**
- Python FastAPI für REST API
- LangChain für AI-Integration
- FAISS Vektordatenbank für DIN-Normen
- PyPDF2 für PDF-Textextraktion
- OpenAI API für Textanalyse

**AI/ML:**
- OpenAI GPT-4 für Textanalyse
- LangChain für RAG (Retrieval Augmented Generation)
- Vektor-Embeddings für semantische Suche
- Feedback-Learning für kontinuierliche Verbesserung

## Architektur

```
Web Frontend          API Backend           Vector DB
(React/Next)     →    (FastAPI)        →    (PostgreSQL)
                           ↓
                    OpenAI API
                  + LangChain
```

## Anforderungen

- Python 3.8+
- Node.js 18+
- OpenAI API Key
- DIN-Normen als PDF-Dateien

## Schnellstart

### 1. Repository klonen
```bash
git clone <repository-url>
cd bauplan-checker
```

### 2. Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Environment konfigurieren
```bash
# Erstelle backend/.env
OPENAI_API_KEY=sk-your-openai-key-here
```

### 4. DIN-Normen vorbereiten
- Lege DIN-Norm PDFs in `backend/din_norms/` ab
- Benenne sie eindeutig (z.B. `DIN_1045-2_Beton.pdf`)

### 5. DIN-Normen verarbeiten
```bash
cd backend
python din_processor.py
```

### 6. Frontend Setup
```bash
cd frontend
npm install
```

### 7. System starten
```bash
# Terminal 1 - Backend
cd backend
python main.py

# Terminal 2 - Frontend  
cd frontend
npm run dev
```

### 8. Anwendung nutzen
- Öffne http://localhost:3000
- Lade einen Bauplan (PDF) hoch
- Warte auf die Basis-Analyse
- Führe DIN-Normen-Prüfung durch

## Projektstruktur

```
bauplan-checker/
├── frontend/                 # React/Next.js Frontend
│   ├── app/                 # Next.js App Router
│   │   ├── page.tsx        # Hauptseite
│   │   └── layout.tsx      # Layout-Komponente
│   ├── components/         # React-Komponenten
│   └── package.json
├── backend/                 # Python Backend
│   ├── main.py             # FastAPI Hauptserver
│   ├── din_processor.py    # DIN-Normen Verarbeitung
│   ├── uploads/            # Hochgeladene PDFs
│   ├── din_norms/          # DIN-Norm PDFs
│   ├── analysis_results/   # Analyseergebnisse
│   └── requirements.txt
├── data/                   # Datenverzeichnis
│   ├── din_norms/         # DIN-Normen PDFs
│   └── uploads/           # Hochgeladene Pläne
└── README.de.md           # Diese Datei
```

## Entwicklung

### Qualitätsstandards
- Code-Review vor jedem Commit
- Automatische Tests für kritische Funktionen
- Staging-Deployment vor Production
- Kontinuierliche Verbesserung basierend auf Feedback

### Git Workflow
1. Feature-Branch erstellen
2. Entwicklung und Tests
3. Code-Review
4. Staging-Deployment
5. Production-Deployment (nur nach Freigabe)

## Deployment

### Staging
```bash
# Siehe Deployment.md für Details
./deploy-staging.sh
```

### Production
```bash
# Nur nach expliziter Freigabe
./deploy-production.sh
```

## Wichtige Hinweise

### 📋 Voraussetzungen
- **OpenAI API**: Kosten können bei vielen Anfragen steigen
- **PDF-Qualität**: Nur digitale PDFs (nicht gescannt) werden optimal unterstützt
- **DIN-Normen**: Rechtliche Prüfung der Nutzungsrechte erforderlich
- **Datenschutz**: Sensible Baupläne - lokale Installation empfohlen

### ⚠️ Limitierungen
- OCR für gescannte PDFs noch nicht implementiert
- Begrenzte Anzahl DIN-Normen im Demo-System
- API-Rate-Limits bei OpenAI beachten

### 🚀 Geplante Features
- Batch-Upload für mehrere PDFs
- Erweiterte Visualisierung mit PDF-Markierungen
- Team-Funktionen und Benutzerverwaltung
- Export-Funktionen für Prüfberichte
- OCR-Integration für gescannte Dokumente

## Support

Bei Fragen oder Problemen:
1. Prüfe die Dokumentation in `docs/`
2. Schaue in die FAQ-Sektion
3. Erstelle ein Issue im Repository

## Lizenz

[Lizenz-Information hier einfügen]

---

**Letztes Update:** $(date)
**Version:** 1.0.0-beta
**Autor:** Christian Bernecker 