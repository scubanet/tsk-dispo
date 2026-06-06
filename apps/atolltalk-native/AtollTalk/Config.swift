import Foundation

enum Config {
  static let appName = "AtollTalk"

  // Claude (Anthropic) models
  static let defaultModel = "claude-sonnet-4-6"
  static let fastModel    = "claude-haiku-4-5-20251001"

  /// Free-tier fair-use: max Basic translations per day before the paywall.
  static let basicDailyLimit = 20

  // ElevenLabs — key baked in (rate-limit in ElevenLabs dashboard as mitigation).
  // TODO before public launch: proxy STT+TTS through Supabase like translate.
  static let elevenLabsAPIKey = "sk_ed54b69b6f7e8ddd7434f87940769f2f17dd88b65944ef5e"
  static let scribeModelID    = "scribe_v1"
  static let ttsModelID       = "eleven_multilingual_v2"

  /// Pro translation proxy (Supabase Edge Function). Holds the Claude key
  /// server-side; the app never ships it. Replace <project-ref> after deploy.
  static let translateProxyURL = URL(string:
    "https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/translate")!

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
