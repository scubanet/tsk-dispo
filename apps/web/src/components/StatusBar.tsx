import { useEffect, useState } from 'react'

export function StatusBar() {
  const [time, setTime] = useState(() => new Date())
  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 30_000)
    return () => clearInterval(id)
  }, [])
  const formatted = time.toLocaleTimeString('de-CH', { hour: '2-digit', minute: '2-digit' })
  return (
    <div className="statusbar">
      <span style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
        <span className="mono" style={{ fontWeight: 600 }}>{formatted}</span>
        <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '.08em', opacity: 0.85 }}>ATOLL</span>
      </span>
      <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span
          style={{
            width: 6,
            height: 6,
            borderRadius: 999,
            background: '#34C759',
            boxShadow: '0 0 0 2px rgba(52,199,89,.18)',
          }}
        />
        <span className="caption-2" style={{ fontWeight: 500, opacity: 0.85 }}>TSK Zürich</span>
      </span>
    </div>
  )
}
