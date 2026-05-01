import { useState } from 'react'
import { Wallpaper } from '@/components/Wallpaper'
import { StatusBar } from '@/components/StatusBar'
import { Stage1Upload } from './Stage1Upload'
import { Stage2Mapping } from './Stage2Mapping'
import { Stage3DryRun } from './Stage3DryRun'
import { Stage4Result } from './Stage4Result'

export interface PreviewData {
  sheets_found: string[]
  course_rows: number
  instructors_in_summary: number
  ambiguous_codes: string[]
  ambiguous_names: string[]
  raw: {
    courses: unknown[]
    instructors: { name: string }[]
    skill_matrix: unknown[]
  }
}

export interface ImportState {
  storagePath?: string
  preview?: PreviewData
  mappings?: Record<string, string>
  result?: unknown
}

export function ImportWizard() {
  const [stage, setStage] = useState<1 | 2 | 3 | 4>(1)
  const [state, setState] = useState<ImportState>({})

  return (
    <>
      <Wallpaper />
      <StatusBar />
      <div
        className="screen-fade scroll"
        style={{
          padding: '40px 60px',
          maxWidth: 900,
          margin: '0 auto',
          height: '100vh',
          position: 'relative',
          zIndex: 1,
        }}
      >
        <div className="title-1" style={{ marginBottom: 4 }}>Excel-Import</div>
        <div className="caption" style={{ marginBottom: 28 }}>Schritt {stage} von 4</div>

        {stage === 1 && (
          <Stage1Upload
            onPreviewReady={(path, preview) => {
              setState({ storagePath: path, preview })
              setStage(2)
            }}
          />
        )}

        {stage === 2 && state.preview && (
          <Stage2Mapping
            preview={state.preview}
            onMappingsConfirmed={(mappings) => {
              setState((s) => ({ ...s, mappings }))
              setStage(3)
            }}
          />
        )}

        {stage === 3 && state.storagePath && state.mappings && (
          <Stage3DryRun
            storagePath={state.storagePath}
            mappings={state.mappings}
            onConfirmed={(result) => {
              setState((s) => ({ ...s, result }))
              setStage(4)
            }}
          />
        )}

        {stage === 4 && state.result !== undefined && <Stage4Result result={state.result} />}
      </div>
    </>
  )
}
