import Foundation

enum Config {
  static let appName = "AtollTalk"

  // Claude (Anthropic) models
  static let defaultModel = "claude-sonnet-4-6"
  static let fastModel    = "claude-haiku-4-5-20251001"

  // ElevenLabs
  static let scribeModelID = "scribe_v1"            // open point #1: confirm Scribe v2 id
  static let ttsModelID    = "eleven_multilingual_v2"

  /// Default translation context (editable later in Settings).
  static let defaultContext = """
  Du übersetzt ein lockeres, gesprochenes Gespräch in einer Restaurantküche \
  zwischen Dominik (Deutsch) und seiner Küchenhilfe Maria (Ukrainisch). \
  Übersetze natürlich und umgangssprachlich, nicht wörtlich. Gib NUR die \
  Übersetzung aus — ohne Anführungszeichen, ohne Erklärungen.
  """
}
