import { useState, type FormEvent } from 'react'
import { supabase } from '@/lib/supabase'
import { Wallpaper } from '@/components/Wallpaper'
import { StatusBar } from '@/components/StatusBar'

export function LoginScreen() {
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setStatus('sending')
    setError(null)
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: `${window.location.origin}/auth/callback` },
    })
    if (error) {
      setError(error.message)
      setStatus('error')
    } else {
      setStatus('sent')
    }
  }

  return (
    <>
      <Wallpaper />
      <StatusBar />
      <div
        style={{
          display: 'grid',
          placeItems: 'center',
          height: '100vh',
          position: 'relative',
          zIndex: 1,
        }}
      >
        <div className="glass card" style={{ width: 380, padding: 28 }}>
          <div className="title-1" style={{ marginBottom: 6 }}>TSK Dispo</div>
          <div className="caption" style={{ marginBottom: 24 }}>Magic-Link an deine Email</div>

          {status === 'sent' ? (
            <div className="chip chip-green" style={{ marginBottom: 8 }}>
              ✉️ Link gesendet — schau in deine Inbox
            </div>
          ) : (
            <form onSubmit={handleSubmit}>
              <div className="search" style={{ marginBottom: 14, height: 40 }}>
                <input
                  type="email"
                  required
                  placeholder="deine@email.ch"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={status === 'sending'}
                />
              </div>
              <button
                className="btn"
                type="submit"
                disabled={status === 'sending' || !email}
                style={{ width: '100%', height: 40, justifyContent: 'center' }}
              >
                {status === 'sending' ? 'Sende…' : 'Magic-Link senden'}
              </button>
              {error && (
                <div className="chip chip-red" style={{ marginTop: 12 }}>{error}</div>
              )}
            </form>
          )}
        </div>
      </div>
    </>
  )
}
