import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/types/supabase'

const url = import.meta.env.VITE_SUPABASE_URL
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !anon) {
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY')
}

// Generated schema types (regenerate via `supabase gen types typescript --project-id axnrilhdokkfujzjifhj`
// or via the Supabase MCP `generate_typescript_types` tool when the schema changes).
export const supabase = createClient<Database>(url, anon, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    // PKCE flow is the modern, recommended OAuth flow for SPAs.
    // Replaces the older `implicit` flow which exposed tokens via URL fragment.
    // Reference: https://supabase.com/docs/guides/auth/sessions/pkce-flow
    flowType: 'pkce',
  },
})
