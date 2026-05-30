/**
 * Public Card Page — `https://atoll-os.com/c/<slug>`.
 *
 * What the QR code lands on. No login. Visitor sees the persona card,
 * action buttons (Email / Phone / WhatsApp / Save Contact), and a lead
 * form below to leave their details.
 *
 * Three database touches per visit:
 *   1. SELECT cards + contacts (joined) on mount
 *   2. INSERT card_scans on mount (source = qr)
 *   3. INSERT card_scans with field_tapped on each action button click
 *   4. INSERT card_leads on form submit
 *
 * RLS (migration 0098) grants the `anon` role exactly these three INSERTs
 * + a SELECT scoped to `is_active = true`. So we don't need any server-side
 * code — the browser talks to PostgREST directly with the public anon key.
 */
import { useEffect, useMemo, useRef, useState } from 'react'
import { useParams, useSearchParams } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { translations, resolveLanguage, type Lang, type Translations } from './PublicCardScreen.i18n'
import { LanguageSwitcher } from '@/components/LanguageSwitcher'

// ─── Types (mirror the iOS app, kept inline so we don't pull AtollCore-iOS) ───

type ThemePreset = 'courseDirector' | 'seaExplorers' | 'privat' | 'custom'

interface CardTheme {
  preset: ThemePreset
  gradient_start?: string
  gradient_end?: string
}

interface DiveProfile {
  padi_member_number?: string
  instructor_level?: string
  specialties?: string[]
  total_dives?: number
  since_year?: number
  teaching_languages?: string[]
}

interface FieldVisibility {
  email: boolean
  phone: boolean
  whatsapp: boolean
  instagram: boolean
  linkedin: boolean
  website: boolean
  diveStats: boolean
}

interface CardRow {
  id: string
  slug: string
  title: string
  subtitle: string | null
  badge: string | null
  theme: CardTheme
  dive_profile: DiveProfile | null
  field_visibility: FieldVisibility
  person_id: string
}

interface ContactRow {
  id: string
  first_name: string | null
  last_name: string | null
  primary_email: string | null
  phones: Array<{ number: string; label?: string }>
  languages: string[]
  avatar_url: string | null
}

// ─── Gradients (mirror Theme/CardTheme.swift in iOS) ──────────────────

const PERSONA_GRADIENTS: Record<ThemePreset, [string, string]> = {
  courseDirector: ['#1E3A8A', '#4A8DE8'],
  seaExplorers:   ['#0D6E7A', '#4EC5D6'],
  privat:         ['#5B3A8E', '#9B6DD0'],
  custom:         ['#1E3A8A', '#4A8DE8'],
}

function gradientFor(theme: CardTheme): string {
  if (theme.gradient_start && theme.gradient_end) {
    return `linear-gradient(135deg, ${theme.gradient_start}, ${theme.gradient_end})`
  }
  const [start, end] = PERSONA_GRADIENTS[theme.preset] ?? PERSONA_GRADIENTS.courseDirector
  return `linear-gradient(135deg, ${start}, ${end})`
}

// ─── Component ────────────────────────────────────────────────────────

export function PublicCardScreen() {
  const { slug } = useParams<{ slug: string }>()
  const [searchParams] = useSearchParams()
  const lang: Lang = resolveLanguage(searchParams)
  const t = translations[lang]
  const [state, setState] = useState<
    { kind: 'loading' }
    | { kind: 'notfound' }
    | { kind: 'error'; message: string }
    | { kind: 'ready'; card: CardRow; contact: ContactRow | null }
  >({ kind: 'loading' })

  useEffect(() => {
    if (!slug) {
      setState({ kind: 'notfound' })
      return
    }
    void (async () => {
      try {
        const { data: card, error: cardErr } = await supabase
          .from('cards')
          .select('*')
          .eq('slug', slug)
          .eq('is_active', true)
          .maybeSingle<CardRow>()

        if (cardErr) throw cardErr
        if (!card) {
          setState({ kind: 'notfound' })
          return
        }

        const { data: contact } = await supabase
          .from('contacts')
          .select('id, first_name, last_name, primary_email, phones, languages, avatar_url')
          .eq('id', card.person_id)
          .maybeSingle<ContactRow>()

        setState({ kind: 'ready', card, contact: contact ?? null })

        // Fire-and-forget scan log — no need to await, doesn't block render.
        void supabase.from('card_scans').insert({
          card_id: card.id,
          source: 'qr',
        })
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err)
        setState({ kind: 'error', message })
      }
    })()
  }, [slug])

  if (state.kind === 'loading') return <CenteredMessage>Lade Karte …</CenteredMessage>
  if (state.kind === 'notfound')
    return (
      <CenteredMessage>
        <LanguageSwitcher current={lang} />
        <div style={{ textAlign: 'center' }}>
          <h1 style={{ fontSize: 20, fontWeight: 700, margin: '0 0 8px' }}>{t.notFoundTitle}</h1>
          <p style={{ margin: 0 }}>{t.notFoundMessage}</p>
        </div>
      </CenteredMessage>
    )
  if (state.kind === 'error')
    return <CenteredMessage>Fehler beim Laden: {state.message}</CenteredMessage>

  return <CardView card={state.card} contact={state.contact} lang={lang} t={t} />
}

