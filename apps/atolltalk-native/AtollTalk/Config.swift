import Foundation

enum Config {
  static let appName = "AtollTalk"

  // Claude (Anthropic) models
  static let defaultModel = "claude-sonnet-4-6"
  static let fastModel    = "claude-haiku-4-5-20251001"

  /// Free-tier fair-use: max Basic translations per day before the paywall.
  static let basicDailyLimit = 20

  /// On-device glossary post-processing of the Basic (Apple MT) translation via
  /// FoundationModels. Off by default until verified on an Apple Intelligence device.
  static let glossaryRefinementEnabled = false

  // ElevenLabs — no key in the app. STT/TTS go through the `speech` Edge
  // Function (key server-side). Model ids are pinned there too; the client
  // constants remain only as protocol-default mirrors.
  static let scribeModelID    = "scribe_v1"
  static let ttsModelID       = "eleven_multilingual_v2"

  /// Speech proxy (Supabase Edge Function `speech`): /stt + /tts/<voiceID>.
  static let speechProxyURL = URL(string:
    "https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/speech")!

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
