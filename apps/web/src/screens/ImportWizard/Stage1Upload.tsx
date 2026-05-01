import { useState, type FormEvent } from 'react'
import { supabase } from '@/lib/supabase'
import type { PreviewData } from './index'

interface Props {
  onPreviewReady: (path: string, preview: PreviewData) => void
}

export function Stage1Upload({ onPreviewReady }: Props) {
  const [file, setFile] = useState<File | null>(null)
  const [status, setStatus] = useState<'idle' | 'uploading' | 'previewing' | 'error'>('idle')
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!file) return
    setStatus('uploading')
    setError(null)
    const path = `${Date.now()}-${file.name}`
    const { error: upErr } = await supabase.storage.from('imports').upload(path, file)
    if (upErr) {
      setError(upErr.message)
      setStatus('error')
      return
    }

    setStatus('previewing')
    const { data, error: fnErr } = await supabase.functions.invoke('excel-import', {
      body: { action: 'preview', storage_path: path },
    })
    if (fnErr) {
      setError(fnErr.message)
      setStatus('error')
      return
    }

    onPreviewReady(path, data as PreviewData)
  }

  return (
    <form onSubmit={handleSubmit} className="glass card" style={{ padding: 24 }}>
      <div className="title-3" style={{ marginBottom: 12 }}>Schritt 1 — Datei hochladen</div>
      <input
        type="file"
        accept=".xlsx"
        onChange={(e) => setFile(e.target.files?.[0] ?? null)}
        style={{ marginBottom: 16, display: 'block' }}
      />
      <button className="btn" type="submit" disabled={!file || status !== 'idle'}>
        {status === 'idle' && 'Hochladen & Vorprüfen'}
        {status === 'uploading' && 'Hochladen…'}
        {status === 'previewing' && 'Analysiere…'}
        {status === 'error' && 'Fehler — nochmal'}
      </button>
      {error && (
        <div className="chip chip-red" style={{ marginTop: 12 }}>{error}</div>
      )}
    </form>
  )
}
