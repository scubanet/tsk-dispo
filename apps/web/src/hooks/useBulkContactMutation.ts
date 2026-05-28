// apps/web/src/hooks/useBulkContactMutation.ts
//
// Phase G Phase 4 Task 7 — Bulk-Mutationen für die AddressbookBulkActionBar.
//
// Discriminated-Union BulkAction. Eine einzige useMutation switch-cased auf
// action.type — das hält Caller-Code knapp (`mutation.mutate({type:'archive', ids})`).
//
// add_tags: N+1-Approach (SELECT existing tags, UPDATE pro Contact mit merged-set).
// Bulk-Tag-Operationen sind selten genug, dass das ok ist. Phase 4.x-Carry-Forward:
// echter `bulk_append_tags(ids[], tags[])` Postgres-RPC für 1-Roundtrip.
//
// onSuccess invalidiert ['contacts'] (Listen-Cache) sowie ['contact-properties']
// (Detail-Panel), damit aktuell offene Sidebar-Properties direkt nachziehen.
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export type BulkAction =
  | { type: 'add_tags'; ids: string[]; tags: string[] }
  | { type: 'set_pipeline_stage'; ids: string[]; stage: string }
  | { type: 'archive'; ids: string[] }
  | { type: 'set_active'; ids: string[]; active: boolean }

async function runAddTags(ids: string[], tags: string[]) {
  if (ids.length === 0 || tags.length === 0) return
  // Hol bestehende tags per Contact, merge dedupliziert, UPDATE pro Contact.
  // Eine echte SQL-RPC würde das in einem Roundtrip schaffen — Carry-Forward.
  const { data, error } = await supabase
    .from('contacts')
    .select('id, tags')
    .in('id', ids)
  if (error) throw new Error(error.message)

  const existingMap = new Map<string, string[]>()
  for (const row of (data ?? []) as Array<{ id: string; tags: string[] | null }>) {
    existingMap.set(row.id, row.tags ?? [])
  }

  for (const id of ids) {
    const existing = existingMap.get(id) ?? []
    const merged = Array.from(new Set([...existing, ...tags]))
    const { error: updErr } = await supabase
      .from('contacts')
      .update({ tags: merged })
      .eq('id', id)
    if (updErr) throw new Error(updErr.message)
  }
}

async function runSetPipelineStage(ids: string[], stage: string) {
  if (ids.length === 0) return
  const { error } = await supabase
    .from('contact_student')
    .update({ pipeline_stage: stage })
    .in('contact_id', ids)
  if (error) throw new Error(error.message)
}

async function runArchive(ids: string[]) {
  if (ids.length === 0) return
  const { error } = await supabase
    .from('contacts')
    .update({ archived_at: new Date().toISOString() })
    .in('id', ids)
  if (error) throw new Error(error.message)
}

async function runSetActive(ids: string[], active: boolean) {
  if (ids.length === 0) return
  const { error } = await supabase
    .from('contact_instructor')
    .update({ active })
    .in('contact_id', ids)
  if (error) throw new Error(error.message)
}

export function useBulkContactMutation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (action: BulkAction) => {
      switch (action.type) {
        case 'add_tags':
          await runAddTags(action.ids, action.tags)
          return
        case 'set_pipeline_stage':
          await runSetPipelineStage(action.ids, action.stage)
          return
        case 'archive':
          await runArchive(action.ids)
          return
        case 'set_active':
          await runSetActive(action.ids, action.active)
          return
      }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contacts'] })
      qc.invalidateQueries({ queryKey: ['contact-properties'] })
    },
  })
}
