import Foundation

enum Config {
  static let appName = "AtollTalk"

  // Claude (Anthropic) models
  static let defaultModel = "claude-sonnet-4-6"
  static let fastModel    = "claude-haiku-4-5-20251001"

  // ElevenLabs
  static let scribeModelID = "scribe_v1"            // open point #1: confirm Scribe v2 id
  static let ttsModelID    = "eleven_multilingual_v2"

  /// Pro translation proxy (Supabase Edge Function). Holds the Claude key
  /// server-side; the app never ships it. Replace <project-ref> after deploy.
  static let translateProxyURL = URL(string:
    "https://YOUR-PROJECT-REF.supabase.co/functions/v1/translate")!

  /// Default translation context (editable later in Settings).
  static let defaultContext = """
  Du übersetzt ein lockeres, gesprochenes Gespräch in einer Restaurantküche \
  zwischen Dominik (Deutsch, spricht oft Schweizerdeutschen Dialekt) und einer \
  Küchenhilfe, die eine andere Sprache spricht. Der deutsche Input kann \
  Schweizerdeutsch sein und vom Transkriptions-System fehlerhaft erfasst werden \
  — interpretiere sinngemäss. Übersetze natürlich und umgangssprachlich, nicht \
  wörtlich. Gib NUR die Übersetzung aus — ohne Anführungszeichen, ohne Erklärungen.
  """
}