// ─── Layout subcomponents ─────────────────────────────────────────────

function CenteredMessage({ children }: { children: React.ReactNode }) {
  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: '-apple-system, system-ui, sans-serif',
      color: '#5A6478',
      background: '#F5F8FC',
    }}>
      {children}
    </div>
  )
}

function CardView({ card, contact, lang, t }: { card: CardRow; contact: ContactRow | null; lang: Lang; t: Translations }) {
  const fullName = useMemo(() => {
    if (!contact) return card.title
    return [contact.first_name, contact.last_name].filter(Boolean).join(' ')
  }, [contact, card.title])

  const initials = useMemo(() => {
    if (!contact) return 'A'
    return [(contact.first_name?.[0] ?? ''), (contact.last_name?.[0] ?? '')].join('').toUpperCase()
  }, [contact])

  // Dynamic browser-tab title + theme-color so Safari's tab group
  // (and any "Add to Home Screen" install) reflects the persona.
  useEffect(() => {
    const previousTitle = document.title
    document.title = `${fullName} — ${card.title}`

    const themeMeta = document.querySelector('meta[name="theme-color"]')
    const previousThemeColor = themeMeta?.getAttribute('content') ?? null
    const [gradientStart] = PERSONA_GRADIENTS[card.theme.preset] ?? PERSONA_GRADIENTS.courseDirector
    themeMeta?.setAttribute('content', gradientStart)

    return () => {
      document.title = previousTitle
      if (previousThemeColor) themeMeta?.setAttribute('content', previousThemeColor)
    }
  }, [fullName, card.title, card.theme.preset])

  const phone = contact?.phones?.[0]?.number
  const email = contact?.primary_email
  const showEmail    = card.field_visibility.email   && !!email
  const showPhone    = card.field_visibility.phone   && !!phone
  const showWhatsApp = card.field_visibility.whatsapp && !!phone

  // Sticky mobile CTA: visible until the lead form scrolls into view.
  // Once the form (or its success state, which lives in the same node)
  // is on screen, the CTA hides — no need to lift form state up.
  const formRef = useRef<HTMLDivElement>(null)
  const [showStickyCta, setShowStickyCta] = useState(true)
  useEffect(() => {
    if (!formRef.current) return
    const observer = new IntersectionObserver(
      ([entry]) => setShowStickyCta(!entry.isIntersecting),
      { threshold: 0.25 },
    )
    observer.observe(formRef.current)
    return () => observer.disconnect()
  }, [])

  function logFieldTap(field: 'email' | 'phone' | 'whatsapp' | 'leadForm') {
    void supabase.from('card_scans').insert({
      card_id: card.id,
      source: 'qr',
      field_tapped: field,
    })
  }

  return (
    <div style={{
      minHeight: '100vh',
      background: '#F5F8FC',
      fontFamily: '-apple-system, BlinkMacSystemFont, system-ui, sans-serif',
      color: '#1A1F2E',
      padding: '24px 16px 64px',
      maxWidth: 480,
      margin: '0 auto',
      position: 'relative',
    }}>
      <LanguageSwitcher current={lang} />

      {/* The persona business card */}
      <div style={{
        background: gradientFor(card.theme),
        borderRadius: 20,
        padding: '22px 22px 24px',
        color: 'white',
        boxShadow: '0 12px 30px rgba(0,0,0,.15), 0 4px 10px rgba(0,0,0,.08)',
        position: 'relative',
        overflow: 'hidden',
      }}>
        {/* Top row: AtollCard logo + badge */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <img src="/atollcard-logo.png" alt="AtollCard"
                 style={{ width: 48, height: 48, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,.25))' }}/>
            <span style={{ fontSize: 14, fontWeight: 800, letterSpacing: 0.5, opacity: 0.95 }}>
              AtollCard
            </span>
          </div>
          {card.badge && (
            <div style={{
              background: 'rgba(255,255,255,.2)',
              padding: '4px 10px',
              borderRadius: 100,
              fontSize: 10, fontWeight: 800, letterSpacing: .8,
            }}>{card.badge}</div>
          )}
        </div>

        <div style={{ marginTop: 56 }}>
          <div style={{ fontSize: 28, fontWeight: 700, letterSpacing: -.5, lineHeight: 1.1 }}>
            {fullName}
          </div>
          <div style={{ fontSize: 13, opacity: .85, marginTop: 4 }}>
            {card.title}{card.subtitle ? ` · ${card.subtitle}` : ''}
          </div>
        </div>
      </div>

      {/* Avatar: overlaps the card edge, persona-themed gradient ring, white border */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 16,
        marginTop: -32, marginLeft: 22, marginRight: 22,
      }}>
        {contact?.avatar_url ? (
          <img
            src={contact.avatar_url}
            alt={fullName}
            style={{
              width: 88, height: 88, borderRadius: '50%',
              objectFit: 'cover',
              border: '4px solid #F5F8FC',
              boxShadow: '0 8px 18px rgba(0,0,0,.20)',
              flexShrink: 0,
              background: '#EAEEF5',
            }}
          />
        ) : (
          <div style={{
            width: 88, height: 88, borderRadius: '50%',
            background: gradientFor(card.theme),
            color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontWeight: 700, fontSize: 30, letterSpacing: .5,
            border: '4px solid #F5F8FC',
            boxShadow: '0 8px 18px rgba(0,0,0,.20)',
            flexShrink: 0,
          }}>{initials}</div>
        )}
        {contact?.languages && contact.languages.length > 0 && (
          <div style={{ fontSize: 12, color: '#5A6478', lineHeight: 1.4 }}>
            <div style={{
              fontSize: 10, fontWeight: 700, letterSpacing: .8,
              color: '#9AA3B5', textTransform: 'uppercase', marginBottom: 2,
            }}>Spricht</div>
            {contact.languages.join(' · ')}
          </div>
        )}
      </div>

      {/* Specialty pills */}
      {card.field_visibility.diveStats && card.dive_profile?.specialties && (
        <div style={{
          marginTop: 18,
          display: 'flex', flexWrap: 'wrap', gap: 6,
        }}>
          {card.dive_profile.specialties.map((spec) => (
            <span key={spec} style={pillStyle}>
              {spec}
            </span>
          ))}
        </div>
      )}

      {/* Dive stats */}
      {card.field_visibility.diveStats && card.dive_profile && (
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)',
          gap: 12, marginTop: 20, padding: '14px 0',
          borderTop: '1px solid #E3E8F2',
          borderBottom: '1px solid #E3E8F2',
        }}>
          {card.dive_profile.total_dives !== undefined && (
            <Stat label="Dives" value={card.dive_profile.total_dives.toLocaleString('de-CH')} />
          )}
          {card.dive_profile.since_year !== undefined && (
            <Stat label="Taucht seit" value={String(card.dive_profile.since_year)} />
          )}
          {card.dive_profile.instructor_level && (
            <Stat label="Level" value={card.dive_profile.instructor_level} />
          )}
        </div>
      )}

      {/* Action buttons */}
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
        gap: 8, marginTop: 20,
      }}>
        {showEmail && (
          <ActionButton
            label={t.emailMe} icon="✉"
            href={`mailto:${email}`}
            onClick={() => logFieldTap('email')}
          />
        )}
        {showPhone && (
          <ActionButton
            label={t.callMe} icon="📞"
            href={`tel:${phone}`}
            onClick={() => logFieldTap('phone')}
          />
        )}
        {showWhatsApp && (
          <ActionButton
            label={t.whatsapp} icon="💬"
            href={`https://wa.me/${(phone ?? '').replace(/[^\d]/g, '')}`}
            onClick={() => logFieldTap('whatsapp')}
          />
        )}
        <ActionButton
          label={t.addToContacts} icon="👤"
          onClick={() => downloadVCard({ fullName, email, phone, title: card.title })}
        />
      </div>

      {/* Lead form (wrapped for IntersectionObserver) */}
      <div ref={formRef} id="verbinden">
        <LeadForm card={card} onTap={() => logFieldTap('leadForm')} t={t} />
      </div>

      <a href="https://atoll-os.com" style={{
        marginTop: 40, textDecoration: 'none', color: '#9AA3B5',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        // Extra bottom-padding so the sticky CTA never covers the footer.
        paddingBottom: 80,
      }}>
        <img src="/atollcard-logo.png" alt="" style={{ width: 22, height: 22, opacity: 0.85 }}/>
        <span style={{ fontSize: 11, fontWeight: 500 }}>Erstellt mit AtollCard</span>
      </a>

      {/* Sticky mobile CTA — hidden ≥640px via the inline @media rule below. */}
      <style>{`
        @media (min-width: 640px) {
          .atoll-sticky-cta { display: none !important; }
        }
      `}</style>
      {showStickyCta && (
        <button
          className="atoll-sticky-cta"
          onClick={() => {
            document.getElementById('verbinden')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
          }}
          style={{
            position: 'fixed',
            bottom: 'calc(env(safe-area-inset-bottom, 0px) + 16px)',
            left: 16, right: 16,
            padding: '15px',
            borderRadius: 14,
            border: 'none',
            background: gradientFor(card.theme),
            color: 'white',
            fontSize: 15, fontWeight: 700, letterSpacing: 0.3,
            cursor: 'pointer',
            boxShadow: '0 8px 24px rgba(0,0,0,.22), 0 2px 6px rgba(0,0,0,.12)',
            zIndex: 50,
          }}>
          Verbinden
        </button>
      )}
    </div>
  )
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div style={{ fontSize: 20, fontWeight: 700, letterSpacing: -.4, lineHeight: 1 }}>{value}</div>
      <div style={{ fontSize: 11, fontWeight: 600, color: '#9AA3B5', textTransform: 'uppercase', marginTop: 4 }}>
        {label}
      </div>
    </div>
  )
}

