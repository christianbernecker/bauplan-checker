"""
Technische Zeichnungen Processor
Spezialisiert auf CAD-Zeichnungen, Baupläne und DIN-Normen für technische Zeichnungen
"""

import json
import logging
from typing import Dict, List, Optional
from pathlib import Path
import openai
from datetime import datetime

# Logging
logger = logging.getLogger(__name__)

class TechnicalDrawingProcessor:
    """Processor für technische Zeichnungen und CAD-spezifische DIN-Normen"""
    
    def __init__(self):
        self.technical_din_standards = {
            "DIN_1356": {
                "title": "Bauzeichnungen - Arten, Inhalte und Grundregeln der Darstellung",
                "scope": "Grundregeln für Bauzeichnungen",
                "key_points": [
                    "Zeichnungsarten und deren Anwendung",
                    "Maßstäbe für verschiedene Plantypen",
                    "Darstellungsregeln für Bauteile",
                    "Bezeichnungen und Beschriftungen"
                ]
            },
            "DIN_919": {
                "title": "Technische Zeichnungen - Allgemeine Grundlagen",
                "scope": "Grundlagen technischer Zeichnungen",
                "key_points": [
                    "Linienarten und -breiten",
                    "Zeichnungsaufbau und -gliederung",
                    "Koordinatensysteme",
                    "Projektionsmethoden"
                ]
            },
            "DIN_EN_ISO_5457": {
                "title": "Zeichnungsblätter - Größen und Aufbau",
                "scope": "Formate und Layout technischer Zeichnungen",
                "key_points": [
                    "Standardformate (A0, A1, A2, A3, A4)",
                    "Schriftfeld und Zeichnungsrahmen",
                    "Faltung von Zeichnungen",
                    "Koordinatensystem der Zeichnungsblätter"
                ]
            },
            "DIN_6771_1": {
                "title": "Bemaßung - Grundlagen, Begriffe, Allgemeine Anforderungen",
                "scope": "Bemaßungsregeln für technische Zeichnungen",
                "key_points": [
                    "Bemaßungslinien und Maßhilfslinien",
                    "Maßzahlen und deren Anordnung",
                    "Bemaßung von Kreisen und Bögen",
                    "Toleranzen und Passungen"
                ]
            },
            "DIN_EN_ISO_3098": {
                "title": "Schriften - Grundregeln für die Anwendung",
                "scope": "Schriftarten und -größen in technischen Zeichnungen",
                "key_points": [
                    "Normschrift Typ A und B",
                    "Schriftgrößen und -neigungen",
                    "Ziffern und Sonderzeichen",
                    "Schreibregeln und Abstände"
                ]
            },
            "DIN_406": {
                "title": "Maßeintragung - Grundlagen, Begriffe, Darstellung",
                "scope": "Maßeintragung in technischen Zeichnungen",
                "key_points": [
                    "Maßketten und Bezugsmaße",
                    "Koordinatenmaße",
                    "Durchmesser- und Radiusmaße",
                    "Winkelmaße"
                ]
            }
        }
        
        self.common_technical_elements = {
            "architectural": {
                "walls": ["Wand", "Außenwand", "Innenwand", "Trennwand"],
                "openings": ["Tür", "Fenster", "Tor", "Öffnung"],
                "structures": ["Stütze", "Träger", "Decke", "Fundament"],
                "rooms": ["Raum", "Zimmer", "Büro", "Flur", "Bad", "Küche"]
            },
            "dimensions": {
                "linear": ["mm", "cm", "m", "Länge", "Breite", "Höhe"],
                "angular": ["°", "Grad", "Winkel", "Neigung"],
                "areas": ["m²", "qm", "Fläche", "Grundfläche"]
            },
            "symbols": {
                "doors": ["Türsymbol", "Drehtür", "Schiebetür"],
                "windows": ["Fenstersymbol", "Fensterdarstellung"],
                "utilities": ["Steckdose", "Schalter", "Leitung"]
            }
        }
    
    def analyze_technical_compliance(self, visual_analysis: Dict) -> Dict:
        """Analysiere DIN-Normen-Konformität für technische Zeichnungen"""
        
        try:
            compliance_check = {
                "overall_compliance": "unknown",
                "din_checks": {},
                "recommendations": [],
                "critical_issues": [],
                "score": 0
            }
            
            # DIN 1356 - Bauzeichnungen prüfen
            if visual_analysis.get("plan_typ"):
                din_1356_check = self._check_din_1356(visual_analysis)
                compliance_check["din_checks"]["DIN_1356"] = din_1356_check
            
            # DIN 6771-1 - Bemaßung prüfen  
            if visual_analysis.get("technische_elemente", {}).get("bemassungen"):
                din_6771_check = self._check_din_6771_dimensioning(visual_analysis)
                compliance_check["din_checks"]["DIN_6771_1"] = din_6771_check
            
            # DIN EN ISO 5457 - Format prüfen
            format_check = self._check_din_iso_5457_format(visual_analysis)
            compliance_check["din_checks"]["DIN_EN_ISO_5457"] = format_check
            
            # Gesamtbewertung berechnen
            compliance_check = self._calculate_overall_compliance(compliance_check)
            
            return compliance_check
            
        except Exception as e:
            logger.error(f"❌ Technische Compliance-Prüfung fehlgeschlagen: {e}")
            return {
                "error": "Compliance-Prüfung fehlgeschlagen",
                "details": str(e)
            }
    
    def _check_din_1356(self, analysis: Dict) -> Dict:
        """Prüfe DIN 1356 - Bauzeichnungen"""
        
        check_result = {
            "standard": "DIN 1356",
            "compliance": "unknown",
            "issues": [],
            "recommendations": [],
            "score": 0
        }
        
        plan_typ = analysis.get("plan_typ", "").lower()
        elements = analysis.get("technische_elemente", {})
        
        # Plantyp-spezifische Prüfungen
        if "grundriss" in plan_typ:
            if not elements.get("waende"):
                check_result["issues"].append("Wände nicht erkennbar in Grundriss")
            if not elements.get("tueren"):
                check_result["issues"].append("Türen fehlen oder nicht erkennbar")
            if elements.get("raeume"):
                check_result["score"] += 20
            else:
                check_result["recommendations"].append("Räume sollten benannt werden")
        
        elif "schnitt" in plan_typ:
            if not elements.get("hoehen"):
                check_result["issues"].append("Höhenangaben fehlen in Schnittdarstellung")
            check_result["score"] += 15
        
        # Maßstab prüfen
        massstab = analysis.get("massstab", "")
        if massstab:
            check_result["score"] += 15
            if not any(scale in massstab.lower() for scale in ["1:", "m", "scale"]):
                check_result["issues"].append("Maßstab unklar oder nicht normgerecht")
        else:
            check_result["issues"].append("Maßstab fehlt")
        
        # Bewertung
        if check_result["score"] >= 40:
            check_result["compliance"] = "gut"
        elif check_result["score"] >= 20:
            check_result["compliance"] = "mittel"
        else:
            check_result["compliance"] = "mangelhaft"
        
        return check_result
    
    def _check_din_6771_dimensioning(self, analysis: Dict) -> Dict:
        """Prüfe DIN 6771-1 - Bemaßung"""
        
        check_result = {
            "standard": "DIN 6771-1",
            "compliance": "unknown", 
            "issues": [],
            "recommendations": [],
            "score": 0
        }
        
        elements = analysis.get("technische_elemente", {})
        geometrie = analysis.get("geometrie_bewertung", {})
        
        # Bemaßung vorhanden?
        if elements.get("bemassungen") or elements.get("masse"):
            check_result["score"] += 25
            
            # Vollständigkeit der Bemaßung
            if geometrie.get("bemassungs_vollstaendigkeit") == "vollstaendig":
                check_result["score"] += 25
            elif geometrie.get("bemassungs_vollstaendigkeit") == "teilweise":
                check_result["score"] += 10
                check_result["recommendations"].append("Bemaßung vervollständigen")
            
            # Bemaßungsrichtigkeit
            if geometrie.get("bemassungs_korrektheit") == "korrekt":
                check_result["score"] += 20
            else:
                check_result["issues"].append("Bemaßung möglicherweise fehlerhaft")
        else:
            check_result["issues"].append("Keine Bemaßung erkennbar")
            check_result["recommendations"].append("Vollständige Bemaßung nach DIN 6771-1 hinzufügen")
        
        # Einheiten prüfen
        if elements.get("einheiten"):
            check_result["score"] += 10
        else:
            check_result["recommendations"].append("Maßeinheiten angeben")
        
        # Bewertung
        if check_result["score"] >= 50:
            check_result["compliance"] = "gut"
        elif check_result["score"] >= 25:
            check_result["compliance"] = "mittel"
        else:
            check_result["compliance"] = "mangelhaft"
        
        return check_result
    
    def _check_din_iso_5457_format(self, analysis: Dict) -> Dict:
        """Prüfe DIN EN ISO 5457 - Zeichnungsformat"""
        
        check_result = {
            "standard": "DIN EN ISO 5457",
            "compliance": "unknown",
            "issues": [],
            "recommendations": [],
            "score": 0
        }
        
        elements = analysis.get("technische_elemente", {})
        
        # Schriftfeld vorhanden?
        if elements.get("schriftfeld") or elements.get("titel_block"):
            check_result["score"] += 30
        else:
            check_result["issues"].append("Schriftfeld fehlt")
            check_result["recommendations"].append("Standardisiertes Schriftfeld nach DIN EN ISO 5457 hinzufügen")
        
        # Zeichnungsrahmen
        if elements.get("rahmen") or elements.get("border"):
            check_result["score"] += 20
        else:
            check_result["recommendations"].append("Zeichnungsrahmen hinzufügen")
        
        # Format erkennbar
        if elements.get("format") or analysis.get("format"):
            check_result["score"] += 15
            format_info = elements.get("format", analysis.get("format", ""))
            if any(f in format_info.upper() for f in ["A0", "A1", "A2", "A3", "A4"]):
                check_result["score"] += 15
        else:
            check_result["recommendations"].append("Standardformat verwenden (A0-A4)")
        
        # Bewertung
        if check_result["score"] >= 50:
            check_result["compliance"] = "gut"
        elif check_result["score"] >= 25:
            check_result["compliance"] = "mittel"
        else:
            check_result["compliance"] = "mangelhaft"
        
        return check_result
    
    def _calculate_overall_compliance(self, compliance_check: Dict) -> Dict:
        """Berechne Gesamtbewertung der DIN-Normen-Konformität"""
        
        din_checks = compliance_check.get("din_checks", {})
        total_score = 0
        max_score = 0
        
        for check in din_checks.values():
            if isinstance(check, dict) and "score" in check:
                total_score += check["score"]
                max_score += 80  # Angenommene Maximalpunktzahl pro Standard
        
        if max_score > 0:
            overall_percentage = (total_score / max_score) * 100
            compliance_check["score"] = round(overall_percentage, 1)
            
            if overall_percentage >= 80:
                compliance_check["overall_compliance"] = "sehr gut"
            elif overall_percentage >= 60:
                compliance_check["overall_compliance"] = "gut"
            elif overall_percentage >= 40:
                compliance_check["overall_compliance"] = "mittel"
            else:
                compliance_check["overall_compliance"] = "mangelhaft"
        
        # Kritische Issues sammeln
        for check in din_checks.values():
            if isinstance(check, dict) and check.get("compliance") == "mangelhaft":
                compliance_check["critical_issues"].extend(check.get("issues", []))
        
        # Allgemeine Empfehlungen
        if compliance_check["score"] < 60:
            compliance_check["recommendations"].append("Systematische Überarbeitung der technischen Zeichnung empfohlen")
            compliance_check["recommendations"].append("Schulung zu DIN-Normen für technische Zeichnungen erwägen")
        
        return compliance_check

    def get_technical_din_standards_info(self) -> Dict:
        """Gibt Informationen über relevante DIN-Normen für technische Zeichnungen zurück"""
        return {
            "standards": self.technical_din_standards,
            "elements": self.common_technical_elements,
            "last_updated": datetime.now().isoformat()
        } 