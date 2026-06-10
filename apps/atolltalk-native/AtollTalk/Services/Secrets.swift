import Foundation

// No in-app secrets remain:
// - ElevenLabs key → server-side in the Supabase `speech` function
//   (⚠️ rotate the key at ElevenLabs: the old one is in git history, 542d7dd)
// - Claude/Anthropic key → server-side in Supabase translate function
