import Foundation

/// Abstraction over the speech backend. Two implementations:
/// `ElevenLabsClient` (direct API access — dev/tests) and
/// `ProxySpeechClient` (AtollTalk `speech` Edge Function — production,
/// keeps the ElevenLabs key server-side).
public protocol SpeechBackend: Sendable {
  /// Transcribe WAV audio via Scribe. Returns transcript + detected language.
  func transcribe(audioData: Data, modelID: String) async throws
    -> ElevenLabsClient.Transcription

  /// Synthesise `text` with the given voice. Returns MP3 bytes.
  func synthesize(text: String, voiceID: String, modelID: String) async throws -> Data
}

public extension SpeechBackend {
  /// Default TTS model — mirrors `ElevenLabsClient`'s default.
  func synthesize(text: String, voiceID: String) async throws -> Data {
    try await synthesize(text: text, voiceID: voiceID, modelID: "eleven_multilingual_v2")
  }
}

extension ElevenLabsClient: SpeechBackend {}
