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
      <span className="mono" style={{ fontWeight: 600 }}>{formatted}</span>
      <span className="caption-2">TSK Dispo</span>
    </div>
  )
}
