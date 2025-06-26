"""
DIN-Normen Processor
Verarbeitung und Abfrage von DIN-Normen für Bauplan-Prüfung
"""

import os
import json
import PyPDF2
from typing import List, Dict, Optional
import openai
from datetime import datetime
import logging
from pathlib import Path
from dotenv import load_dotenv

# Environment laden
load_dotenv()

# LangChain Imports
try:
    from langchain_text_splitters import RecursiveCharacterTextSplitter
    from langchain_openai import OpenAIEmbeddings
    from langchain_community.vectorstores import FAISS
    from langchain_core.documents import Document
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    logging.warning("⚠️ LangChain nicht verfügbar. Vereinfachter Modus wird verwendet.")

logger = logging.getLogger(__name__)


class DINNormProcessor:
    """Verarbeitung und Abfrage von DIN-Normen"""
    
    def __init__(self, enable_ocr=True, enable_vision=True):
        self.embeddings = None
        self.text_splitter = None
        self.vectorstore = None
        self.din_index_path = "din_norms/din_index.faiss"
        
        # Erweiterte Features
        self.enable_ocr = enable_ocr
        self.enable_vision = enable_vision
        
        if LANGCHAIN_AVAILABLE:
            self.embeddings = OpenAIEmbeddings()
            self.text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=500,  # Kleinere Chunks für bessere Verarbeitung
                chunk_overlap=100,
                length_function=len,
            )
        else:
            logger.warning("🔧 LangChain nicht verfügbar - vereinfachter Modus")
        
        # Feature-Status protokollieren
        if self.enable_ocr:
            logger.info("🔍 OCR für gescannte PDFs aktiviert")
        if self.enable_vision:
            logger.info("🖼️ GPT-4 Vision für Bildanalyse aktiviert")
    
    def process_din_pdfs(self, din_folder="din_norms", force_reprocess=False) -> int:
        """Alle DIN PDFs einlesen und in Vektordatenbank speichern (mit Token-Sparmodus)"""
        if not LANGCHAIN_AVAILABLE:
            return self._process_simple_mode(din_folder, force_reprocess)
        
        din_path = Path(din_folder)
        if not din_path.exists():
            logger.warning(f"⚠️ DIN-Normen Ordner {din_folder} nicht gefunden")
            return 0
        
        pdf_files = list(din_path.glob("*.pdf"))
        if not pdf_files:
            logger.warning(f"⚠️ Keine PDF-Dateien in {din_folder} gefunden")
            return 0
        
        # Token-Sparmodus: Prüfe ob bereits verarbeitet
        if not force_reprocess and self._is_processing_up_to_date(pdf_files, din_folder):
            logger.info("✅ DIN-Normen bereits aktuell - überspringe Verarbeitung (Token-Sparmodus)")
            return self._get_cached_chunk_count(din_folder)
        
        documents = []
        processed_files = 0
        
        logger.info(f"📚 Verarbeite {len(pdf_files)} DIN-Norm PDFs...")
        
        for pdf_file in pdf_files:
            try:
                logger.info(f"🔄 Verarbeite: {pdf_file.name}")
                
                # Text extrahieren
                text = self._extract_pdf_text(pdf_file)
                if not text.strip():
                    logger.warning(f"⚠️ Keine Textinhalte in {pdf_file.name}")
                    continue
                
                # In Chunks aufteilen
                chunks = self.text_splitter.split_text(text)
                logger.info(f"📄 {len(chunks)} Textblöcke aus {pdf_file.name}")
                
                # Dokumente erstellen mit Metadaten
                for i, chunk in enumerate(chunks):
                    if len(chunk.strip()) < 50:  # Zu kurze Chunks überspringen
                        continue
                        
                    doc = Document(
                        page_content=chunk,
                        metadata={
                            "source": pdf_file.name,
                            "din_norm": pdf_file.stem,
                            "chunk_index": i,
                            "file_path": str(pdf_file),
                            "processed_date": datetime.now().isoformat()
                        }
                    )
                    documents.append(doc)
                
                processed_files += 1
                
            except Exception as e:
                logger.error(f"❌ Fehler bei {pdf_file.name}: {e}")
                continue
        
        # Vektordatenbank erstellen mit Batch-Verarbeitung
        if documents:
            try:
                logger.info(f"🔧 Erstelle Vektordatenbank mit {len(documents)} Dokumenten...")
                
                # Batch-Verarbeitung für große Dokumentmengen
                batch_size = 50  # Kleinere Batches zur Vermeidung von Token-Limits
                total_batches = (len(documents) + batch_size - 1) // batch_size
                
                logger.info(f"📦 Verarbeite in {total_batches} Batches (je {batch_size} Dokumente)")
                
                # Erste Batch erstellen
                first_batch = documents[:batch_size]
                self.vectorstore = FAISS.from_documents(first_batch, self.embeddings)
                logger.info(f"✅ Erste Batch verarbeitet: {len(first_batch)} Dokumente")
                
                # Weitere Batches hinzufügen
                for i in range(1, total_batches):
                    start_idx = i * batch_size
                    end_idx = min((i + 1) * batch_size, len(documents))
                    batch_docs = documents[start_idx:end_idx]
                    
                    logger.info(f"🔄 Verarbeite Batch {i+1}/{total_batches}: {len(batch_docs)} Dokumente")
                    
                    # Neue FAISS-Instanz für Batch erstellen und zusammenführen
                    batch_vectorstore = FAISS.from_documents(batch_docs, self.embeddings)
                    self.vectorstore.merge_from(batch_vectorstore)
                
                # Speichern
                index_dir = Path(self.din_index_path).parent
                index_dir.mkdir(exist_ok=True)
                self.vectorstore.save_local(str(index_dir / "din_index"))
                
                logger.info(f"✅ {len(documents)} Chunks aus {processed_files} DIN-Normen verarbeitet")
                
                # Metadaten speichern
                self._save_processing_metadata(processed_files, len(documents), pdf_files)
                
            except Exception as e:
                logger.error(f"❌ Vektordatenbank-Erstellung fehlgeschlagen: {e}")
                return 0
        
        return len(documents)
    
    def _is_processing_up_to_date(self, pdf_files: List[Path], din_folder: str) -> bool:
        """Prüft, ob die DIN-Verarbeitung aktuell ist (Token-Sparmodus)"""
        try:
            metadata_path = Path(din_folder) / "processing_metadata.json"
            if not metadata_path.exists():
                return False
                
            with open(metadata_path, "r", encoding="utf-8") as f:
                metadata = json.load(f)
            
            # Prüfe Anzahl und Änderungsdaten der PDFs
            cached_files = metadata.get("processed_files", [])
            if len(cached_files) != len(pdf_files):
                logger.info(f"📊 Anzahl der PDFs geändert: {len(cached_files)} → {len(pdf_files)}")
                return False
            
            for pdf_file in pdf_files:
                file_info = next((f for f in cached_files if f["filename"] == pdf_file.name), None)
                if not file_info:
                    logger.info(f"📄 Neue Datei gefunden: {pdf_file.name}")
                    return False
                    
                current_mtime = pdf_file.stat().st_mtime
                cached_mtime = file_info.get("last_modified", 0)
                if abs(current_mtime - cached_mtime) > 1:  # 1 Sekunde Toleranz
                    logger.info(f"📄 {pdf_file.name} wurde geändert - Neuverarbeitung erforderlich")
                    return False
            
            # Prüfe ob Datenbank existiert
            if LANGCHAIN_AVAILABLE:
                index_path = Path(din_folder) / "din_index" / "index.faiss"
                return index_path.exists()
            else:
                simple_db_path = Path(din_folder) / "simple_din_db.json"
                return simple_db_path.exists()
                
        except Exception as e:
            logger.warning(f"⚠️ Cache-Prüfung fehlgeschlagen: {e}")
            return False
    
    def _get_cached_chunk_count(self, din_folder: str) -> int:
        """Gibt die Anzahl der Chunks aus Cache zurück"""
        try:
            metadata_path = Path(din_folder) / "processing_metadata.json"
            if metadata_path.exists():
                with open(metadata_path, "r", encoding="utf-8") as f:
                    metadata = json.load(f)
                return metadata.get("total_chunks", 0)
            else:
                # Fallback: Zähle aus Simple-DB
                simple_db_path = Path(din_folder) / "simple_din_db.json"
                if simple_db_path.exists():
                    with open(simple_db_path, "r", encoding="utf-8") as f:
                        simple_db = json.load(f)
                    return len(simple_db)
        except Exception as e:
            logger.warning(f"⚠️ Chunk-Count aus Cache fehlgeschlagen: {e}")
        return 0

    def _process_simple_mode(self, din_folder: str, force_reprocess=False) -> int:
        """Vereinfachte Verarbeitung ohne LangChain"""
        din_path = Path(din_folder)
        if not din_path.exists():
            return 0
        
        pdf_files = list(din_path.glob("*.pdf"))
        simple_db = {}
        
        for pdf_file in pdf_files:
            try:
                text = self._extract_pdf_text(pdf_file)
                if text.strip():
                    simple_db[pdf_file.stem] = {
                        "content": text[:5000],  # Erste 5000 Zeichen
                        "file": pdf_file.name,
                        "processed": datetime.now().isoformat()
                    }
            except Exception as e:
                logger.error(f"❌ Fehler bei {pdf_file.name}: {e}")
        
        # Einfache Datenbank speichern
        simple_db_path = Path(din_folder) / "simple_din_db.json"
        with open(simple_db_path, "w", encoding="utf-8") as f:
            json.dump(simple_db, f, ensure_ascii=False, indent=2)
        
        logger.info(f"✅ {len(simple_db)} DIN-Normen im vereinfachten Modus verarbeitet")
        return len(simple_db)
    
    def _extract_pdf_text(self, filepath: Path) -> str:
        """Erweiterte Text- und Bildextraktion aus PDF"""
        text = ""
        
        # Erste Methode: Standard PDF Text-Extraktion
        logger.info(f"📄 Versuche Standard-Textextraktion: {filepath.name}")
        try:
            with open(filepath, 'rb') as file:
                pdf_reader = PyPDF2.PdfReader(file)
                
                for page_num, page in enumerate(pdf_reader.pages):
                    try:
                        page_text = page.extract_text()
                        if page_text.strip():
                            text += f"[Seite {page_num + 1}]\n{page_text}\n\n"
                    except Exception as e:
                        logger.warning(f"⚠️ Seite {page_num + 1} in {filepath.name}: {e}")
                        continue
                        
        except Exception as e:
            logger.error(f"❌ PDF-Extraktion {filepath.name}: {e}")
        
        # Zweite Methode: OCR für gescannte PDFs oder wenn wenig Text gefunden
        if self.enable_ocr and len(text.strip()) < 500:  # Weniger als 500 Zeichen = wahrscheinlich gescannt
            logger.info(f"🔍 Wenig Text gefunden ({len(text)} Zeichen), starte OCR-Verarbeitung...")
            ocr_text = self._extract_with_ocr(filepath)
            if ocr_text:
                text += f"\n\n[OCR-EXTRAKTION]\n{ocr_text}"
        
        # Dritte Methode: Bildanalyse für Diagramme und technische Zeichnungen
        if self.enable_vision and self._should_analyze_images(filepath):
            logger.info(f"🖼️ Starte Bildanalyse für: {filepath.name}")
            image_analysis = self._analyze_pdf_images(filepath)
            if image_analysis:
                text += f"\n\n[BILDANALYSE]\n{image_analysis}"
        
        return text
    
    def _extract_with_ocr(self, filepath: Path) -> str:
        """OCR-basierte Textextraktion für gescannte PDFs"""
        try:
            import pytesseract
            from pdf2image import convert_from_path
            
            logger.info(f"🔄 Konvertiere PDF zu Bildern: {filepath.name}")
            
            # PDF zu Bildern konvertieren
            pages = convert_from_path(filepath, dpi=200, first_page=1, last_page=10)  # Erste 10 Seiten
            
            ocr_text = ""
            for page_num, page in enumerate(pages, 1):
                try:
                    logger.info(f"📖 OCR Seite {page_num}/{len(pages)}")
                    
                    # OCR mit Deutsch und Englisch
                    page_text = pytesseract.image_to_string(
                        page, 
                        lang='deu+eng',
                        config='--psm 6 --oem 3'  # Page segmentation mode 6, OCR engine mode 3
                    )
                    
                    if page_text.strip():
                        ocr_text += f"[OCR Seite {page_num}]\n{page_text.strip()}\n\n"
                        
                except Exception as e:
                    logger.warning(f"⚠️ OCR Fehler Seite {page_num}: {e}")
                    continue
            
            logger.info(f"✅ OCR abgeschlossen: {len(ocr_text)} Zeichen extrahiert")
            return ocr_text
            
        except Exception as e:
            logger.error(f"❌ OCR-Verarbeitung fehlgeschlagen: {e}")
            return ""
    
    def _should_analyze_images(self, filepath: Path) -> bool:
        """Prüft, ob Bildanalyse für diese PDF sinnvoll ist"""
        # Bildanalyse für technische Normen aktivieren
        filename_lower = filepath.name.lower()
        
        # Technische Normen die oft Diagramme enthalten
        technical_keywords = [
            'din', 'ril', 'ztv', 'technical', 'engineering', 
            'bau', 'construction', 'standard', 'norm'
        ]
        
        return any(keyword in filename_lower for keyword in technical_keywords)
    
    def _analyze_pdf_images(self, filepath: Path) -> str:
        """Analysiert Bilder/Diagramme in PDFs mit GPT-4 Vision"""
        try:
            from pdf2image import convert_from_path
            import base64
            import io
            
            logger.info(f"🖼️ Konvertiere PDF für Bildanalyse: {filepath.name}")
            
            # Nur erste 5 Seiten für Bildanalyse (Kosten sparen)
            pages = convert_from_path(filepath, dpi=150, first_page=1, last_page=5)
            
            image_analyses = []
            
            for page_num, page in enumerate(pages, 1):
                try:
                    # Bild komprimieren für API
                    img_buffer = io.BytesIO()
                    page.save(img_buffer, format='JPEG', quality=70)
                    img_base64 = base64.b64encode(img_buffer.getvalue()).decode()
                    
                    # GPT-4 Vision API
                    analysis = self._analyze_image_with_gpt4_vision(img_base64, page_num, filepath.name)
                    
                    if analysis:
                        image_analyses.append(f"[Seite {page_num} Bildanalyse]\n{analysis}")
                        
                    # Pause zwischen API-Aufrufen
                    import time
                    time.sleep(1)
                        
                except Exception as e:
                    logger.warning(f"⚠️ Bildanalyse Seite {page_num} fehlgeschlagen: {e}")
                    continue
            
            return "\n\n".join(image_analyses) if image_analyses else ""
            
        except Exception as e:
            logger.error(f"❌ Bildanalyse fehlgeschlagen: {e}")
            return ""
    
    def _analyze_image_with_gpt4_vision(self, image_base64: str, page_num: int, filename: str) -> str:
        """Analysiert ein Bild mit GPT-4 Vision"""
        try:
            if not openai.api_key:
                return ""
            
            client = openai.OpenAI()
            
            response = client.chat.completions.create(
                model="gpt-4o",  # Aktuelles Vision-Model
                messages=[
                    {
                        "role": "system",
                        "content": """Du bist ein Experte für technische Dokumentation und DIN-Normen. 
                        Analysiere das Bild und extrahiere alle technischen Informationen, die für die 
                        Bauplan-Prüfung relevant sind. Fokussiere dich auf:
                        - Technische Diagramme und Zeichnungen
                        - Tabellen mit Grenzwerten und Spezifikationen  
                        - Maße, Toleranzen und technische Parameter
                        - Symbole und Legenden
                        - Konstruktionsdetails und Anweisungen
                        Antworte auf Deutsch."""
                    },
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": f"Analysiere diese Seite {page_num} aus der DIN-Norm '{filename}'. Extrahiere alle technischen Informationen, die für Bauplan-Prüfungen relevant sind. Beschreibe Diagramme, Tabellen, Maße und technische Details."
                            },
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{image_base64}",
                                    "detail": "high"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=800,
                temperature=0.2
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            logger.warning(f"⚠️ GPT-4 Vision Analyse fehlgeschlagen: {e}")
            return ""
    
    def _save_processing_metadata(self, file_count: int, chunk_count: int, files: List[Path]):
        """Metadaten der Verarbeitung speichern (für Token-Sparmodus)"""
        try:
            # Detaillierte Datei-Informationen für Cache-Prüfung
            processed_files = []
            for f in files:
                file_stat = f.stat()
                processed_files.append({
                    "filename": f.name,
                    "last_modified": file_stat.st_mtime,
                    "size": file_stat.st_size,
                    "path": str(f)
                })
            
            metadata = {
                "processed_date": datetime.now().isoformat(),
                "file_count": file_count,
                "total_chunks": chunk_count,  # Für _get_cached_chunk_count()
                "chunk_count": chunk_count,   # Legacy für Kompatibilität
                "processed_files": processed_files,  # Für Cache-Prüfung
                "files": [f.name for f in files],    # Legacy für Kompatibilität
                "langchain_available": LANGCHAIN_AVAILABLE,
                "cache_version": "1.0"
            }
            
            metadata_path = Path("din_norms") / "processing_metadata.json"
            with open(metadata_path, "w", encoding="utf-8") as f:
                json.dump(metadata, f, ensure_ascii=False, indent=2)
                
            logger.info(f"💾 Cache-Metadaten gespeichert: {file_count} Dateien, {chunk_count} Chunks")
            
        except Exception as e:
            logger.error(f"❌ Metadaten-Speicherung fehlgeschlagen: {e}")
    
    def load_vectorstore(self) -> bool:
        """Gespeicherte Vektordatenbank laden"""
        if not LANGCHAIN_AVAILABLE:
            return self._load_simple_db()
        
        index_path = Path("din_norms/din_index")
        if index_path.exists():
            try:
                self.vectorstore = FAISS.load_local(
                    str(index_path),
                    self.embeddings,
                    allow_dangerous_deserialization=True
                )
                logger.info("✅ Vektordatenbank geladen")
                return True
            except Exception as e:
                logger.error(f"❌ Fehler beim Laden der Vektordatenbank: {e}")
                return False
        
        logger.warning("⚠️ Keine Vektordatenbank gefunden")
        return False
    
    def _load_simple_db(self) -> bool:
        """Einfache Datenbank laden"""
        simple_db_path = Path("din_norms/simple_din_db.json")
        if simple_db_path.exists():
            try:
                with open(simple_db_path, "r", encoding="utf-8") as f:
                    self.simple_db = json.load(f)
                logger.info(f"✅ Vereinfachte DIN-DB geladen ({len(self.simple_db)} Normen)")
                return True
            except Exception as e:
                logger.error(f"❌ Fehler beim Laden der vereinfachten DB: {e}")
        return False
    
    def find_relevant_norms(self, query: str, k: int = 5) -> List[Dict]:
        """Relevante DIN-Norm Abschnitte finden"""
        if not LANGCHAIN_AVAILABLE:
            return self._find_relevant_simple(query, k)
        
        if not self.vectorstore:
            if not self.load_vectorstore():
                return []
        
        try:
            # Ähnliche Dokumente finden
            docs = self.vectorstore.similarity_search(query, k=k)
            
            # Formatieren
            results = []
            for doc in docs:
                results.append({
                    "content": doc.page_content[:1000],  # Erste 1000 Zeichen
                    "din_norm": doc.metadata.get("din_norm", "Unbekannt"),
                    "source": doc.metadata.get("source", ""),
                    "chunk_index": doc.metadata.get("chunk_index", 0)
                })
            
            return results
            
        except Exception as e:
            logger.error(f"❌ Suche fehlgeschlagen: {e}")
            return []
    
    def _find_relevant_simple(self, query: str, k: int) -> List[Dict]:
        """Vereinfachte Suche ohne Vektor-DB"""
        if not hasattr(self, 'simple_db'):
            self._load_simple_db()
        
        if not hasattr(self, 'simple_db'):
            return []
        
        # Einfache Keyword-Suche
        query_words = query.lower().split()
        results = []
        
        for din_norm, data in self.simple_db.items():
            content_lower = data["content"].lower()
            score = sum(1 for word in query_words if word in content_lower)
            
            if score > 0:
                results.append({
                    "content": data["content"][:1000],
                    "din_norm": din_norm,
                    "source": data["file"],
                    "score": score
                })
        
        # Nach Score sortieren
        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:k]
    
    def check_against_norms(self, plan_text: str) -> Dict:
        """Plan gegen DIN-Normen prüfen"""
        try:
            # Relevante Normen finden
            relevant_norms = self.find_relevant_norms(plan_text[:2000], k=8)
            
            if not relevant_norms:
                return {
                    "error": "Keine relevanten DIN-Normen gefunden",
                    "suggestion": "Bitte prüfen Sie, ob DIN-Normen verarbeitet wurden",
                    "timestamp": datetime.now().isoformat()
                }
            
            # Kontext für GPT vorbereiten
            norm_context = "\n\n".join([
                f"DIN {norm['din_norm']}:\n{norm['content'][:800]}"
                for norm in relevant_norms[:5]  # Top 5 Normen
            ])
            
            # GPT-Analyse durchführen
            analysis = self._perform_gpt_analysis(plan_text, norm_context, relevant_norms)
            
            return analysis
            
        except Exception as e:
            logger.error(f"❌ DIN-Prüfung fehlgeschlagen: {e}")
            return {
                "error": f"DIN-Prüfung fehlgeschlagen: {str(e)}",
                "timestamp": datetime.now().isoformat()
            }
    
    def _load_system_prompt(self) -> str:
        """Lädt den System-Prompt aus der Datei"""
        try:
            prompt_path = Path("system_prompts/din_analysis_prompt.md")
            if prompt_path.exists():
                with open(prompt_path, "r", encoding="utf-8") as f:
                    return f.read()
            else:
                return """Du bist ein Experte für DIN-Normen im Bauwesen. 
                        Prüfe den gegebenen Bauplan gegen die relevanten DIN-Normen und gib eine detaillierte Analyse.
                        Antworte ausschließlich auf Deutsch und nur im JSON-Format."""
        except Exception as e:
            logger.warning(f"⚠️ System-Prompt konnte nicht geladen werden: {e}")
            return "Du bist ein Experte für DIN-Normen im Bauwesen."
    
    def _load_feedback_context(self) -> str:
        """Lädt ALLE Feedback-Kontexte für bessere Analysen"""
        try:
            feedback_db_path = Path("din_norms/feedback_db.json")
            if not feedback_db_path.exists():
                return ""
            
            with open(feedback_db_path, "r", encoding="utf-8") as f:
                feedback_db = json.load(f)
            
            context_parts = []
            
            # ALLE positiven Beispiele als Best Practices
            if feedback_db.get("positive_examples"):
                positive_examples = feedback_db["positive_examples"]  # ALLE statt nur letzte 3
                context_parts.append("\n=== BEST PRACTICES (aus ALLEM positivem Feedback) ===")
                
                # Sammle alle positiven Aspekte
                all_positive_aspects = []
                for example in positive_examples:
                    if example.get("positive_aspects"):
                        all_positive_aspects.extend(example['positive_aspects'])
                
                # Entferne Duplikate und sortiere
                unique_positive = list(set(all_positive_aspects))
                for aspect in unique_positive:
                    context_parts.append(f"✅ Bewährte Praxis: {aspect}")
                
                # Zusätzlich: Häufigkeitsanalyse
                from collections import Counter
                aspect_frequency = Counter(all_positive_aspects)
                most_common = aspect_frequency.most_common(5)
                if most_common:
                    context_parts.append("\n🏆 MEIST GELOBTE ASPEKTE:")
                    for aspect, count in most_common:
                        context_parts.append(f"   • {aspect} (erwähnt {count}x)")
            
            # ALLE negativen Beispiele als Warnungen
            if feedback_db.get("negative_examples"):
                negative_examples = feedback_db["negative_examples"]  # ALLE statt nur letzte 3
                context_parts.append("\n=== HÄUFIGE FEHLER (aus ALLEM negativem Feedback) ===")
                
                # Sammle alle negativen Aspekte
                all_negative_aspects = []
                for example in negative_examples:
                    if example.get("negative_aspects"):
                        all_negative_aspects.extend(example['negative_aspects'])
                
                # Entferne Duplikate
                unique_negative = list(set(all_negative_aspects))
                for aspect in unique_negative:
                    context_parts.append(f"❌ Zu vermeiden: {aspect}")
                
                # Häufigkeitsanalyse für kritische Probleme
                from collections import Counter
                problem_frequency = Counter(all_negative_aspects)
                most_common_problems = problem_frequency.most_common(5)
                if most_common_problems:
                    context_parts.append("\n🚨 HÄUFIGSTE KRITIKPUNKTE:")
                    for problem, count in most_common_problems:
                        context_parts.append(f"   • {problem} (kritisiert {count}x)")
            
            # Statistiken hinzufügen
            total_positive = len(feedback_db.get("positive_examples", []))
            total_negative = len(feedback_db.get("negative_examples", []))
            if total_positive > 0 or total_negative > 0:
                context_parts.append(f"\n📊 FEEDBACK-STATISTIK: {total_positive} positive, {total_negative} negative Bewertungen")
            
            return "\n".join(context_parts) if context_parts else ""
            
        except Exception as e:
            logger.warning(f"⚠️ Feedback-Kontext konnte nicht geladen werden: {e}")
            return ""

    def _perform_gpt_analysis(self, plan_text: str, norm_context: str, relevant_norms: List[Dict]) -> Dict:
        """GPT-Analyse mit DIN-Normen Kontext und Lernfähigkeit"""
        if not openai.api_key:
            return {
                "error": "OpenAI API Key nicht konfiguriert",
                "relevant_norms": [norm["din_norm"] for norm in relevant_norms[:3]]
            }
        
        try:
            client = openai.OpenAI()
            
            # System-Prompt und Feedback-Kontext laden
            system_prompt = self._load_system_prompt()
            feedback_context = self._load_feedback_context()
            
            # Erweiterte Prompt mit Lernkontext
            user_prompt = f"""
Prüfe diesen Bauplan-Auszug gegen die DIN-Normen:

BAUPLAN:
{plan_text[:3000]}

RELEVANTE DIN-NORMEN:
{norm_context}

{feedback_context}

Gib eine strukturierte JSON-Analyse mit:
1. "erfuellte_anforderungen": Liste der erfüllten DIN-Anforderungen
2. "moegliche_verstoesse": Liste möglicher Verstöße oder Probleme
3. "empfehlungen": Konkrete Empfehlungen zur Verbesserung
4. "kritische_punkte": Besonders wichtige Punkte die geprüft werden sollten
5. "anwendbare_normen": Liste der relevanten DIN-Normen mit Referenzen
6. "gesamtbewertung": "gut", "akzeptabel", "problematisch"

Berücksichtige die oben genannten Best Practices und vermeide häufige Fehler.
Nur JSON-Format, keine anderen Texte.
            """
            
            response = client.chat.completions.create(
                model="gpt-4",
                messages=[
                    {
                        "role": "system",
                        "content": system_prompt
                    },
                    {
                        "role": "user",
                        "content": user_prompt
                    }
                ],
                temperature=0.2,
                max_tokens=2000
            )
            
            content = response.choices[0].message.content
            
            try:
                analysis = json.loads(content)
                
                # Metadaten hinzufügen
                analysis.update({
                    "timestamp": datetime.now().isoformat(),
                    "gpt_model": "gpt-4",
                    "normen_gefunden": len(relevant_norms),
                    "top_normen": [norm["din_norm"] for norm in relevant_norms[:3]]
                })
                
                return analysis
                
            except json.JSONDecodeError:
                logger.warning("⚠️ GPT Antwort konnte nicht als JSON geparst werden")
                return {
                    "error": "JSON Parse Fehler",
                    "raw_response": content[:500],
                    "relevant_norms": [norm["din_norm"] for norm in relevant_norms[:3]]
                }
                
        except Exception as e:
            logger.error(f"❌ GPT-Analyse fehlgeschlagen: {e}")
            return {
                "error": f"GPT-Analyse fehlgeschlagen: {str(e)}",
                "relevant_norms": [norm["din_norm"] for norm in relevant_norms[:3]]
            }
    
    def learn_from_feedback(self, plan_text: str, feedback: Dict):
        """Aus Feedback lernen (experimentell)"""
        try:
            # Feedback-Datenbank erstellen/erweitern
            feedback_db_path = Path("din_norms/feedback_db.json")
            
            # Bestehende Datenbank laden
            if feedback_db_path.exists():
                with open(feedback_db_path, "r", encoding="utf-8") as f:
                    feedback_db = json.load(f)
            else:
                feedback_db = {"positive_examples": [], "negative_examples": []}
            
            # Feedback kategorisieren
            rating = feedback.get("rating", 3)
            
            if rating >= 4:  # Positive Beispiele
                example = {
                    "plan_excerpt": plan_text[:1000],
                    "positive_aspects": feedback.get("positive_aspects", []),
                    "rating": rating,
                    "timestamp": feedback.get("timestamp", datetime.now().isoformat())
                }
                feedback_db["positive_examples"].append(example)
                
            elif rating <= 2:  # Negative Beispiele
                example = {
                    "plan_excerpt": plan_text[:1000],
                    "negative_aspects": feedback.get("negative_aspects", []),
                    "rating": rating,
                    "timestamp": feedback.get("timestamp", datetime.now().isoformat())
                }
                feedback_db["negative_examples"].append(example)
            
            # Speichern
            with open(feedback_db_path, "w", encoding="utf-8") as f:
                json.dump(feedback_db, f, ensure_ascii=False, indent=2)
            
            logger.info(f"✅ Feedback gespeichert (Rating: {rating})")
            
        except Exception as e:
            logger.error(f"❌ Feedback-Learning Fehler: {e}")
    
    def get_processing_info(self) -> Dict:
        """Informationen über die DIN-Normen Verarbeitung"""
        try:
            metadata_path = Path("din_norms/processing_metadata.json")
            if metadata_path.exists():
                with open(metadata_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            else:
                return {"status": "Keine Verarbeitungsmetadaten gefunden"}
        except Exception as e:
            return {"error": f"Fehler beim Laden der Metadaten: {e}"}


# Initialisierungs-Skript
if __name__ == "__main__":
    print("🔧 DIN-Normen Processor Test")
    
    processor = DINNormProcessor()
    
    # Prüfen ob DIN PDFs vorhanden sind
    din_folder = "din_norms"
    din_path = Path(din_folder)
    
    if not din_path.exists():
        din_path.mkdir(exist_ok=True)
        print(f"📁 Ordner '{din_folder}' erstellt")
    
    pdf_files = list(din_path.glob("*.pdf"))
    pdf_count = len(pdf_files)
    
    if pdf_count == 0:
        print(f"⚠️  Keine DIN-Norm PDFs in '{din_folder}' gefunden!")
        print("📋 Bitte legen Sie DIN-Norm PDFs in diesen Ordner:")
        print("   Beispiel: DIN_1045-2_Beton.pdf")
        print("   Beispiel: DIN_1052_Holzbau.pdf")
        print("   Beispiel: DIN_18065_Treppen.pdf")
    else:
        print(f"📚 Gefunden: {pdf_count} DIN-Norm PDFs")
        for pdf_file in pdf_files:
            print(f"   - {pdf_file.name}")
        
        print("\n🚀 Starte Verarbeitung...")
        chunk_count = processor.process_din_pdfs(din_folder)
        
        if chunk_count > 0:
            print(f"✅ Verarbeitung abgeschlossen: {chunk_count} Textblöcke")
            
            # Test-Suche
            print("\n🔍 Test-Suche...")
            test_results = processor.find_relevant_norms("Beton Stahlbeton", k=3)
            print(f"📋 {len(test_results)} relevante Abschnitte gefunden")
            
        else:
            print("❌ Verarbeitung fehlgeschlagen")
    
    print("\n" + "="*50)
    print("🎯 Setup abgeschlossen!")
    print("💡 Tipp: Starten Sie nun das Backend mit 'python main.py'") 