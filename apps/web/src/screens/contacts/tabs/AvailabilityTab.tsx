/**
 * AvailabilityTab — placeholder. Will be implemented in a later phase.
 */

import { useTranslation } from 'react-i18next'

interface Props {
  contactId: string
}

// contactId will be used when the tab is implemented
export function AvailabilityTab(_props: Props) {
  const { t } = useTranslation()
  return (
    <div className="contact-tab-body tab-stub">
      {t('contacts.availability_stub')}
    </div>
  )
}
