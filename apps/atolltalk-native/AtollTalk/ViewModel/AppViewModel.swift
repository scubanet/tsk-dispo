import Foundation
import Observation

@MainActor @Observable
final class AppViewModel {
  enum Phase: Equatable { case idle, recording, transcribing, translating, error(String) }

  private(set) var phase: Phase = .idle
  var pair = LanguagePair(a: .de, b: .uk)

  private let recorder: AudioRecorder
  private let speech: SpeechService
  private let translator: TranslationService
  private let synthesis: SynthesisService
  private let store: ConversationStore
  private let context: String
  private let glossaryLines: () -> String

  init(
    recorder: AudioRecorder,
    speech: SpeechService,
    translator: TranslationService,
    synthesis: SynthesisService,
    store: ConversationStore,
    context: String,
    glossaryLines: @escaping () -> String
  ) {
    self.recorder = recorder
    self.speech = speech
    self.translator = translator
    self.synthesis = synthesis
    self.store = store
    self.context = context
    self.glossaryLines = glossaryLines
  }

  func toggleRecording() async {
    switch phase {
    case .idle:      await startRecording()
    case .recording: await stopAndProcess()
    default:         break
    }
  }

  func startRecording() async {
    do { try await recorder.start(); phase = .recording }
    catch { phase = .error(Self.message(for: error)) }
  }

  func stopAndProcess() async {
    guard let wav = recorder.stop() else {
      phase = .error("Keine Aufnahme erkannt — bitte nochmal."); return
    }
    await process(wav: wav)
  }

  /// Testable core: transcribe → route → translate → persist.
  func process(wav: Data) async {
    phase = .transcribing
    do {
      let result = try await speech.transcribe(wav: wav)
      guard !result.text.isEmpty else {
        phase = .error("Nichts verstanden — bitte nochmal sprechen."); return
      }
      guard let detected = result.language,
            let route = LanguageRouter.route(detected: detected, in: pair) else {
        phase = .error("Sprache nicht erkannt oder nicht im Paar."); return
      }
      phase = .translating
      let translated = try await translator.translate(
        result.text, to: route.target, context: context, glossary: glossaryLines())
      store.add(Turn(
        sourceText: result.text, sourceLang: route.source,
        targetText: translated, targetLang: route.target))
      phase = .idle
    } catch {
      phase = .error(Self.message(for: error))
    }
  }

  func speak(_ turn: Turn) { synthesis.speak(turn.targetText, in: turn.targetLang) }

  static func message(for error: Error) -> String {
    if let e = error as? AudioRecorder.RecorderError {
      switch e {
      case .permissionDenied: return "Mikrofon-Zugriff fehlt. Bitte in den iOS-Einstellungen erlauben."
      case .inputUnavailable: return "Mikrofon ist nicht verfügbar."
      }
    }
    return "Ein Fehler ist aufgetreten: \(error.localizedDescription)"
  }

  func phaseResetToIdle() { if case .error = phase { phase = .idle } }
}
