"""
Bauplan-Checker Backend
Haupt-FastAPI-Anwendung für die Prüfung von Bauplänen gegen DIN-Normen
"""

from fastapi import FastAPI, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import PyPDF2
import os
from datetime import datetime, timedelta
import json
from typing import List, Dict, Optional
import openai
from dotenv import load_dotenv
import logging
from pathlib import Path
import shutil
import asyncio
import pytesseract
from PIL import Image
from pdf2image import convert_from_path
import tempfile
import base64
import cv2
import numpy as np
import matplotlib.pyplot as plt
import psutil

# Lokale Imports
from din_processor import DINNormProcessor
from technical_drawing_processor import TechnicalDrawingProcessor

# Environment laden
load_dotenv()

# Logging konfigurieren
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI App
app = FastAPI(
    title="Bauplan-Checker API",
    description="API zur automatischen Prüfung von Bauplänen gegen DIN-Normen",
    version="1.0.0"
)

# CORS für Frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000", 
        "http://127.0.0.1:3000",
        "http://192.168.178.145:3000",
        "http://192.168.178.126:3000"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Verzeichnisse erstellen
UPLOAD_DIR = Path("uploads")
DIN_NORMS_DIR = Path("din_norms")
RESULTS_DIR = Path("analysis_results")

for directory in [UPLOAD_DIR, DIN_NORMS_DIR, RESULTS_DIR]:
    directory.mkdir(exist_ok=True)

# OpenAI Setup
openai.api_key = os.getenv("OPENAI_API_KEY")
if not openai.api_key:
    logger.warning("⚠️ OPENAI_API_KEY nicht gefunden! Bitte in .env-Datei setzen.")

# Processors initialisieren
din_processor = DINNormProcessor()
technical_processor = TechnicalDrawingProcessor()

# Globale Variablen
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB
ALLOWED_EXTENSIONS = {'.pdf'}

# Budget-Überwachung
USAGE_LOG_FILE = Path("usage_log.json")

def log_api_usage(endpoint: str, tokens_used: int, cost_estimate: float):
    """API-Nutzung protokollieren"""
    try:
        usage_data = {
            "timestamp": datetime.now().isoformat(),
            "endpoint": endpoint,
            "tokens": tokens_used,
            "cost_estimate": cost_estimate,
            "date": datetime.now().strftime("%Y-%m-%d")
        }
        
        # Existing logs laden
        usage_log = []
        if USAGE_LOG_FILE.exists():
            with open(USAGE_LOG_FILE, "r") as f:
                usage_log = json.load(f)
        
        usage_log.append(usage_data)
        
        # Log speichern
        with open(USAGE_LOG_FILE, "w") as f:
            json.dump(usage_log, f, indent=2)
            
        # Budget-Check
        check_monthly_budget()
        
    except Exception as e:
        logger.warning(f"⚠️ Usage-Logging fehlgeschlagen: {e}")

def check_monthly_budget():
    """Monatliches Budget prüfen"""
    try:
        if not USAGE_LOG_FILE.exists():
            return
        
        with open(USAGE_LOG_FILE, "r") as f:
            usage_log = json.load(f)
        
        current_month = datetime.now().strftime("%Y-%m")
        monthly_cost = sum(
            entry["cost_estimate"] for entry in usage_log
            if entry["timestamp"].startswith(current_month)
        )
        
        max_budget = float(os.getenv("MAX_MONTHLY_BUDGET", "20.0"))
        warn_budget = float(os.getenv("WARN_AT_BUDGET", "15.0"))
        
        if monthly_cost >= max_budget:
            logger.error(f"🚨 BUDGET ÜBERSCHRITTEN: ${monthly_cost:.2f} / ${max_budget:.2f}")
        elif monthly_cost >= warn_budget:
            logger.warning(f"⚠️ Budget-Warnung: ${monthly_cost:.2f} / ${max_budget:.2f}")
        else:
            logger.info(f"💰 Budget OK: ${monthly_cost:.2f} / ${max_budget:.2f}")
            
    except Exception as e:
        logger.warning(f"⚠️ Budget-Check fehlgeschlagen: {e}")