function ActionButton({
  label, icon, href, onClick,
}: {
  label: string; icon: string; href?: string; onClick?: () => void
}) {
  const base: React.CSSProperties = {
    display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
    gap: 6, padding: '12px 4px', borderRadius: 16, background: 'white',
    border: '1px solid rgba(0,0,0,.05)', textDecoration: 'none', color: '#1A1F2E',
    fontSize: 11, fontWeight: 600, cursor: 'pointer',
    boxShadow: '0 2px 4px rgba(0,0,0,.04)',
  }
  if (href) {
    return (
      <a href={href} onClick={onClick} style={base}>
        <span style={{ fontSize: 20 }}>{icon}</span>
        <span>{label}</span>
      </a>
    )
  }
  return (
    <button onClick={onClick} style={{ ...base, font: 'inherit' }}>
      <span style={{ fontSize: 20 }}>{icon}</span>
      <span>{label}</span>
    </button>
  )
}

const pillStyle: React.CSSProperties = {
  padding: '6px 12px', borderRadius: 100, fontSize: 13, fontWeight: 500,
  background: '#DDE8F7', color: '#1E3A8A',
}

// ─── Lead form ────────────────────────────────────────────────────────

function LeadForm({ card, onTap, t }: { card: CardRow; onTap: () => void; t: Translations }) {
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [topic, setTopic] = useState('')
  const [message, setMessage] = useState('')
  const [status, setStatus] = useState<'idle' | 'submitting' | 'success' | 'error'>('idle')
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setStatus('submitting')
    onTap()
    try {
      const { error } = await supabase.from('card_leads').insert({
        card_id: card.id,
        first_name: firstName,
        last_name: lastName || null,
        email: email || null,
        phone: phone || null,
        topic: topic || null,
        message: message || null,
      })
      if (error) throw error
      setStatus('success')
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : String(err))
      setStatus('error')
    }
  }

  if (status === 'success') {
    return (
      <div style={{
        marginTop: 32, padding: 20, borderRadius: 18,
        background: '#D8EBD9', color: '#2D5A3A', textAlign: 'center',
      }}>
        <p style={{ margin: 0, fontSize: 15, fontWeight: 600 }}>{t.leadFormSuccess}</p>
      </div>
    )
  }

  return (
    <form onSubmit={submit} style={{
      marginTop: 32, padding: 18, borderRadius: 18,
      background: 'white', border: '1px solid rgba(0,0,0,.04)',
      boxShadow: '0 2px 8px rgba(0,0,0,.03)',
    }}>
      <div style={{
        fontSize: 11, fontWeight: 800, letterSpacing: .8, color: '#9AA3B5',
        textTransform: 'uppercase', marginBottom: 12,
      }}>Verbinden</div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 8 }}>
        <Field placeholder={`${t.leadFormFirstName} *`} value={firstName} onChange={setFirstName} required />
        <Field placeholder={t.leadFormLastName} value={lastName} onChange={setLastName} />
      </div>
      <Field placeholder={t.leadFormEmail} type="email" value={email} onChange={setEmail} style={{ marginBottom: 8 }} />
      <Field placeholder={t.leadFormPhone} type="tel" value={phone} onChange={setPhone} style={{ marginBottom: 8 }} />
      <Field placeholder={t.leadFormTopic} value={topic} onChange={setTopic} style={{ marginBottom: 8 }} />
      <textarea
        placeholder={t.leadFormMessage}
        value={message}
        onChange={(e) => setMessage(e.target.value)}
        style={{
          width: '100%', minHeight: 80, padding: '10px 12px', borderRadius: 10,
          border: '1px solid rgba(0,0,0,.08)', background: '#EAEEF5',
          fontFamily: 'inherit', fontSize: 14, resize: 'vertical', marginBottom: 12,
        }}
      />

      <button type="submit" disabled={status === 'submitting' || !firstName}
        style={{
          width: '100%', padding: '14px', borderRadius: 12, border: 'none',
          background: '#1A1F2E', color: 'white', fontSize: 15, fontWeight: 600,
          cursor: status === 'submitting' || !firstName ? 'not-allowed' : 'pointer',
          opacity: !firstName ? 0.5 : 1,
        }}>
        {status === 'submitting' ? t.leadFormSending : t.leadFormSubmit}
      </button>

      {status === 'error' && (
        <div style={{ marginTop: 10, fontSize: 12, color: '#8C2B3A' }}>
          {t.leadFormError}{errorMsg ? ` (${errorMsg})` : ''}
        </div>
      )}
    </form>
  )
}

