// apps/web/src/hooks/useContactFieldMutation.ts
//
// Phase G Phase 3 — Generic single-field-update mutation for Contact + Sidecars.
// `contacts`-Table verwendet `id` als FK, Sidecars verwenden `contact_id`.
// Auf Erfolg invalidiert die `['contact-properties', contactId]` Query damit
// die UI neu lädt.
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

const ID_COLUMN_FOR: Record<string, string> = {
  contacts: 'id',
  // Sidecars (Phase F1 schema) use contact_id as FK
  contact_instructor: 'contact_id',
  contact_student: 'contact_id',
  contact_organization: 'contact_id',
}

interface MutationInput {
  table: string
  field: string
  value: unknown
}

export function useContactFieldMutation(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ table, field, value }: MutationInput) => {
      const idColumn = ID_COLUMN_FOR[table] ?? 'contact_id'
      const { error } = await supabase
        .from(table)
        .update({ [field]: value })
        .eq(idColumn, contactId)
      if (error) throw new Error(error.message)
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-properties', contactId] })
    },
  })
}
