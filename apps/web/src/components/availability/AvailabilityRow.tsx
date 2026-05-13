/**
 * AvailabilityRow — Einzelner Eintrag mit Kind-Pill, Zeitraum, Notiz, Delete.
 * Wird sowohl im MyProfileScreen (TL/DM-Self-Service) als auch im
 * AvailabilityTab (Dispatcher-Sicht) verwendet.
 */

import { useTranslation } from 'react-i18next'
import { Pill, Icon, dateMedium } from '@/foundation'
import { supabase } from '@/lib/supabase'
import type { AvailabilityRow as AvailabilityRowData } from '@/lib/queries'

interface Props {
  row: AvailabilityRowData
  onDeleted: () => void
}

export function AvailabilityRow({ row, onDeleted }: Props) {
  const { t } = useTranslation()
  const tone =
    row.kind === 'urlaub' ? 'brand' :
    row.kind === 'abwesend' ? 'warning' :
    'success'

  async function del() {
    if (!confirm(t('my_profile.confirm_delete', { kind: t(`my_profile.kind_${row.kind}`) }))) return
    await supabase.from('availability').delete().eq('id', row.id)
    onDeleted()
  }

  return (
    <div className="atoll-myprofile__avail-row">
      <Pill tone={tone} size="sm">{t(`my_profile.kind_${row.kind}`)}</Pill>
      <div className="atoll-myprofile__avail-body">
        <div className="atoll-myprofile__avail-date tabular-nums">
          {dateMedium(row.from_date)}
          {row.from_date !== row.to_date && ` – ${dateMedium(row.to_date)}`}
        </div>
        {row.note && <div className="atoll-myprofile__avail-note">{row.note}</div>}
      </div>
      <button
        type="button"
        className="atoll-iconbtn"
        onClick={del}
        title={t('common.delete')}
        aria-label={t('common.delete')}
      >
        <Icon.Close size={14} />
      </button>
    </div>
  )
}
