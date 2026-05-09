/**
 * MergeContactsSheet — Drawer for the merge-contacts workflow.
 *
 * Stages:
 *   1. Search & select the loser contact
 *   2. Side-by-side preview of winner vs loser
 *   3. Confirm & execute merge
 */

import { useState, useEffect, useCallback } from 'react'
import { Drawer } from '@/foundation/layouts/Drawer'
import { listContacts, getContactWithSidecars, mergeContacts } from '@/lib/contactQueries'
import type { Contact, ContactWithSidecars } from '@/types/contacts'

interface Props {
  winnerId: string
  open: boolean
  onClose: () => void
  onMerged: () => void
}

export function MergeContactsSheet({ winnerId, open, onClose, onMerged }: Props) {
  const [search, setSearch] = useState('')
  const [results, setResults] = useState<Contact[]>([])
  const [searching, setSearching] = useState(false)

  const [loserId, setLoserId] = useState<string | null>(null)
  const [winner, setWinner] = useState<ContactWithSidecars | null>(null)
  const [loser, setLoser] = useState<ContactWithSidecars | null>(null)
  const [loadingPreview, setLoadingPreview] = useState(false)

  const [merging, setMerging] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Reset state when sheet opens/closes
  useEffect(() => {
    if (!open) {
      setSearch('')
      setResults([])
      setLoserId(null)
      setWinner(null)
      setLoser(null)
      setError(null)
    }
  }, [open])

  // Search contacts when search text changes
  useEffect(() => {
    if (search.length < 2) {
      setResults([])
      return
    }
    let cancelled = false
    setSearching(true)
    listContacts({ searchText: search }, 0, 20)
      .then(({ rows }) => {
        if (!cancelled) {
          // Exclude the winner from results
          setResults(rows.filter((c) => c.id !== winnerId))
        }
      })
      .catch(() => { /* silent */ })
      .finally(() => { if (!cancelled) setSearching(false) })
    return () => { cancelled = true }
  }, [search, winnerId])

  // Fetch both contacts when loser is selected
  const loadPreview = useCallback(() => {
    if (!loserId) return
    setLoadingPreview(true)
    setError(null)
    Promise.all([
      getContactWithSidecars(winnerId),
      getContactWithSidecars(loserId),
    ])
      .then(([w, l]) => {
        setWinner(w)
        setLoser(l)
      })
      .catch((err) => setError(err instanceof Error ? err.message : 'Fehler beim Laden'))
      .finally(() => setLoadingPreview(false))
  }, [winnerId, loserId])

  useEffect(() => {
    if (loserId) loadPreview()
  }, [loserId, loadPreview])

  async function handleMerge() {
    if (!loserId) return
    if (!window.confirm(
      'Sicher? Die Verschmelzung migriert alle FK-Referenzen (Kurse, Saldo, Kommunikation, Beziehungen) auf den Gewinner-Kontakt und archiviert den Verlierer. Dieser Vorgang kann nicht rückgängig gemacht werden.'
    )) return

    setMerging(true)
    setError(null)
    try {
      await mergeContacts(winnerId, loserId)
      onMerged()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Verschmelzen')
    } finally {
      setMerging(false)
    }
  }

  const drawerWidth = typeof window !== 'undefined' ? Math.round(window.innerWidth * 0.8) : 900

  return (
    <Drawer
      open={open}
      onClose={onClose}
      title="Mit anderem Kontakt verschmelzen"
      width={drawerWidth}
      ariaLabel="Kontakte verschmelzen"
    >
      <div style={{ padding: 'var(--space-5)', display: 'flex', flexDirection: 'column', gap: 'var(--space-5)' }}>
        {error && (
          <div style={{ color: 'var(--brand-red)', fontSize: 'var(--text-body)' }}>{error}</div>
        )}

        {/* Stage 1: Search */}
        {!loserId && (
          <section>
            <h2 style={{ fontSize: 'var(--text-h3)', color: 'var(--text-secondary)', marginBottom: 'var(--space-3)', fontWeight: 'var(--weight-medium)' }}>
              Zu verschmelzenden Kontakt suchen
            </h2>
            <input
              type="search"
              placeholder="Name oder E-Mail eingeben…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{
                width: '100%',
                padding: 'var(--space-2) var(--space-3)',
                fontSize: 'var(--text-body)',
                border: '1px solid var(--border-secondary)',
                borderRadius: 'var(--radius-sm)',
                fontFamily: 'var(--font-sans)',
                boxSizing: 'border-box',
              }}
              autoFocus
            />
            {searching && (
              <div style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-label)', marginTop: 'var(--space-2)' }}>
                Suche…
              </div>
            )}
            {results.length > 0 && (
              <ul style={{ listStyle: 'none', margin: 'var(--space-2) 0 0', padding: 0, border: '1px solid var(--border-secondary)', borderRadius: 'var(--radius-sm)', overflow: 'hidden' }}>
                {results.map((c) => (
                  <li key={c.id}>
                    <button
                      type="button"
                      onClick={() => setLoserId(c.id)}
                      style={{
                        display: 'block',
                        width: '100%',
                        textAlign: 'left',
                        padding: 'var(--space-3)',
                        background: 'none',
                        border: 'none',
                        borderBottom: '1px solid var(--border-tertiary)',
                        cursor: 'pointer',
                        fontFamily: 'var(--font-sans)',
                        fontSize: 'var(--text-body)',
                        color: 'var(--text-primary)',
                      }}
                    >
                      <strong>{c.display_name}</strong>
                      {c.primary_email && (
                        <span style={{ color: 'var(--text-tertiary)', marginLeft: 'var(--space-2)' }}>
                          {c.primary_email}
                        </span>
                      )}
                      <span style={{ color: 'var(--text-tertiary)', marginLeft: 'var(--space-2)', fontSize: 'var(--text-label)' }}>
                        {c.kind === 'organization' ? 'Organisation' : 'Person'}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
            {search.length >= 2 && !searching && results.length === 0 && (
              <div style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-label)', marginTop: 'var(--space-2)' }}>
                Keine Ergebnisse.
              </div>
            )}
          </section>
        )}

        {/* Stage 2+3: Preview + confirm */}
        {loserId && (
          <>
            <button
              type="button"
              onClick={() => { setLoserId(null); setWinner(null); setLoser(null) }}
              style={{ alignSelf: 'flex-start', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--brand-blue)', fontSize: 'var(--text-label)', padding: 0 }}
            >
              ← Andere Auswahl
            </button>

            {loadingPreview && (
              <div style={{ color: 'var(--text-tertiary)' }}>Lade Vorschau…</div>
            )}

            {winner && loser && !loadingPreview && (
              <>
                <div className="merge-preview">
                  <div className="merge-side">
                    <div style={{ fontSize: 'var(--text-meta)', color: 'var(--brand-teal)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 'var(--space-2)', fontWeight: 'var(--weight-medium)' }}>
                      Gewinner (bleibt erhalten)
                    </div>
                    <ContactPreview contact={winner} />
                  </div>
                  <div className="merge-side">
                    <div style={{ fontSize: 'var(--text-meta)', color: 'var(--brand-red)', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 'var(--space-2)', fontWeight: 'var(--weight-medium)' }}>
                      Verlierer (wird archiviert)
                    </div>
                    <ContactPreview contact={loser} />
                  </div>
                </div>

                <p style={{ fontSize: 'var(--text-body)', color: 'var(--text-secondary)', background: 'var(--brand-amber-50)', border: '1px solid var(--brand-amber-100)', borderRadius: 'var(--radius-sm)', padding: 'var(--space-3)', margin: 0 }}>
                  <strong>Hinweis:</strong> Die Verschmelzung migriert alle FK-Referenzen (Kurse, Saldo, Kommunikation, Beziehungen) auf den Gewinner-Kontakt und archiviert den Verlierer. Dieser Vorgang kann nicht rückgängig gemacht werden.
                </p>

                <div style={{ display: 'flex', gap: 'var(--space-3)' }}>
                  <button type="button" className="contact-action-btn" onClick={onClose}>Abbrechen</button>
                  <button
                    type="button"
                    className="contact-action-btn contact-action-btn--primary"
                    onClick={handleMerge}
                    disabled={merging}
                    style={{ background: 'var(--brand-red)', borderColor: 'var(--brand-red)' }}
                  >
                    {merging ? 'Verschmelzen…' : 'Verschmelzen'}
                  </button>
                </div>
              </>
            )}
          </>
        )}
      </div>
    </Drawer>
  )
}

function ContactPreview({ contact }: { contact: ContactWithSidecars }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
      <div style={{ fontSize: 'var(--text-h3)', fontWeight: 'var(--weight-medium)', color: 'var(--text-primary)' }}>
        {contact.display_name}
      </div>
      {contact.primary_email && (
        <div style={{ fontSize: 'var(--text-body)', color: 'var(--text-secondary)' }}>
          {contact.primary_email}
        </div>
      )}
      <div style={{ fontSize: 'var(--text-label)', color: 'var(--text-tertiary)' }}>
        {contact.kind === 'organization' ? 'Organisation' : 'Person'}
      </div>
      {contact.roles.length > 0 && (
        <div style={{ fontSize: 'var(--text-label)', color: 'var(--text-tertiary)' }}>
          Rollen: {contact.roles.join(', ')}
        </div>
      )}
    </div>
  )
}
