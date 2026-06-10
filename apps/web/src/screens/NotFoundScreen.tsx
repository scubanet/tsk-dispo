/**
 * NotFoundScreen — 404 inside the AppShell.
 *
 * Replaces the old silent `Navigate to="/heute"` catch-all that made
 * broken links invisible (Status-Review 2026-06-10, Bug #2).
 */

import { useNavigate, useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { PageHeader, EmptyState, Icon } from '@/foundation'

export function NotFoundScreen() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { pathname } = useLocation()

  return (
    <div className="atoll-screen">
      <PageHeader title={t('notfound.title')} />
      <div className="atoll-screen__body">
        <EmptyState
          icon={<Icon.Info size={20} />}
          title={t('notfound.heading')}
          body={<><span className="mono">{pathname}</span> — {t('notfound.body')}</>}
          action={{ label: t('notfound.back'), onClick: () => navigate('/heute') }}
        />
      </div>
    </div>
  )
}
