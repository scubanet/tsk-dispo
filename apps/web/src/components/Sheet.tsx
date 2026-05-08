/**
 * Sheet — thin compatibility wrapper around the Foundation `Drawer`.
 *
 * All edit sheets (CourseEditSheet, AssignmentEditSheet, StudentEditSheet,
 * EnrollStudentSheet, CertificationEditSheet, CommunicationEditSheet,
 * IntakeChecklistSheet, OrganizationEditSheet, CorrectionSheet, …) import
 * `Sheet` from here. Routing them through Foundation `Drawer` gives every
 * sheet the same backdrop, slide-in animation, body-scroll lock, ESC-close,
 * focus trap and soft scrollbar — without touching each individual sheet.
 *
 * Behavior preserved from the legacy implementation:
 *   - `open` / `onClose` semantics
 *   - `width` prop (default 520 — matches the legacy default)
 *   - `title` rendered in the drawer header
 *   - Children rendered inside the scrollable body
 */

import type { ReactNode } from 'react'
import { Drawer } from '@/foundation'

interface SheetProps {
  open: boolean
  onClose: () => void
  title: string
  width?: number
  children: ReactNode
}

export function Sheet({ open, onClose, title, width = 520, children }: SheetProps) {
  return (
    <Drawer open={open} onClose={onClose} title={title} width={width}>
      {children}
    </Drawer>
  )
}
