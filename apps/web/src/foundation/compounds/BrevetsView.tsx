/**
 * BrevetsView — 4-group display of a person's certifications.
 *
 * Groups, in order:
 *   1. Diver Brevets       (SCUBA_DIVER, OWD, AOWD, RESCUE_DIVER, MASTER_SCUBA_DIVER)
 *   2. Pro Brevets         (DM, OWSI, IDC_STAFF, MI, CD)
 *   3. Specialty Teacher   (SPEC_TEACHER_*)
 *   4. Additional Certs    (EFRI, EFR, MEDICAL)
 *
 * Within each group: sorted by issued_at descending (newest first).
 * Invalidated certs render with reduced opacity + strikethrough.
 *
 * Foundation rules:
 *   - Section dividers use small-caps.
 *   - Each cert is a Pill row with code, number, and issue date.
 *   - Empty groups render an EmptyState micro-message ("Keine Diver-Brevets").
 */

import type { Certification, CertCategory } from '@/types/foundation'
import { dateMedium } from '../lib/dates'
import { Pill } from '../components/Pill'
import './BrevetsView.css'

export interface BrevetsViewProps {
  certifications: Certification[]
  /** Optional click handler — invoked with the cert id when a row is clicked. */
  onCertClick?: (certId: string) => void
}

const GROUPS: { id: CertCategory; label: string; emptyText: string }[] = [
  { id: 'diver', label: 'Diver-Brevets', emptyText: 'Keine Diver-Brevets erfasst.' },
  { id: 'pro', label: 'Pro-Brevets', emptyText: 'Keine Pro-Brevets erfasst.' },
  { id: 'specialty-teacher', label: 'Specialty-Teacher', emptyText: 'Keine Specialty-Teacher-Permits.' },
  { id: 'additional', label: 'Weitere Brevets', emptyText: 'Keine weiteren Brevets.' },
]

export function BrevetsView({ certifications, onCertClick }: BrevetsViewProps) {
  return (
    <div className="atoll-brevets">
      {GROUPS.map((group) => {
        const items = certifications
          .filter((c) => c.category === group.id)
          .sort((a, b) => b.issuedAt.localeCompare(a.issuedAt))

        return (
          <section key={group.id} className="atoll-brevets__group">
            <h3 className="atoll-brevets__group-title small-caps">{group.label}</h3>
            {items.length === 0 ? (
              <div className="atoll-brevets__empty">{group.emptyText}</div>
            ) : (
              <ul className="atoll-brevets__list">
                {items.map((cert) => (
                  <li key={cert.id} className="atoll-brevets__item">
                    <button
                      type="button"
                      className={`atoll-brevets__row${cert.invalidatedAt ? ' atoll-brevets__row--invalidated' : ''}`}
                      onClick={() => onCertClick?.(cert.id)}
                      disabled={!onCertClick}
                    >
                      <Pill tone={categoryTone(cert.category)} size="sm">
                        {cert.code}
                      </Pill>
                      <span className="atoll-brevets__agency">{cert.agency}</span>
                      {cert.number && cert.number !== '—' && (
                        <span className="atoll-brevets__number mono">{cert.number}</span>
                      )}
                      <span className="atoll-brevets__date tabular-nums">
                        {dateMedium(cert.issuedAt)}
                      </span>
                      {cert.invalidatedAt && (
                        <span className="atoll-brevets__invalidated">Ungültig</span>
                      )}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </section>
        )
      })}
    </div>
  )
}

function categoryTone(cat: CertCategory) {
  switch (cat) {
    case 'diver': return 'brand'
    case 'pro': return 'pro'
    case 'specialty-teacher': return 'success'
    case 'additional': return 'warning'
  }
}
