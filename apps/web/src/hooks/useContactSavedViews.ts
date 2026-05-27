// apps/web/src/hooks/useContactSavedViews.ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { ContactSavedView, SavedViewInput } from '@/types/contactEvents'

const QK = ['contact-saved-views']

/** Liste aller eigenen Saved Views (RLS scoped auf user_id). */
export function useContactSavedViews() {
  return useQuery({
    queryKey: QK,
    queryFn: async (): Promise<ContactSavedView[]> => {
      const { data, error } = await supabase
        .from('contact_saved_views')
        .select('*')
        .order('created_at', { ascending: false })
      if (error) throw new Error(error.message)
      return (data ?? []) as ContactSavedView[]
    },
  })
}

/** View speichern. user_id wird via RLS-WITH-CHECK aus auth.uid() validiert. */
export function useCreateSavedView() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (input: SavedViewInput): Promise<ContactSavedView> => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) throw new Error('not authenticated')
      const { data, error } = await supabase
        .from('contact_saved_views')
        .insert({ ...input, user_id: user.id })
        .select('*')
        .single()
      if (error) throw new Error(error.message)
      return data as ContactSavedView
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: QK }),
  })
}

/** View löschen. */
export function useDeleteSavedView() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (viewId: string): Promise<void> => {
      const { error } = await supabase
        .from('contact_saved_views')
        .delete()
        .eq('id', viewId)
      if (error) throw new Error(error.message)
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: QK }),
  })
}