function Field({
  placeholder, value, onChange, type = 'text', required, style,
}: {
  placeholder: string; value: string; onChange: (v: string) => void;
  type?: string; required?: boolean; style?: React.CSSProperties;
}) {
  return (
    <input
      type={type} placeholder={placeholder} value={value} required={required}
      onChange={(e) => onChange(e.target.value)}
      style={{
        width: '100%', padding: '10px 12px', borderRadius: 10,
        border: '1px solid rgba(0,0,0,.08)', background: '#EAEEF5',
        fontFamily: 'inherit', fontSize: 14, ...style,
      }}
    />
  )
}

// ─── vCard download ───────────────────────────────────────────────────

/// Builds a minimal vCard 3.0 blob and triggers a download. Works on iOS
/// Safari (which routes the .vcf into the Contacts app) and on desktop.
function downloadVCard({
  fullName, email, phone, title,
}: { fullName: string; email?: string | null; phone?: string | null; title: string }) {
  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `FN:${fullName}`,
    `TITLE:${title}`,
    email ? `EMAIL:${email}` : null,
    phone ? `TEL:${phone}` : null,
    'END:VCARD',
  ].filter(Boolean).join('\r\n')
  const blob = new Blob([lines], { type: 'text/vcard' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `${fullName.replace(/\s+/g, '_')}.vcf`
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}
