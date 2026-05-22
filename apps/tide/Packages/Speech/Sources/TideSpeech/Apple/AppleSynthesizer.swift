import Foundation
import AVFoundation
import OSLog

private let log = Logger(subsystem: "swiss.weckherlin.tide", category: "tts")

/// `Synthesizer` backed by `AVSpeechSynthesizer`. Voice defaults to a
/// German voice; pass a different identifier to switch. Queue-style
/// behaviour is inherited from AVSpeechSynthesizer — repeated `speak(_:)`
/// calls append utterances rather than interrupting.
public final class AppleSynthesizer: NSObject, Synthesizer, @unchecked Sendable {
  private let synth = AVSpeechSynthesizer()
  private let voiceIdentifier: String

  public init(voiceIdentifier: String = "com.apple.voice.compact.de-DE.Anna") {
    self.voiceIdentifier = voiceIdentifier
    super.init()
  }

  public var isSpeaking: Bool { synth.isSpeaking }

  public func speak(_ text: String) {
    guard !text.isEmpty else { return }
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
      ?? AVSpeechSynthesisVoice(language: "de-DE")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    log.debug("speak(\(text.count, privacy: .public) chars)")
    synth.speak(utterance)
  }

  public func stop() {
    log.debug("stop")
    synth.stopSpeaking(at: .immediate)
  }
}
