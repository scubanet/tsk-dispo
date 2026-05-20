import { useState, type FormEvent } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'
import { Wallpaper } from '@/components/Wallpaper'
import { StatusBar } from '@/components/StatusBar'
import { Logo } from '@/components/Logo'
import { CopyrightFooter } from '@/components/CopyrightFooter'

// GL-004 M5: simple email shape check. We do NOT use the browser's native
// `required` + type="email" validation because its tooltip is unbranded and
// disconnected from the ATOLL palette. The error renders as a styled chip
// below the input instead.
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export function LoginScreen() {
  const { t } = useTranslation()
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')
  const [error, setError] = useState<string | null>(null)
  const [validation, setValidation] = useState<string | null>(null)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setValidation(null)

    const trimmed = email.trim()
    if (!trimmed || !EMAIL_PATTERN.test(trimmed)) {
      setValidation(t('auth.invalid_email'))
      return
    }

    setStatus('sending')
    const { error } = await supabase.auth.signInWithOtp({
      email: trimmed,
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
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: '100vh',
          position: 'relative',
          zIndex: 1,
          padding: '24px 0',
        }}
      >
        <div className="glass card" style={{ width: 380, padding: 28 }}>
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, marginBottom: 24 }}>
            <Logo size={120} />
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 32, fontWeight: 800, letterSpacing: '.08em', lineHeight: 1 }}>ATOLL</div>
              <div className="caption-2" style={{ marginTop: 6, opacity: 0.75 }}>{t('auth.tagline')}</div>
            </div>
          </div>
          <div className="caption" style={{ marginBottom: 18 }}>{t('auth.magic_link_prompt')}</div>

          {status === 'sent' ? (
            <div className="chip chip-green" style={{ marginBottom: 8 }}>
              {t('auth.link_sent')}
            </div>
          ) : (
            <form onSubmit={handleSubmit} noValidate>
              <div
                className="search"
                style={{
                  marginBottom: validation ? 6 : 14,
                  height: 40,
                  outline: validation ? '1px solid var(--brand-red)' : undefined,
                }}
              >
                <input
                  type="email"
                  placeholder={t('auth.email_placeholder')}
                  value={email}
                  onChange={(e) => {
                    setEmail(e.target.value)
                    if (validation) setValidation(null)
                  }}
                  disabled={status === 'sending'}
                  aria-invalid={validation ? true : undefined}
                  aria-describedby={validation ? 'login-email-error' : undefined}
                />
              </div>
              {validation && (
                <div
                  id="login-email-error"
                  role="alert"
                  className="chip chip-red"
                  style={{ marginBottom: 14 }}
                >
                  {validation}
                </div>
              )}
              <button
                className="btn"
                type="submit"
                disabled={status === 'sending' || !email}
                style={{ width: '100%', height: 40, justifyContent: 'center' }}
              >
                {status === 'sending' ? t('common.sending') : t('auth.send_magic_link')}
              </button>
              {error && (
                <div role="alert" className="chip chip-red" style={{ marginTop: 12 }}>{error}</div>
              )}
            </form>
          )}
        </div>

        <div style={{ width: 380, maxWidth: '90vw' }}>
          <CopyrightFooter variant="full" />
        </div>
      </div>
    </>
  )
}