@app.get("/budget-status")
def get_budget_status():
    """Aktueller Budget-Status"""
    try:
        if not USAGE_LOG_FILE.exists():
            return {"monthly_cost": 0, "status": "no_usage"}
        
        with open(USAGE_LOG_FILE, "r") as f:
            usage_log = json.load(f)
        
        current_month = datetime.now().strftime("%Y-%m")
        monthly_cost = sum(
            entry["cost_estimate"] for entry in usage_log
            if entry["timestamp"].startswith(current_month)
        )
        
        max_budget = float(os.getenv("MAX_MONTHLY_BUDGET", "20.0"))
        
        return {
            "monthly_cost": round(monthly_cost, 2),
            "max_budget": max_budget,
            "remaining": round(max_budget - monthly_cost, 2),
            "usage_percent": round((monthly_cost / max_budget) * 100, 1)
        }
        
    except Exception as e:
        return {"error": str(e)}

@app.get("/")
def read_root():
    """Root Endpoint - System Status"""
    return {
        "message": "Bauplan-Checker API läuft",
        "version": "1.0.0",
        "status": "aktiv",
        "timestamp": datetime.now().isoformat()
    }


@app.get("/health")
async def health_check():
    """Health-Check Endpoint für Home Assistant"""
    try:
        # System-Informationen
        start_time = datetime.now() - timedelta(seconds=psutil.boot_time())
        
        # DIN-Normen Status prüfen
        processor = DINNormProcessor()
        processing_info = processor.get_processing_info()
        
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "uptime": str(start_time),
            "version": "1.0.0",
            "din_norms_count": processing_info.get("file_count", 0),
            "last_din_update": processing_info.get("processed_date", "unknown"),
            "system": {
                "cpu_percent": psutil.cpu_percent(),
                "memory_percent": psutil.virtual_memory().percent,
                "disk_percent": psutil.disk_usage('/').percent
            }
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }


