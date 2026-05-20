import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY

if (!url || !anon) {
  throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY')
}

// Generated schema types live at `@/types/supabase` (regenerate via Supabase MCP
// `generate_typescript_types` or `supabase gen types typescript --project-id axnrilhdokkfujzjifhj`
// when the schema changes). Binding `<Database>` to the client surfaces latent type
// errors across queries.ts / contactQueries.ts that the existing `as unknown as` casts
// hide today — too many to fix in one PR. Adoption path: import the types per-call
// where new code wants strict typing.
//
//   import type { Database } from '@/types/supabase'
//   type CourseRow = Database['public']['Tables']['courses']['Row']
//
// Once queries.ts is refactored to use generated types, swap to
// `createClient<Database>(...)` here.
export const supabase = createClient(url, anon, {
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
