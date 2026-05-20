import { useState, type FormEvent } from 'react'
import { useImportPreview } from '@/hooks/useImport'
import type { PreviewData } from './index'

interface Props {
  onPreviewReady: (path: string, preview: PreviewData) => void
}

export function Stage1Upload({ onPreviewReady }: Props) {
  const [file, setFile] = useState<File | null>(null)
  const preview = useImportPreview()

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!file) return
    preview.mutate(file, {
      onSuccess: ({ storagePath, preview: data }) => {
        onPreviewReady(storagePath, data as PreviewData)
      },
    })
  }

  // The mutation tracks two phases internally: upload + preview. We expose
  // them as a single 'busy' label, but distinguishing them in the button
  // text would need separating into two chained mutations.
  const busy = preview.isPending
  const label = busy
    ? 'Hochladen & Analysieren…'
    : preview.isError
      ? 'Fehler — nochmal'
      : 'Hochladen & Vorprüfen'

  return (
    <form onSubmit={handleSubmit} className="glass card" style={{ padding: 24 }}>
      <div className="title-3" style={{ marginBottom: 12 }}>Schritt 1 — Datei hochladen</div>
      <input
        type="file"
        accept=".xlsx"
        onChange={(e) => setFile(e.target.files?.[0] ?? null)}
        style={{ marginBottom: 16, display: 'block' }}
      />
      <button className="btn" type="submit" disabled={!file || busy}>
        {label}
      </button>
      {preview.error && (
        <div className="chip chip-red" style={{ marginTop: 12 }}>{preview.error.message}</div>
      )}
    </form>
  )
}
