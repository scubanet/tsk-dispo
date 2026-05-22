import Foundation
import AVFoundation
import TideSpeech

/// Captures microphone audio via `AVAudioEngine` and forwards each PCM
/// buffer to an injected `SpeechRecognizer`. The recognizer drives the
/// transcription; this class is just the audio-capture half.
///
/// Lifecycle:
///   1. `start()` — install a tap on the engine's input node, kick off
///      the recognizer, start the engine.
///   2. (audio flows) — tap callbacks call `recognizer.feed(_:)`.
///      `recognizer.partialTranscript` yields partials to subscribers.
///   3. `stop()` — stop the engine, remove the tap, finalize the
///      recognizer, return the final transcript.
@MainActor
final class AudioRecorder {
  private let engine = AVAudioEngine()
  private let recognizer: any SpeechRecognizer
  private var isRunning = false

  init(recognizer: any SpeechRecognizer) {
    self.recognizer = recognizer
  }

  /// Live transcript stream from the underlying recognizer. UI binds to
  /// this and shows partial results while the user is speaking.
  var partialTranscript: AsyncStream<String> {
    recognizer.partialTranscript
  }

  func start() async throws {
    guard !isRunning else { return }
    try await recognizer.start()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
      self?.recognizer.feed(buffer)
    }
    engine.prepare()
    try engine.start()
    isRunning = true
  }

  func stop() async throws -> String {
    guard isRunning else { return "" }
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    isRunning = false
    return try await recognizer.stop()
  }
}
