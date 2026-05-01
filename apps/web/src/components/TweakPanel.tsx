import { useState } from 'react'
import { Icon } from './Icon'
import { useTweaks, type AccentHex, type Layout } from '@/lib/tweaks'

const ACCENTS: { value: AccentHex; name: string }[] = [
  { value: '#0A84FF', name: 'Ocean Blue' },
  { value: '#30B0C7', name: 'Teal' },
  { value: '#34C759', name: 'Reef' },
  { value: '#AF52DE', name: 'Coral' },
  { value: '#FF9500', name: 'Sunset' },
]

export function TweakPanel() {
  const [open, setOpen] = useState(false)
  const [tweaks, set] = useTweaks()

  return (
    <>
      <button
        className="btn-icon tweak-trigger"
        onClick={() => setOpen((v) => !v)}
        title="Tweaks"
      >
        <Icon name="wrench" size={14} />
      </button>

      {open && (
        <div className="tweak-panel glass-strong">
          <div className="title-3" style={{ marginBottom: 4 }}>Tweaks</div>
          <div className="caption" style={{ marginBottom: 8 }}>
            Anpassungen werden lokal gespeichert
          </div>

          <div className="tweak-section">Erscheinungsbild</div>

          <div className="tweak-row">
            <span>Dark Mode</span>
            <input
              type="checkbox"
              checked={tweaks.dark}
              onChange={(e) => set('dark', e.target.checked)}
            />
          </div>

          <div className="tweak-row">
            <span>Akzent</span>
            <div style={{ display: 'flex', gap: 8 }}>
              {ACCENTS.map((a) => (
                <button
                  key={a.value}
                  onClick={() => set('accent', a.value)}
                  title={a.name}
                  style={{
                    width: 26,
                    height: 26,
                    borderRadius: 999,
                    border: 0,
                    background: a.value,
                    cursor: 'pointer',
                    outline: tweaks.accent === a.value ? '2px solid var(--ink)' : 'none',
                    outlineOffset: 2,
                  }}
                />
              ))}
            </div>
          </div>

          <div className="tweak-section">Layout</div>

          <div className="tweak-row">
            <span>Navigation</span>
            <select
              value={tweaks.layout}
              onChange={(e) => set('layout', e.target.value as Layout)}
              style={{ padding: '4px 8px', borderRadius: 6 }}
            >
              <option value="sidebar">Sidebar</option>
              <option value="tabbar">Floating Tabs</option>
            </select>
          </div>
        </div>
      )}
    </>
  )
}
