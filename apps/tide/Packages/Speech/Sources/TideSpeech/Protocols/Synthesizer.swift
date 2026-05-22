import Foundation

/// Text-to-speech abstraction. Implementations are expected to be
/// thread-safe — `speak(_:)` can be called from any context (typically
/// from the streaming-LLM token loop on MainActor). The implementation
/// queues utterances internally.
public protocol Synthesizer: Sendable {
  /// Queue `text` for playback. Returns immediately. Speech happens
  /// asynchronously on the audio output.
  func speak(_ text: String)

  /// Cancel any queued or in-flight utterances.
  func stop()

  /// Whether playback is currently active. Useful for UI toggles.
  var isSpeaking: Bool { get }
}
