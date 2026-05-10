/**
 * NotesAndDocsTab — placeholder (coming soon).
 *
 * Notes are available on the Overview tab. Full document management
 * will be implemented in a later iteration.
 */

import { useTranslation } from 'react-i18next'

export function NotesAndDocsTab() {
  const { t } = useTranslation()
  return (
    <div className="contact-tab-body tab-stub">
      {t('contacts.notes_coming_soon')}
    </div>
  )
}