@app.post("/upload-plan")
async def upload_plan(file: UploadFile = File(...)):
    """PDF-Plan hochladen und Basis-Analyse durchführen"""
    
    # Validierung
    if not file.filename:
        raise HTTPException(status_code=400, detail="Keine Datei ausgewählt")
    
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Nur PDF-Dateien sind erlaubt")
    
    # Dateigröße prüfen
    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="Datei zu groß (max. 50MB)")
    
    try:
        # Datei speichern
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        safe_filename = f"{timestamp}_{file.filename.replace(' ', '_')}"
        filepath = UPLOAD_DIR / safe_filename
        
        with open(filepath, "wb") as f:
            f.write(content)
        
        logger.info(f"📁 Datei gespeichert: {filepath}")
        
        # Text aus PDF extrahieren (für Metadaten)
        text_content = await extract_text_from_pdf(filepath)
        
        # Technische Zeichnung analysieren mit GPT-4 Vision
        visual_analysis = await analyze_technical_drawing(filepath)
        
        # Kombinierte Analyse
        initial_analysis = {
            "visual_analysis": visual_analysis,
            "text_metadata": await analyze_plan_basic(text_content[:2000]) if text_content else {}
        }
        
        # Ergebnis zusammenstellen
        result = {
            "id": timestamp,
            "filename": safe_filename,
            "original_filename": file.filename,
            "upload_time": timestamp,
            "file_size": len(content),
            "page_count": estimate_page_count(text_content),
            "text_preview": text_content[:500] + "..." if len(text_content) > 500 else text_content,
            "text_length": len(text_content),
            "initial_analysis": initial_analysis,
            "status": "uploaded"
        }
        
        # Ergebnis speichern
        result_file = RESULTS_DIR / f"{timestamp}_analysis.json"
        with open(result_file, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        
        logger.info(f"✅ Upload erfolgreich: {file.filename}")
        return JSONResponse(content=result)
        
    except Exception as e:
        logger.error(f"❌ Upload Fehler: {e}")
        # Aufräumen bei Fehler
        if 'filepath' in locals() and filepath.exists():
            filepath.unlink()
        raise HTTPException(status_code=500, detail=f"Upload fehlgeschlagen: {str(e)}")


async def extract_text_from_pdf(filepath: Path) -> str:
    """Text aus PDF extrahieren - erst normal, dann OCR bei Bedarf"""
    try:
        # Versuch 1: Normaler Text-Extrakt mit PyPDF2
        text = ""
        with open(filepath, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            
            for page_num, page in enumerate(pdf_reader.pages):
                try:
                    page_text = page.extract_text()
                    if page_text.strip():
                        text += f"--- Seite {page_num + 1} ---\n{page_text}\n\n"
                except Exception as e:
                    logger.warning(f"⚠️ Seite {page_num + 1} konnte nicht gelesen werden: {e}")
                    continue
        
        # Wenn Text gefunden wurde, zurückgeben
        if text.strip():
            logger.info("✅ Text erfolgreich aus PDF extrahiert (normaler Modus)")
            return text
        
        # Versuch 2: OCR für gescannte PDFs
        logger.info("📷 Kein Text gefunden - verwende OCR für gescanntes PDF...")
        text = await extract_text_with_ocr(filepath)
        
        if text.strip():
            logger.info("✅ Text erfolgreich mit OCR extrahiert")
            return text
        
        logger.warning("⚠️ Kein Text mit OCR gefunden - verwende leeren Text für reine Bildanalyse")
        return "# Gescanntes PDF - Nur visuelle Analyse verfügbar"
        
    except Exception as e:
        logger.error(f"❌ PDF-Extraktion fehlgeschlagen: {e}")
        # Für gescannte PDFs ohne Text ist das normal - trotzdem fortfahren
        if "Keine Textinhalte" in str(e) or "OCR" in str(e):
            logger.info("💡 Kein Text verfügbar - System arbeitet nur mit visueller Analyse")
            return "# Gescanntes PDF - Nur visuelle Analyse verfügbar"
        raise Exception(f"PDF-Verarbeitung fehlgeschlagen: {str(e)}")


async def extract_text_with_ocr(filepath: Path) -> str:
    """Text mit OCR aus gescanntem PDF extrahieren"""
    try:
        # PDF in Bilder konvertieren
        logger.info("🔄 Konvertiere PDF in Bilder für OCR...")
        images = convert_from_path(
            filepath,
            dpi=200,  # Gute Balance zwischen Qualität und Geschwindigkeit
            first_page=1,
            last_page=10  # Limitierung auf erste 10 Seiten für Performance
        )
        
        text = ""
        for page_num, image in enumerate(images):
            try:
                logger.info(f"🔍 OCR für Seite {page_num + 1}...")
                
                # OCR mit Tesseract (Deutsch + Englisch)
                page_text = pytesseract.image_to_string(
                    image, 
                    lang='deu+eng',  # Deutsch und Englisch
                    config='--psm 1 --oem 3'  # Automatische Seitensegmentierung
                )
                
                if page_text.strip():
                    text += f"--- Seite {page_num + 1} (OCR) ---\n{page_text}\n\n"
                    
            except Exception as e:
                logger.warning(f"⚠️ OCR für Seite {page_num + 1} fehlgeschlagen: {e}")
                continue
        
        return text
        
    except Exception as e:
        logger.error(f"❌ OCR-Verarbeitung fehlgeschlagen: {e}")
        raise Exception(f"OCR-Verarbeitung fehlgeschlagen: {str(e)}")


def estimate_page_count(text: str) -> int:
    """Schätze Seitenanzahl basierend auf Text"""
    return max(1, text.count("--- Seite"))


async def analyze_technical_drawing(filepath: Path) -> Dict:
    """Technische Zeichnung mit GPT-4 Vision analysieren"""
    if not openai.api_key:
        return {
            "error": "OpenAI API Key nicht konfiguriert",
            "status": "Bitte OPENAI_API_KEY in .env-Datei setzen"
        }
    
    try:
        # PDF in Bilder konvertieren für Vision API
        logger.info("🎨 Konvertiere PDF für visuelle Analyse...")
        images = convert_from_path(filepath, dpi=150, first_page=1, last_page=5)
        
        if not images:
            return {"error": "Keine Bilder aus PDF extrahiert"}
        
        # Erstes Bild für Analyse verwenden
        image = images[0]
        
        # Bild zu Base64 konvertieren
        img_buffer = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
        image.save(img_buffer.name, 'PNG')
        
        with open(img_buffer.name, 'rb') as img_file:
            img_base64 = base64.b64encode(img_file.read()).decode('utf-8')
        
        os.unlink(img_buffer.name)  # Temp-Datei löschen
        
        # GPT-4 Vision API für technische Analyse
        from openai import OpenAI
        client = OpenAI(api_key=openai.api_key)
        
        response = client.chat.completions.create(
            model="gpt-4-vision-preview",
            messages=[
                {
                    "role": "system",
                    "content": """Du bist ein Experte für technische Zeichnungen, CAD-Systeme und DIN-Normen im Bauwesen. 
                    Analysiere die technische Zeichnung systematisch und strukturiert. Antworte nur auf Deutsch."""
                },
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": """Analysiere diese technische Zeichnung/Bauplan detailliert:

1. **PLAN-TYP**: Identifiziere die Art der Zeichnung (Grundriss, Schnitt, Ansicht, Detail, Lageplan, etc.)

2. **TECHNISCHE ELEMENTE**: Erkenne und liste auf:
   - Wände, Türen, Fenster
   - Maße und Bemaßungen
   - Symbole und Bezeichnungen
   - Maßstab
   - Räume und deren Funktionen

3. **DIN-NORMEN-PRÜFUNG**: Prüfe gegen relevante DIN-Normen:
   - DIN 1356 (Bauzeichnungen)
   - DIN 919 (Technische Zeichnungen)
   - DIN EN ISO 5457 (Zeichnungsformate)
   - DIN 6771-1 (Bemaßung)
   - DIN EN ISO 3098 (Schrift)

4. **GEOMETRIE & MASSSTAB**: Bewerte:
   - Korrekte Bemaßung
   - Maßstabstreue
   - Geometrische Konsistenz

5. **QUALITÄTSBEWERTUNG**: 
   - Vollständigkeit der Informationen
   - Zeichnungsqualität
   - Normkonformität

6. **PROBLEME & EMPFEHLUNGEN**: Konkrete Verbesserungsvorschläge

Antworte im JSON-Format mit diesen Schlüsseln:
{
  "plan_typ": "...",
  "technische_elemente": {...},
  "din_normen_check": {...},
  "geometrie_bewertung": {...},
  "qualitaet": "gut/mittel/schlecht",
  "probleme": [...],
  "empfehlungen": [...],
  "massstab": "...",
  "vollstaendigkeit": "..."
}"""
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/png;base64,{img_base64}"
                            }
                        }
                    ]
                }
            ],
            max_tokens=2000,
            temperature=0.2
        )
        
        content = response.choices[0].message.content
        
        # JSON parsen
        try:
            analysis = json.loads(content)
            analysis["timestamp"] = datetime.now().isoformat()
            analysis["analysis_type"] = "vision_technical"
            analysis["model"] = "gpt-4-vision"
            return analysis
        except json.JSONDecodeError:
            return {
                "error": "JSON Parse Fehler",
                "raw_response": content,
                "status": "Vision API Antwort konnte nicht geparst werden"
            }
        
    except Exception as e:
        logger.error(f"❌ Vision-Analyse fehlgeschlagen: {e}")
        return {
            "error": "Vision-Analyse fehlgeschlagen",
            "details": str(e),
            "status": "Bitte API-Konfiguration und Modell-Zugang prüfen"
        }


async def analyze_plan_basic(text: str) -> Dict:
    """Text-Metadaten analysieren (Ergänzung zur visuellen Analyse)"""
    if not openai.api_key or not text.strip():
        return {
            "text_available": False,
            "note": "Keine Textinhalte oder API nicht konfiguriert"
        }
    
    try:
        from openai import OpenAI
        client = OpenAI(api_key=openai.api_key)
        
        response = client.chat.completions.create(
            model="gpt-4",
            messages=[
                {
                    "role": "system", 
                    "content": """Analysiere Textinhalte aus technischen Zeichnungen (Beschriftungen, Maße, etc.).
                    Fokus auf Metadaten und Textinformationen."""
                },
                {
                    "role": "user", 
                    "content": f"""Analysiere diese Textinhalte aus einer technischen Zeichnung:

{text}

Extrahiere:
1. "beschriftungen": Gefundene Texte und Beschriftungen
2. "masse": Erkannte Maße und Abmessungen  
3. "normen_hinweise": Verweise auf Normen oder Standards
4. "projekt_info": Projektinformationen (Titel, Datum, etc.)

JSON-Format verwenden."""
                }
            ],
            temperature=0.2,
            max_tokens=800
        )
        
        content = response.choices[0].message.content
        
        try:
            analysis = json.loads(content)
            analysis["text_available"] = True
            return analysis
        except json.JSONDecodeError:
            return {
                "text_available": True,
                "raw_text_length": len(text),
                "parse_error": "Konnte Textanalyse nicht parsen"
            }
        
    except Exception as e:
        logger.error(f"❌ Text-Analyse fehlgeschlagen: {e}")
        return {
            "text_available": True,
            "error": str(e),
            "text_length": len(text)
        }


@app.get("/plans")
async def get_plans():
    """Liste aller hochgeladenen Pläne"""
    try:
        plans = []
        
        for analysis_file in RESULTS_DIR.glob("*_analysis.json"):
            try:
                with open(analysis_file, "r", encoding="utf-8") as f:
                    plan_data = json.load(f)
                    plans.append(plan_data)
            except Exception as e:
                logger.warning(f"⚠️ Fehler beim Laden von {analysis_file}: {e}")
                continue
        
        # Nach Upload-Zeit sortieren (neueste zuerst)
        plans.sort(key=lambda x: x.get('upload_time', ''), reverse=True)
        
        return plans
        
    except Exception as e:
        logger.error(f"❌ Fehler beim Laden der Pläne: {e}")
        raise HTTPException(status_code=500, detail="Fehler beim Laden der Pläne")


@app.post("/check-against-din/{plan_id}")
async def check_against_din(plan_id: str, background_tasks: BackgroundTasks):
    """Plan gegen DIN-Normen prüfen"""
    
    analysis_file = RESULTS_DIR / f"{plan_id}_analysis.json"
    
    if not analysis_file.exists():
        raise HTTPException(status_code=404, detail="Plan nicht gefunden")
    
    try:
        # Plan-Daten laden
        with open(analysis_file, "r", encoding="utf-8") as f:
            plan_data = json.load(f)
        
        # Vollständigen Text aus Original-PDF holen
        pdf_path = UPLOAD_DIR / plan_data["filename"]
        if not pdf_path.exists():
            raise HTTPException(status_code=404, detail="Original-PDF nicht gefunden")
        
        full_text = await extract_text_from_pdf(pdf_path)
        
        # DIN-Prüfung im Hintergrund starten
        background_tasks.add_task(perform_din_check, plan_id, full_text)
        
        return {
            "message": "DIN-Prüfung gestartet",
            "plan_id": plan_id,
            "status": "in_progress"
        }
        
    except Exception as e:
        logger.error(f"❌ DIN-Prüfung Fehler: {e}")
        raise HTTPException(status_code=500, detail=f"DIN-Prüfung fehlgeschlagen: {str(e)}")


async def perform_din_check(plan_id: str, plan_text: str):
    """Technische DIN-Prüfung für Zeichnungen durchführen (Background Task)"""
    try:
        logger.info(f"🔍 Starte technische DIN-Prüfung für Plan {plan_id}")
        
        # Analyse-Datei laden um visuelle Analyse zu bekommen
        analysis_file = RESULTS_DIR / f"{plan_id}_analysis.json"
        
        with open(analysis_file, "r", encoding="utf-8") as f:
            plan_data = json.load(f)
        
        # Visuelle Analyse für DIN-Check verwenden
        visual_analysis = plan_data.get("initial_analysis", {}).get("visual_analysis", {})
        
        if visual_analysis:
            # Technische DIN-Normen-Prüfung
            technical_compliance = technical_processor.analyze_technical_compliance(visual_analysis)
            
            # Zusätzlich: Textbasierte Analyse falls vorhanden
            text_based_check = din_processor.check_against_norms(plan_text) if plan_text else {}
            
            # Kombinierte DIN-Prüfung
            combined_din_check = {
                "technical_compliance": technical_compliance,
                "text_based_analysis": text_based_check,
                "analysis_type": "comprehensive_technical",
                "timestamp": datetime.now().isoformat()
            }
        else:
            # Fallback auf reine Textanalyse
            combined_din_check = {
                "text_based_analysis": din_processor.check_against_norms(plan_text),
                "analysis_type": "text_only_fallback",
                "note": "Keine visuelle Analyse verfügbar",
                "timestamp": datetime.now().isoformat()
            }
        
        plan_data["din_check"] = combined_din_check
        plan_data["din_check_timestamp"] = datetime.now().isoformat()
        plan_data["status"] = "technical_din_checked"
        
        with open(analysis_file, "w", encoding="utf-8") as f:
            json.dump(plan_data, f, ensure_ascii=False, indent=2)
        
        logger.info(f"✅ Technische DIN-Prüfung abgeschlossen für Plan {plan_id}")
        
    except Exception as e:
        logger.error(f"❌ Background DIN-Prüfung Fehler: {e}")


@app.get("/din-check-status/{plan_id}")
async def get_din_check_status(plan_id: str):
    """Status der DIN-Prüfung abfragen"""
    analysis_file = RESULTS_DIR / f"{plan_id}_analysis.json"
    
    if not analysis_file.exists():
        raise HTTPException(status_code=404, detail="Plan nicht gefunden")
    
    with open(analysis_file, "r", encoding="utf-8") as f:
        plan_data = json.load(f)
    
    has_din_check = "din_check" in plan_data
    
    return {
        "plan_id": plan_id,
        "has_din_check": has_din_check,
        "status": plan_data.get("status", "unknown"),
        "din_check": plan_data.get("din_check") if has_din_check else None
    }


@app.post("/process-din-norms")
async def process_din_norms():
    """DIN-Normen neu einlesen und in Vektordatenbank speichern"""
    try:
        pdf_count = len(list(DIN_NORMS_DIR.glob("*.pdf")))
        
        if pdf_count == 0:
            return {
                "warning": "Keine DIN-Norm PDFs gefunden",
                "message": f"Bitte legen Sie DIN-Norm PDFs in '{DIN_NORMS_DIR}' ab",
                "count": 0
            }
        
        # DIN-Normen verarbeiten
        chunk_count = din_processor.process_din_pdfs(str(DIN_NORMS_DIR))
        
        return {
            "message": f"DIN-Normen erfolgreich verarbeitet",
            "pdf_count": pdf_count,
            "chunk_count": chunk_count,
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ DIN-Normen Verarbeitung Fehler: {e}")
        raise HTTPException(status_code=500, detail=f"DIN-Normen Verarbeitung fehlgeschlagen: {str(e)}")


@app.post("/add-feedback/{plan_id}")
async def add_feedback(plan_id: str, feedback: Dict):
    """Feedback zu einem Plan hinzufügen"""
    analysis_file = RESULTS_DIR / f"{plan_id}_analysis.json"
    
    if not analysis_file.exists():
        raise HTTPException(status_code=404, detail="Plan nicht gefunden")
    
    try:
        with open(analysis_file, "r", encoding="utf-8") as f:
            plan_data = json.load(f)
        
        # Feedback hinzufügen
        if "feedback" not in plan_data:
            plan_data["feedback"] = []
        
        feedback_entry = {
            "timestamp": datetime.now().isoformat(),
            "positive_aspects": feedback.get("positive_aspects", []),
            "negative_aspects": feedback.get("negative_aspects", []),
            "comments": feedback.get("comments", ""),
            "rating": feedback.get("rating", 0)
        }
        
        plan_data["feedback"].append(feedback_entry)
        
        # Speichern
        with open(analysis_file, "w", encoding="utf-8") as f:
            json.dump(plan_data, f, ensure_ascii=False, indent=2)
        
        # Optional: Aus Feedback lernen
        if hasattr(din_processor, 'learn_from_feedback'):
            try:
                pdf_path = UPLOAD_DIR / plan_data["filename"]
                if pdf_path.exists():
                    plan_text = await extract_text_from_pdf(pdf_path)
                    din_processor.learn_from_feedback(plan_text, feedback_entry)
            except Exception as e:
                logger.warning(f"⚠️ Feedback-Learning Fehler: {e}")
        
        return {
            "message": "Feedback erfolgreich gespeichert",
            "feedback": feedback_entry
        }
        
    except Exception as e:
        logger.error(f"❌ Feedback Fehler: {e}")
        raise HTTPException(status_code=500, detail=f"Feedback konnte nicht gespeichert werden: {str(e)}")


@app.delete("/plan/{plan_id}")
async def delete_plan(plan_id: str):
    """Plan und zugehörige Dateien löschen"""
    try:
        analysis_file = RESULTS_DIR / f"{plan_id}_analysis.json"
        
        if not analysis_file.exists():
            raise HTTPException(status_code=404, detail="Plan nicht gefunden")
        
        # Plan-Daten laden für Dateiname
        with open(analysis_file, "r", encoding="utf-8") as f:
            plan_data = json.load(f)
        
        # PDF-Datei löschen
        pdf_file = UPLOAD_DIR / plan_data["filename"]
        if pdf_file.exists():
            pdf_file.unlink()
        
        # Analyse-Datei löschen
        analysis_file.unlink()
        
        return {
            "message": "Plan erfolgreich gelöscht",
            "plan_id": plan_id
        }
        
    except Exception as e:
        logger.error(f"❌ Plan-Löschung Fehler: {e}")
        raise HTTPException(status_code=500, detail=f"Plan konnte nicht gelöscht werden: {str(e)}")


@app.get("/statistics")
async def get_statistics():
    """Statistik Endpoint für Home Assistant Dashboard"""
    try:
        # Analysierte Pläne zählen
        analysis_dir = Path("analysis_results")
        analysis_files = list(analysis_dir.glob("*.json")) if analysis_dir.exists() else []
        
        # Feedback-Statistiken
        feedback_db_path = Path("din_norms/feedback_db.json")
        feedback_stats = {"positive": 0, "negative": 0, "average_rating": 0}
        
        if feedback_db_path.exists():
            try:
                with open(feedback_db_path, "r", encoding="utf-8") as f:
                    feedback_db = json.load(f)
                    
                feedback_stats["positive"] = len(feedback_db.get("positive_examples", []))
                feedback_stats["negative"] = len(feedback_db.get("negative_examples", []))
                
                # Durchschnittsbewertung berechnen
                all_ratings = []
                for example in feedback_db.get("positive_examples", []):
                    if "rating" in example:
                        all_ratings.append(example["rating"])
                for example in feedback_db.get("negative_examples", []):
                    if "rating" in example:
                        all_ratings.append(example["rating"])
                        
                if all_ratings:
                    feedback_stats["average_rating"] = sum(all_ratings) / len(all_ratings)
                    
            except Exception as e:
                logger.error(f"Fehler beim Laden der Feedback-Statistiken: {e}")
        
        # DIN-Normen Information
        processor = DINNormProcessor()
        processing_info = processor.get_processing_info()
        
        return {
            "timestamp": datetime.now().isoformat(),
            "total_plans": len(analysis_files),
            "plans_with_din_check": len([f for f in analysis_files if "analysis" in f.name]),
            "plans_with_feedback": feedback_stats["positive"] + feedback_stats["negative"],
            "average_rating": round(feedback_stats["average_rating"], 2),
            "din_norms_count": processing_info.get("file_count", 0),
            "din_chunks_count": processing_info.get("chunk_count", 0),
            "feedback_stats": feedback_stats,
            "last_analysis": max([f.stat().st_mtime for f in analysis_files]) if analysis_files else None
        }
        
    except Exception as e:
        logger.error(f"Fehler beim Erstellen der Statistiken: {e}")
        return {
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }


@app.post("/upload-din-norm")
async def upload_din_norm(file: UploadFile = File(...)):
    """DIN-Norm PDF hochladen und verarbeiten"""
    
    # Validierung
    if not file.filename:
        raise HTTPException(status_code=400, detail="Keine Datei ausgewählt")
    
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Nur PDF-Dateien sind erlaubt")
    
    # Dateigröße prüfen
    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail="Datei zu groß (max. 50MB)")
    
    try:
        # DIN-Norm Dateiname normalisieren
        safe_filename = file.filename.replace(' ', '_').replace('(', '').replace(')', '')
        if not safe_filename.startswith('DIN'):
            safe_filename = f"DIN_{safe_filename}"
        
        filepath = DIN_NORMS_DIR / safe_filename
        
        # Datei speichern
        with open(filepath, "wb") as f:
            f.write(content)
        
        logger.info(f"📚 DIN-Norm gespeichert: {filepath}")
        
        # Sofort verarbeiten
        chunks_processed = din_processor.process_din_pdfs(str(DIN_NORMS_DIR))
        
        result = {
            "filename": safe_filename,
            "original_filename": file.filename,
            "file_size": len(content),
            "upload_time": datetime.now().isoformat(),
            "chunks_processed": chunks_processed,
            "status": "processed",
            "message": f"DIN-Norm erfolgreich hochgeladen und {chunks_processed} Textblöcke verarbeitet"
        }
        
        logger.info(f"✅ DIN-Norm Upload erfolgreich: {file.filename}")
        return JSONResponse(content=result)
        
    except Exception as e:
        logger.error(f"❌ DIN-Upload Fehler: {e}")
        # Aufräumen bei Fehler
        if 'filepath' in locals() and filepath.exists():
            filepath.unlink()
        raise HTTPException(status_code=500, detail=f"DIN-Upload fehlgeschlagen: {str(e)}")


@app.get("/din-norms")
async def get_din_norms_status():
    """DIN-Normen Status für Home Assistant"""
    try:
        processor = DINNormProcessor()
        processing_info = processor.get_processing_info()
        
        # Verfügbare DIN-Normen auflisten
        din_path = Path("din_norms")
        pdf_files = list(din_path.glob("*.pdf")) if din_path.exists() else []
        
        norms_list = []
        for pdf_file in pdf_files:
            file_stat = pdf_file.stat()
            norms_list.append({
                "name": pdf_file.stem,
                "filename": pdf_file.name,
                "size_mb": round(file_stat.st_size / (1024 * 1024), 2),
                "last_modified": datetime.fromtimestamp(file_stat.st_mtime).isoformat()
            })
        
        return {
            "status": "available" if pdf_files else "empty",
            "count": len(pdf_files),
            "total_chunks": processing_info.get("chunk_count", 0),
            "last_update": processing_info.get("processed_date", "never"),
            "norms": norms_list
        }
        
    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "count": 0
        }


@app.delete("/din-norm/{filename}")
async def delete_din_norm(filename: str):
    """DIN-Norm löschen"""
    try:
        filepath = DIN_NORMS_DIR / filename
        
        if not filepath.exists():
            raise HTTPException(status_code=404, detail="DIN-Norm nicht gefunden")
        
        filepath.unlink()
        
        # Vektordatenbank neu aufbauen
        chunks_processed = din_processor.process_din_pdfs(str(DIN_NORMS_DIR))
        
        return {
            "message": f"DIN-Norm {filename} erfolgreich gelöscht",
            "remaining_chunks": chunks_processed
        }
        
    except Exception as e:
        logger.error(f"❌ Fehler beim Löschen der DIN-Norm: {e}")
        raise HTTPException(status_code=500, detail=f"Löschen fehlgeschlagen: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    
    logger.info("🚀 Starte Bauplan-Checker Backend...")
    logger.info(f"📁 Upload-Verzeichnis: {UPLOAD_DIR.absolute()}")
    logger.info(f"📚 DIN-Normen-Verzeichnis: {DIN_NORMS_DIR.absolute()}")
    logger.info(f"📊 Ergebnis-Verzeichnis: {RESULTS_DIR.absolute()}")
    
    uvicorn.run(
        "main:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True,
        log_level="info"
    ) 