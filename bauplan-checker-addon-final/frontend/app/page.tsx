'use client'

import { useState, useCallback, useEffect } from 'react'
import { useDropzone } from 'react-dropzone'
import axios from 'axios'

// API URL wird im Component dynamisch gesetzt

interface AnalysisResult {
  id: string
  filename: string
  original_filename: string
  upload_time: string
  file_size: number
  page_count: number
  text_preview: string
  text_length: number
  initial_analysis: any
  din_check?: any
  feedback?: any[]
  status: string
}

export default function Home() {
  const [uploading, setUploading] = useState(false)
  const [result, setResult] = useState<AnalysisResult | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [previousPlans, setPreviousPlans] = useState<AnalysisResult[]>([])
  const [checkingDIN, setCheckingDIN] = useState<string | null>(null)
  const [selectedPlan, setSelectedPlan] = useState<AnalysisResult | null>(null)
  const [showFeedback, setShowFeedback] = useState<string | null>(null)
  const [dinNorms, setDinNorms] = useState<any[]>([])
  const [showDinUpload, setShowDinUpload] = useState(false)
  const [apiUrl, setApiUrl] = useState('http://localhost:8000')

  // API URL dynamisch setzen basierend auf der aktuellen Host-Adresse
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const hostname = window.location.hostname
      if (hostname === 'localhost' || hostname === '127.0.0.1') {
        setApiUrl('http://localhost:8000')
      } else {
        // Für Netzwerk-IPs verwende die gleiche IP für das Backend
        setApiUrl(`http://${hostname}:8000`)
      }
    }
  }, [])

  // Lade vorherige Pläne beim Start
  useEffect(() => {
    loadPlans()
    // Polling für DIN-Check Status
    const interval = setInterval(checkForUpdates, 3000)
    return () => clearInterval(interval)
  }, [])

  const loadPlans = async () => {
    try {
      const res = await axios.get(`${apiUrl}/plans`)
      setPreviousPlans(res.data)
    } catch (err) {
      console.error('Fehler beim Laden der Pläne:', err)
    }
  }

  const checkForUpdates = async () => {
    if (checkingDIN) {
      try {
        const res = await axios.get(`${apiUrl}/din-check-status/${checkingDIN}`)
        if (res.data.has_din_check) {
          setCheckingDIN(null)
          await loadPlans()
          if (result && result.id === checkingDIN) {
            setResult({ ...result, din_check: res.data.din_check, status: 'din_checked' })
          }
        }
      } catch (err) {
        console.error('Fehler beim Prüfen des Status:', err)
      }
    }
  }

  const onDrop = useCallback(async (acceptedFiles: File[]) => {
    if (acceptedFiles.length === 0) return

    const file = acceptedFiles[0]
    
    // Handle DIN upload vs regular plan upload
    if (showDinUpload) {
      await handleDinUpload(acceptedFiles)
      return
    }

    setUploading(true)
    setError(null)
    setResult(null)

    const formData = new FormData()
    formData.append('file', file)

    try {
      const response = await axios.post(`${apiUrl}/upload-plan`, formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        timeout: 120000, // 120 Sekunden Timeout für OCR- und AI-Verarbeitung
      })

      setResult(response.data)
      await loadPlans()
    } catch (err: any) {
      if (err.code === 'ECONNREFUSED') {
        setError('Backend nicht erreichbar. Bitte starten Sie das Backend mit "python main.py"')
      } else {
        setError(err.response?.data?.detail || err.message || 'Upload fehlgeschlagen')
      }
    } finally {
      setUploading(false)
    }
  }, [showDinUpload, apiUrl])

  const checkAgainstDIN = async (planId: string) => {
    setCheckingDIN(planId)
    try {
      await axios.post(`${apiUrl}/check-against-din/${planId}`, {}, {
        timeout: 180000, // 180 Sekunden für DIN-Prüfung mit OCR und AI
      })
      // Status wird durch Polling erkannt
    } catch (err: any) {
      setError('DIN-Prüfung fehlgeschlagen: ' + (err.response?.data?.detail || err.message))
      setCheckingDIN(null)
    }
  }

  const submitFeedback = async (planId: string, feedback: any) => {
    try {
      await axios.post(`${apiUrl}/add-feedback/${planId}`, feedback)
      setShowFeedback(null)
      await loadPlans()
      alert('Feedback erfolgreich gespeichert!')
    } catch (err: any) {
      setError('Feedback konnte nicht gespeichert werden: ' + (err.response?.data?.detail || err.message))
    }
  }

  const deletePlan = async (planId: string) => {
    if (!confirm('Plan wirklich löschen?')) return
    
    try {
      await axios.delete(`${apiUrl}/plan/${planId}`)
      await loadPlans()
      if (result && result.id === planId) {
        setResult(null)
      }
    } catch (err: any) {
      setError('Plan konnte nicht gelöscht werden: ' + (err.response?.data?.detail || err.message))
    }
  }

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  // DIN-Normen laden
  const loadDinNorms = async () => {
    try {
      const response = await axios.get(`${apiUrl}/din-norms`)
      console.log('DIN-Normen Response:', response.data)
      setDinNorms(response.data.norms || [])
    } catch (error) {
      console.error('Fehler beim Laden der DIN-Normen:', error)
      console.error('API URL:', apiUrl)
    }
  }

  // DIN-Norm hochladen
  const handleDinUpload = async (files: File[]) => {
    if (files.length === 0) return

    const file = files[0]
    const formData = new FormData()
    formData.append('file', file)

    try {
      setUploading(true)
      const response = await axios.post(`${apiUrl}/upload-din-norm`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })

      alert(`✅ DIN-Norm erfolgreich hochgeladen: ${response.data.chunks_processed} Textblöcke verarbeitet`)
      loadDinNorms() // Liste aktualisieren
    } catch (error) {
      console.error('DIN-Upload Fehler:', error)
      alert('❌ DIN-Upload fehlgeschlagen')
    } finally {
      setUploading(false)
    }
  }

  // DIN-Norm löschen
  const deleteDinNorm = async (filename: string) => {
    if (!confirm(`DIN-Norm "${filename}" wirklich löschen?`)) return

    try {
      await axios.delete(`${apiUrl}/din-norm/${filename}`)
      alert('✅ DIN-Norm gelöscht')
      loadDinNorms()
    } catch (error) {
      console.error('Löschen fehlgeschlagen:', error)
      alert('❌ Löschen fehlgeschlagen')
    }
  }

  // DIN-Normen beim Start laden
  useEffect(() => {
    if (apiUrl) {
      loadDinNorms()
    }
  }, [apiUrl])

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'application/pdf': ['.pdf']
    },
    multiple: false,
    maxSize: 50 * 1024 * 1024 // 50MB
  })

  return (
    <main className="min-h-screen p-8 bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-12">
          <h1 className="text-4xl font-bold mb-4 text-gray-800">
            🏗️ Bauplan-Checker System
          </h1>
          <p className="text-lg text-gray-600">
            Automatische Prüfung von Bauplänen gegen DIN-Normen mit KI-Unterstützung
          </p>
        </div>

        {/* Tab Navigation */}
        <div className="flex justify-center mb-8">
          <div className="bg-white rounded-lg p-1 shadow-md">
            <button
              onClick={() => setShowDinUpload(false)}
              className={`px-6 py-2 rounded-lg font-medium transition-colors ${
                !showDinUpload 
                  ? 'bg-blue-500 text-white shadow-md' 
                  : 'text-gray-600 hover:text-blue-500'
              }`}
            >
              📋 Bauplan prüfen
            </button>
            <button
              onClick={() => setShowDinUpload(true)}
              className={`px-6 py-2 rounded-lg font-medium transition-colors ${
                showDinUpload 
                  ? 'bg-green-500 text-white shadow-md' 
                  : 'text-gray-600 hover:text-green-500'
              }`}
            >
              📚 DIN-Normen verwalten ({dinNorms.length})
            </button>
          </div>
        </div>

        {/* DIN Upload Tab */}
        {showDinUpload && (
          <div className="bg-white rounded-lg shadow-lg p-8 mb-8">
            <h2 className="text-2xl font-bold mb-6 text-center text-green-700">
              📚 DIN-Normen Verwaltung
            </h2>
            
            {/* DIN Upload Area */}
            <div 
              {...getRootProps()} 
              className={`border-2 border-dashed p-12 text-center rounded-lg cursor-pointer transition-colors ${
                isDragActive 
                  ? 'border-green-400 bg-green-50' 
                  : 'border-green-300 hover:border-green-400 hover:bg-green-50'
              }`}
            >
              <input {...getInputProps()} />
              <div className="text-6xl mb-4">📄</div>
              <p className="text-xl font-medium text-green-600 mb-2">
                📚 DIN-Norm PDF hier hochladen
              </p>
              <p className="text-green-500">
                Wird automatisch verarbeitet und in die Wissensdatenbank integriert
              </p>
            </div>

            {/* Verfügbare DIN-Normen */}
            <div className="mt-8">
              <h3 className="text-lg font-semibold mb-4 text-gray-700">
                📋 Verfügbare DIN-Normen
              </h3>
              
              {dinNorms.length === 0 ? (
                <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                  <p className="text-yellow-800">
                    Noch keine DIN-Normen hochgeladen. Laden Sie Ihre erste DIN-Norm hoch, um mit der automatischen Prüfung zu beginnen.
                  </p>
                </div>
              ) : (
                <div className="space-y-2">
                  {dinNorms.map((norm, index) => (
                    <div key={index} className="flex justify-between items-center bg-gray-50 p-3 rounded-lg">
                      <div className="flex-1">
                        <div className="font-medium text-gray-800">{norm.filename}</div>
                        <div className="text-sm text-gray-500">
                          {formatFileSize(norm.file_size)} • {norm.upload_time ? new Date(norm.upload_time).toLocaleDateString('de-DE') : 'Unbekannt'}
                        </div>
                      </div>
                      <button
                        onClick={() => deleteDinNorm(norm.filename)}
                        className="px-3 py-1 bg-red-500 text-white rounded hover:bg-red-600 transition-colors"
                      >
                        🗑️ Löschen
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Plan Upload Tab */}
        {!showDinUpload && (
          <>
            {/* Error Display */}
            {error && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-8">
                <div className="flex items-center">
                  <div className="text-2xl mr-3">❌</div>
                  <div>
                    <h3 className="font-semibold text-red-800">Fehler</h3>
                    <p className="text-red-700">{error}</p>
                  </div>
                </div>
              </div>
            )}

            {/* Upload Area */}
            <div className="bg-white rounded-lg shadow-lg p-8 mb-8">
              <div 
                {...getRootProps()} 
                className={`border-2 border-dashed p-12 text-center rounded-lg cursor-pointer transition-colors ${
                  isDragActive 
                    ? 'border-blue-400 bg-blue-50' 
                    : 'border-gray-300 hover:border-blue-400 hover:bg-blue-50'
                }`}
              >
                <input {...getInputProps()} />
                <div className="text-6xl mb-4">
                  {uploading ? '⏳' : '📋'}
                </div>
                <p className="text-xl font-medium text-gray-700 mb-2">
                  {uploading ? 'Bauplan wird verarbeitet...' : 'Bauplan PDF hier hochladen'}
                </p>
                <p className="text-gray-500">
                  {uploading 
                    ? 'Bitte warten - KI-Analyse läuft...' 
                    : 'Drag & Drop oder klicken zum Auswählen (max. 50MB)'
                  }
                </p>
                {uploading && (
                  <div className="mt-4 bg-blue-100 rounded-lg p-3">
                    <div className="animate-pulse text-blue-600">
                      🤖 KI analysiert Ihren Bauplan...
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Current Result */}
            {result && (
              <div className="bg-white rounded-lg shadow-lg p-8 mb-8">
                <h2 className="text-2xl font-bold mb-6 text-center">
                  📊 Analyse-Ergebnis
                </h2>
                
                <div className="grid md:grid-cols-2 gap-6">
                  <div>
                    <h3 className="font-semibold text-lg mb-3 text-gray-700">📄 Plan-Info</h3>
                    <div className="space-y-2 text-sm">
                      <div><strong>Datei:</strong> {result.original_filename}</div>
                      <div><strong>Größe:</strong> {formatFileSize(result.file_size)}</div>
                      <div><strong>Seiten:</strong> {result.page_count}</div>
                      <div><strong>Text-Länge:</strong> {result.text_length} Zeichen</div>
                      <div><strong>Upload:</strong> {new Date(result.upload_time).toLocaleString('de-DE')}</div>
                    </div>
                  </div>
                  
                  <div>
                    <h3 className="font-semibold text-lg mb-3 text-gray-700">🎯 Status</h3>
                    <div className="space-y-2">
                      <div className="flex items-center">
                        <span className="w-3 h-3 bg-green-500 rounded-full mr-2"></span>
                        <span>PDF analysiert</span>
                      </div>
                      <div className="flex items-center">
                        <span className={`w-3 h-3 rounded-full mr-2 ${
                          result.din_check ? 'bg-green-500' : 'bg-yellow-500'
                        }`}></span>
                        <span>DIN-Prüfung {result.din_check ? 'abgeschlossen' : 'ausstehend'}</span>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Actions */}
                <div className="mt-6 flex flex-wrap gap-3">
                  {!result.din_check && (
                    <button
                      onClick={() => checkAgainstDIN(result.id)}
                      disabled={checkingDIN === result.id}
                      className="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50 transition-colors"
                    >
                      {checkingDIN === result.id ? '⏳ Prüfe gegen DIN...' : '📋 Gegen DIN-Normen prüfen'}
                    </button>
                  )}
                  
                  <button
                    onClick={() => setSelectedPlan(result)}
                    className="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 transition-colors"
                  >
                    📊 Details anzeigen
                  </button>
                  
                  <button
                    onClick={() => setShowFeedback(result.id)}
                    className="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600 transition-colors"
                  >
                    💬 Feedback geben
                  </button>
                </div>
              </div>
            )}

            {/* Previous Plans */}
            {previousPlans.length > 0 && (
              <div className="bg-white rounded-lg shadow-lg p-8">
                <h2 className="text-2xl font-bold mb-6 text-center">
                  🗂️ Vorherige Analysen
                </h2>
                
                <div className="space-y-4">
                  {previousPlans.map((plan) => (
                    <div key={plan.id} className="border rounded-lg p-4 hover:bg-gray-50 transition-colors">
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <h3 className="font-medium text-lg">{plan.original_filename}</h3>
                          <div className="text-sm text-gray-500 mt-1">
                            {formatFileSize(plan.file_size)} • {plan.page_count} Seiten • {new Date(plan.upload_time).toLocaleDateString('de-DE')}
                          </div>
                          <div className="flex items-center mt-2 space-x-4">
                            <span className={`inline-block px-2 py-1 rounded text-xs font-medium ${
                              plan.din_check 
                                ? 'bg-green-100 text-green-800' 
                                : 'bg-yellow-100 text-yellow-800'
                            }`}>
                              {plan.din_check ? '✅ DIN-geprüft' : '⏳ DIN-Prüfung ausstehend'}
                            </span>
                            {plan.status === 'processing' && (
                              <span className="inline-block px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                🔄 Wird geprüft...
                              </span>
                            )}
                            {checkingDIN === plan.id && (
                              <span className="inline-block px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800">
                                🔄 Wird geprüft...
                              </span>
                            )}
                          </div>
                        </div>
                        
                        <div className="flex space-x-2 ml-4">
                          {!plan.din_check && (
                            <button
                              onClick={() => checkAgainstDIN(plan.id)}
                              disabled={checkingDIN === plan.id}
                              className="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600 disabled:opacity-50 transition-colors"
                            >
                              {checkingDIN === plan.id ? '⏳ Wird geprüft' : '📋 Wird geprüft...'}
                            </button>
                          )}
                          
                          <button
                            onClick={() => setSelectedPlan(plan)}
                            className="px-3 py-1 bg-gray-500 text-white text-sm rounded hover:bg-gray-600 transition-colors"
                          >
                            📊 Details
                          </button>
                          
                          <button
                            onClick={() => setShowFeedback(plan.id)}
                            className="px-3 py-1 bg-green-500 text-white text-sm rounded hover:bg-green-600 transition-colors"
                          >
                            💬 Feedback
                          </button>
                          
                          <button
                            onClick={() => deletePlan(plan.id)}
                            className="px-3 py-1 bg-red-500 text-white text-sm rounded hover:bg-red-600 transition-colors"
                          >
                            🗑️ Löschen
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        )}

        {/* Feedback Modal */}
        {showFeedback && (
          <FeedbackForm 
            planId={showFeedback} 
            onSubmit={submitFeedback}
            onClose={() => setShowFeedback(null)}
          />
        )}

        {/* Plan Details Modal */}
        {selectedPlan && (
          <PlanDetailsModal 
            plan={selectedPlan} 
            onClose={() => setSelectedPlan(null)}
            onFeedback={() => {
              setShowFeedback(selectedPlan.id)
              setSelectedPlan(null)
            }}
          />
        )}
      </div>
    </main>
  )
}

// Feedback Form Component
function FeedbackForm({ planId, onSubmit, onClose }: { 
  planId: string, 
  onSubmit: (planId: string, feedback: any) => void,
  onClose: () => void 
}) {
  const [rating, setRating] = useState(5)
  const [correctPlan, setCorrectPlan] = useState(true)
  const [comments, setComments] = useState('')

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    onSubmit(planId, {
      rating,
      correct_plan: correctPlan,
      comments,
      feedback_type: 'user_evaluation'
    })
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg p-8 max-w-md w-full">
        <h3 className="text-xl font-bold mb-6">💬 Feedback geben</h3>
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-2">Bewertung (1-10)</label>
            <input
              type="range"
              min="1"
              max="10"
              value={rating}
              onChange={(e) => setRating(parseInt(e.target.value))}
              className="w-full"
            />
            <div className="text-center text-lg font-semibold text-blue-600">{rating}/10</div>
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">Analyse korrekt?</label>
            <div className="flex space-x-4">
              <label className="flex items-center">
                <input
                  type="radio"
                  checked={correctPlan}
                  onChange={() => setCorrectPlan(true)}
                  className="mr-2"
                />
                ✅ Ja, korrekt
              </label>
              <label className="flex items-center">
                <input
                  type="radio"
                  checked={!correctPlan}
                  onChange={() => setCorrectPlan(false)}
                  className="mr-2"
                />
                ❌ Nein, fehlerhaft
              </label>
            </div>
          </div>
          
          <div>
            <label className="block text-sm font-medium mb-2">Kommentare</label>
            <textarea
              value={comments}
              onChange={(e) => setComments(e.target.value)}
              className="w-full p-2 border rounded-lg"
              rows={4}
              placeholder="Optionale Anmerkungen zur Analyse..."
            />
          </div>
          
          <div className="flex space-x-3 pt-4">
            <button
              type="submit"
              className="flex-1 bg-blue-500 text-white py-2 rounded-lg hover:bg-blue-600 transition-colors"
            >
              💾 Feedback speichern
            </button>
            <button
              type="button"
              onClick={onClose}
              className="flex-1 bg-gray-500 text-white py-2 rounded-lg hover:bg-gray-600 transition-colors"
            >
              ❌ Abbrechen
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

// DIN Check Results Component
function DINCheckResults({ dinCheck }: { dinCheck: any }) {
  if (!dinCheck) return null

  const getComplianceColor = (compliance: string) => {
    switch(compliance?.toLowerCase()) {
      case 'erfüllt': case 'gut': return 'text-green-600 bg-green-50'
      case 'mangelhaft': case 'problematisch': return 'text-red-600 bg-red-50'
      case 'akzeptabel': case 'befriedigend': return 'text-yellow-600 bg-yellow-50'
      default: return 'text-gray-600 bg-gray-50'
    }
  }

  const getScoreColor = (score: number) => {
    if (score >= 8) return 'text-green-600 bg-green-100'
    if (score >= 6) return 'text-yellow-600 bg-yellow-100'
    if (score >= 4) return 'text-orange-600 bg-orange-100'
    return 'text-red-600 bg-red-100'
  }

  return (
    <div className="space-y-6">
      {/* Technische Compliance */}
      {dinCheck.technical_compliance && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h5 className="font-semibold text-lg mb-3 text-blue-800">🔧 Technische Compliance</h5>
          
          <div className="mb-4">
            <div className="flex items-center justify-between mb-2">
              <span className="font-medium">Gesamtbewertung:</span>
              <span className={`px-3 py-1 rounded-full text-sm font-medium ${getComplianceColor(dinCheck.technical_compliance.overall_compliance)}`}>
                {dinCheck.technical_compliance.overall_compliance}
              </span>
            </div>
            
            {dinCheck.technical_compliance.score !== undefined && (
              <div className="flex items-center justify-between">
                <span className="font-medium">Score:</span>
                <span className={`px-3 py-1 rounded-full text-sm font-medium ${getScoreColor(dinCheck.technical_compliance.score)}`}>
                  {dinCheck.technical_compliance.score.toFixed(1)}/10
                </span>
              </div>
            )}
          </div>

          {/* DIN Checks */}
          {dinCheck.technical_compliance.din_checks && (
            <div className="mb-4">
              <h6 className="font-medium text-blue-700 mb-2">📋 DIN-Standard Prüfungen:</h6>
              {Object.entries(dinCheck.technical_compliance.din_checks).map(([key, check]: [string, any]) => (
                <div key={key} className="bg-white p-3 rounded border mb-2">
                  <div className="flex items-center justify-between mb-2">
                    <span className="font-medium text-sm">{check.standard}</span>
                    <span className={`px-2 py-1 rounded text-xs font-medium ${getComplianceColor(check.compliance)}`}>
                      {check.compliance}
                    </span>
                  </div>
                  
                  {check.issues && check.issues.length > 0 && (
                    <div className="mb-2">
                      <strong className="text-red-600 text-xs">Probleme:</strong>
                      <ul className="text-xs text-red-600 ml-4">
                        {check.issues.map((issue: string, i: number) => (
                          <li key={i}>• {issue}</li>
                        ))}
                      </ul>
                    </div>
                  )}
                  
                  {check.recommendations && check.recommendations.length > 0 && (
                    <div>
                      <strong className="text-blue-600 text-xs">Empfehlungen:</strong>
                      <ul className="text-xs text-blue-600 ml-4">
                        {check.recommendations.map((rec: string, i: number) => (
                          <li key={i}>• {rec}</li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          {/* Critical Issues */}
          {dinCheck.technical_compliance.critical_issues && dinCheck.technical_compliance.critical_issues.length > 0 && (
            <div className="bg-red-50 border border-red-200 p-3 rounded mb-4">
              <h6 className="font-medium text-red-700 mb-2">🚨 Kritische Punkte:</h6>
              <ul className="text-sm text-red-600">
                {dinCheck.technical_compliance.critical_issues.map((issue: string, i: number) => (
                  <li key={i}>• {issue}</li>
                ))}
              </ul>
            </div>
          )}

          {/* Recommendations */}
          {dinCheck.technical_compliance.recommendations && dinCheck.technical_compliance.recommendations.length > 0 && (
            <div className="bg-green-50 border border-green-200 p-3 rounded">
              <h6 className="font-medium text-green-700 mb-2">💡 Empfehlungen:</h6>
              <ul className="text-sm text-green-600">
                {dinCheck.technical_compliance.recommendations.map((rec: string, i: number) => (
                  <li key={i}>• {rec}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}

      {/* Text-basierte Analyse */}
      {dinCheck.text_based_analysis && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <h5 className="font-semibold text-lg mb-3 text-green-800">📝 Text-basierte DIN-Analyse</h5>
          
          <div className="grid md:grid-cols-2 gap-4 mb-4">
            <div>
              <div className="flex items-center justify-between mb-2">
                <span className="font-medium">Gesamtbewertung:</span>
                <span className={`px-3 py-1 rounded-full text-sm font-medium ${getComplianceColor(dinCheck.text_based_analysis.gesamtbewertung)}`}>
                  {dinCheck.text_based_analysis.gesamtbewertung}
                </span>
              </div>
              
              {dinCheck.text_based_analysis.normen_gefunden && (
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium">DIN-Normen gefunden:</span>
                  <span className="bg-blue-100 text-blue-800 px-2 py-1 rounded text-sm font-medium">
                    {dinCheck.text_based_analysis.normen_gefunden}
                  </span>
                </div>
              )}

              {dinCheck.text_based_analysis.gpt_model && (
                <div className="flex items-center justify-between">
                  <span className="font-medium">AI-Model:</span>
                  <span className="bg-purple-100 text-purple-800 px-2 py-1 rounded text-sm font-medium">
                    {dinCheck.text_based_analysis.gpt_model}
                  </span>
                </div>
              )}
            </div>

            <div>
              {dinCheck.text_based_analysis.top_normen && dinCheck.text_based_analysis.top_normen.length > 0 && (
                <div>
                  <h6 className="font-medium text-green-700 mb-2">🏆 Relevante Normen:</h6>
                  <ul className="text-sm text-green-600">
                                                              {[...new Set(dinCheck.text_based_analysis.top_normen)].map((norm: unknown, i: number) => (
                       <li key={i} className="bg-green-100 px-2 py-1 rounded mb-1">• {String(norm)}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          </div>

          {/* Erfüllte Anforderungen */}
          {dinCheck.text_based_analysis.erfuellte_anforderungen && dinCheck.text_based_analysis.erfuellte_anforderungen.length > 0 && (
            <div className="mb-4">
              <h6 className="font-medium text-green-700 mb-2">✅ Erfüllte Anforderungen:</h6>
              <div className="space-y-2">
                {dinCheck.text_based_analysis.erfuellte_anforderungen.map((req: any, i: number) => (
                  <div key={i} className="bg-green-100 p-2 rounded text-sm">
                    <strong>{req.norm}:</strong> {req.anforderung} - {req.bemerkung}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Mögliche Verstöße */}
          {dinCheck.text_based_analysis.moegliche_verstoesse && dinCheck.text_based_analysis.moegliche_verstoesse.length > 0 && (
            <div className="mb-4">
              <h6 className="font-medium text-red-700 mb-2">⚠️ Mögliche Verstöße:</h6>
              <div className="space-y-2">
                {dinCheck.text_based_analysis.moegliche_verstoesse.map((violation: any, i: number) => (
                  <div key={i} className="bg-red-100 p-2 rounded text-sm">
                    <strong>{violation.norm}:</strong> {violation.anforderung} - {violation.bemerkung}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Kritische Punkte */}
          {dinCheck.text_based_analysis.kritische_punkte && dinCheck.text_based_analysis.kritische_punkte.length > 0 && (
            <div className="mb-4">
              <h6 className="font-medium text-red-700 mb-2">🚨 Kritische Punkte:</h6>
              <div className="space-y-2">
                {dinCheck.text_based_analysis.kritische_punkte.map((point: any, i: number) => (
                  <div key={i} className="bg-red-100 p-2 rounded text-sm">
                    <strong>{point.kritischer_punkt}:</strong> {point.bemerkung}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Empfehlungen */}
          {dinCheck.text_based_analysis.empfehlungen && dinCheck.text_based_analysis.empfehlungen.length > 0 && (
            <div className="mb-4">
              <h6 className="font-medium text-blue-700 mb-2">💡 Empfehlungen:</h6>
              <div className="space-y-2">
                {dinCheck.text_based_analysis.empfehlungen.map((emp: any, i: number) => (
                  <div key={i} className="bg-blue-100 p-2 rounded text-sm">
                    <strong>Empfehlung:</strong> {emp.empfehlung}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Anwendbare Normen */}
          {dinCheck.text_based_analysis.anwendbare_normen && dinCheck.text_based_analysis.anwendbare_normen.length > 0 && (
            <div>
              <h6 className="font-medium text-blue-700 mb-2">📚 Anwendbare Normen:</h6>
              <div className="space-y-2">
                {dinCheck.text_based_analysis.anwendbare_normen.map((norm: any, i: number) => (
                  <div key={i} className="bg-blue-50 p-2 rounded text-sm">
                    <strong>{norm.norm}:</strong>
                    {norm.referenz && (
                      <a href={norm.referenz} target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline ml-2">
                        📎 Referenz
                      </a>
                    )}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Timestamp */}
          {dinCheck.text_based_analysis.timestamp && (
            <div className="mt-4 text-xs text-gray-500 border-t pt-2">
              Analyse durchgeführt: {new Date(dinCheck.text_based_analysis.timestamp).toLocaleString('de-DE')}
            </div>
          )}
        </div>
      )}

      {/* Analysis Type Info */}
      {dinCheck.analysis_type && (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
          <div className="flex items-center justify-between">
            <span className="font-medium text-gray-700">📊 Analyse-Typ:</span>
            <span className="bg-gray-200 text-gray-800 px-2 py-1 rounded text-sm font-medium">
              {dinCheck.analysis_type}
            </span>
          </div>
          {dinCheck.timestamp && (
            <div className="text-xs text-gray-500 mt-2">
              Prüfung abgeschlossen: {new Date(dinCheck.timestamp).toLocaleString('de-DE')}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

// Plan Details Modal Component
function PlanDetailsModal({ plan, onClose, onFeedback }: { 
  plan: AnalysisResult, 
  onClose: () => void,
  onFeedback: () => void 
}) {
  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg p-8 max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        <div className="flex justify-between items-start mb-6">
          <h3 className="text-2xl font-bold">📊 Plan-Details</h3>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700 text-2xl"
          >
            ✕
          </button>
        </div>
        
        <div className="grid md:grid-cols-2 gap-6 mb-6">
          <div className="col-span-2">
            <h4 className="font-semibold text-lg mb-3">📄 Datei-Informationen</h4>
            <div className="grid grid-cols-2 gap-4 text-sm">
              <div><strong>Original Name:</strong> {plan.original_filename}</div>
              <div><strong>Dateigröße:</strong> {plan.file_size ? `${(plan.file_size / 1024 / 1024).toFixed(2)} MB` : 'Unbekannt'}</div>
              <div><strong>Seitenzahl:</strong> {plan.page_count}</div>
              <div><strong>Text-Länge:</strong> {plan.text_length} Zeichen</div>
              <div><strong>Upload-Zeit:</strong> {plan.upload_time && plan.upload_time !== 'Invalid Date' ? new Date(plan.upload_time).toLocaleString('de-DE') : 'Unbekannt'}</div>
              <div><strong>Status:</strong> <span className="capitalize">{plan.status?.replace('_', ' ')}</span></div>
            </div>
          </div>
        </div>
        

        
        {plan.din_check && (
          <div className="mb-6">
            <h4 className="font-semibold text-lg mb-3">📏 DIN-Normen Prüfung</h4>
            <DINCheckResults dinCheck={plan.din_check} />
          </div>
        )}
        
        {plan.feedback && plan.feedback.length > 0 && (
          <div className="mb-6">
            <h4 className="font-semibold text-lg mb-3">💬 Feedback Historie</h4>
            <div className="space-y-3">
              {plan.feedback.map((fb: any, index: number) => (
                <div key={index} className="bg-yellow-50 p-3 rounded-lg">
                  <div className="flex justify-between items-start mb-2">
                    <span className="font-medium">Bewertung: {fb.rating}/10</span>
                    <span className="text-sm text-gray-500">
                      {fb.timestamp ? new Date(fb.timestamp).toLocaleString('de-DE') : 'Kein Datum'}
                    </span>
                  </div>
                  <div className="text-sm">
                    <strong>Korrekt:</strong> {fb.correct_plan ? '✅ Ja' : '❌ Nein'}
                  </div>
                  {fb.comments && (
                    <div className="text-sm mt-2">
                      <strong>Kommentar:</strong> {fb.comments}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
        
        <div className="flex space-x-3">
          <button
            onClick={onFeedback}
            className="px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors"
          >
            💬 Feedback hinzufügen
          </button>
          <button
            onClick={onClose}
            className="px-4 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors"
          >
            ✕ Schließen
          </button>
        </div>
      </div>
    </div>
  )
}
