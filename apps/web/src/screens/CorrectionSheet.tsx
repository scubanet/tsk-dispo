import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CHDateField } from '@/components/CHFields'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { useActiveInstructors } from '@/hooks/useActiveInstructors'
import {
  useAccountMovement,
  useInsertCorrection,
  useUpdateAccountMovement,
  useDeleteAccountMovement,
} from '@/hooks/useCorrection'
import { chf } from '@/lib/format'

type Kind = 'korrektur' | 'übertrag'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  /** Pre-select an instructor when opening from their detail panel */
  defaultInstructorId?: string
  /** If set: edit-mode for an existing movement. Only 'korrektur' or 'übertrag' allowed. */
  movementId?: string | null
}

const inputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)',
  color: 'var(--ink)',
  font: 'inherit',
  fontSize: 13.5,
  width: '100%',
}

export function CorrectionSheet({ open, onClose, onSaved, defaultInstructorId, movementId }: Props) {
  const { t } = useTranslation()
  const isEdit = !!movementId

  const { data: instructorRows = [] } = useActiveInstructors()
  const instructors = useMemo(
    () => instructorRows.map(({ id, name, padi_level }) => ({ id, name, padi_level })),
    [instructorRows],
  )
  const { data: existingMovement, error: loadError } = useAccountMovement(
    open && movementId ? movementId : null,
  )
  const insertMutation = useInsertCorrection()
  const updateMutation = useUpdateAccountMovement()
  const deleteMutation = useDeleteAccountMovement()
  const saving = insertMutation.isPending || updateMutation.isPending
  const deleting = deleteMutation.isPending

  const [instructorId, setInstructorId] = useState(defaultInstructorId ?? '')
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10))
  const [amount, setAmount] = useState('')
  const [description, setDescription] = useState('')
  const [kind, setKind] = useState<Kind>('korrektur')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(loadError ? loadError.message : null)

    if (!movementId) {
      // CREATE mode: reset to defaults.
      setInstructorId(defaultInstructorId ?? '')
      setDate(new Date().toISOString().slice(0, 10))
      setAmount('')
      setDescription('')
      setKind('korrektur')
      return
    }

    // EDIT mode: hydrate from cached movement.
    if (!existingMovement) return
    if (existingMovement.kind !== 'korrektur' && existingMovement.kind !== 'übertrag') {
      setError(t('correction.only_corrections_editable'))
      return
    }
    setInstructorId(existingMovement.instructor_id)
    setDate(existingMovement.date)
    setAmount(String(existingMovement.amount_chf))
    setDescription(existingMovement.description ?? '')
    setKind(existingMovement.kind as Kind)
  }, [open, movementId, defaultInstructorId, existingMovement, loadError, t])

  async function save() {
    setError(null)
    const num = Number(amount.replace(',', '.'))
    if (isNaN(num) || num === 0) {
      setError(t('correction.error_amount_zero'))
      return
    }
    if (!description.trim()) {
      setError(t('correction.error_reason_required'))
      return
    }

    const payload = {
      instructor_id: instructorId,
      date,
      amount_chf: num,
      description: description.trim(),
    }

    try {
      if (movementId) {
        await updateMutation.mutateAsync({ movementId, input: payload })
      } else {
        await insertMutation.mutateAsync(payload)
      }
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  async function remove() {
    if (!movementId) return
    if (!confirm(t('correction.confirm_delete'))) return
    setError(null)
    try {
      await deleteMutation.mutateAsync(movementId)
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  const previewAmount = Number(amount.replace(',', '.'))
  const title = isEdit
    ? (kind === 'übertrag' ? t('correction.title_edit_carryover') : t('correction.title_edit_correction'))
    : t('correction.title_new')

  return (
    <Sheet open={open} onClose={onClose} title={title}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div className="caption">
          {isEdit ? (
            <>{t('correction.edit_intro_prefix')} <code>{kind}</code>{t('correction.edit_intro_suffix')}</>
          ) : (
            t('correction.new_intro')
          )}
        </div>

        <div>
          <Label>{t('assignment_edit.label_person')}</Label>
          <select
            value={instructorId}
            onChange={(e) => setInstructorId(e.target.value)}
            style={inputStyle}
            disabled={isEdit}
          >
            <option value="">— {t('course_edit.choose')} —</option>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
            ))}
          </select>
        </div>

        <div>
          <Label>{t('correction.label_date')}</Label>
          <CHDateField
            value={date}
            onChange={setDate}
            style={inputStyle}
          />
        </div>

        <div>
          <Label>{t('correction.label_amount')}</Label>
          <input
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder={t('correction.amount_placeholder')}
            style={{ ...inputStyle, fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace' }}
          />
          {!isNaN(previewAmount) && previewAmount !== 0 && (
            <div className="caption-2" style={{ marginTop: 'var(--space-1)' }}>
              {t('correction.preview')}: <strong style={{ color: previewAmount < 0 ? '#FF3B30' : 'inherit' }}>{chf(previewAmount)}</strong>
            </div>
          )}
        </div>

        <div>
          <Label>{t('correction.label_reason')}</Label>
          <input
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder={t('correction.reason_placeholder')}
            style={inputStyle}
          />
        </div>

        {error && (
          <div className="chip-orange" style={{ padding: 'var(--space-3)', borderRadius: 12, display: 'flex', gap: 'var(--space-2)', alignItems: 'flex-start', fontSize: 13 }}>
            <Icon name="bell" size={16} /> {error}
          </div>
        )}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          {isEdit && (
            <button
              type="button"
              className="btn-danger btn"
              onClick={remove}
              disabled={saving || deleting}
            >
              <Icon name="x" size={14} /> {deleting ? t('correction.deleting') : t('common.delete')}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || deleting || !instructorId || !amount || !description.trim()}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : (isEdit ? t('common.save') : t('instructor_detail.book_correction'))}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 'var(--space-1)' }}>{children.toUpperCase()}</div>
}
