import Foundation
import Observation

@MainActor @Observable
final class AppViewModel {
  enum Phase: Equatable { case idle, recording, transcribing, translating, error(String) }

  private(set) var phase: Phase = .idle

  private let recorder: AudioRecorder
  private let speech: SpeechService
  private let translator: any Translator
  private let synthesis: SynthesisService
  private let store: ConversationStore
  private let context: String
  private let glossaryLines: () -> String
  private let pairProvider: () -> LanguagePair

  /// The active language pair, read live (so header changes take effect
  /// without rebuilding the view model).
  var pair: LanguagePair { pairProvider() }

  init(
    recorder: AudioRecorder,
    speech: SpeechService,
    translator: any Translator,
    synthesis: SynthesisService,
    store: ConversationStore,
    context: String,
    glossaryLines: @escaping () -> String,
    pair: @escaping () -> LanguagePair
  ) {
    self.recorder = recorder
    self.speech = speech
    self.translator = translator
    self.synthesis = synthesis
    self.store = store
    self.context = context
    self.glossaryLines = glossaryLines
    self.pairProvider = pair
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
      phase = .error(String(localized: "Keine Aufnahme erkannt — bitte nochmal.")); return
    }
    await process(wav: wav)
  }

  /// Testable core: transcribe → route → translate → persist.
  func process(wav: Data) async {
    phase = .transcribing
    do {
      let result = try await speech.transcribe(wav: wav)
      guard !result.text.isEmpty else {
        phase = .error(String(localized: "Nichts verstanden — bitte nochmal sprechen.")); return
      }
      guard let detected = result.language,
            let route = LanguageRouter.route(detected: detected, in: pair) else {
        phase = .error(String(localized: "Sprache nicht erkannt oder nicht im Paar.")); return
      }
      phase = .translating
      let translated = try await translator.translate(
        result.text, from: route.source, to: route.target,
        context: context, glossary: glossaryLines())
      store.add(Turn(
        sourceText: result.text, sourceLang: route.source,
        targetText: translated, targetLang: route.target))
      phase = .idle
    } catch {
      phase = .error(Self.message(for: error))
    }
  }

  func speak(_ turn: Turn) {
    if !synthesis.speak(turn.targetText, in: turn.targetLang) {
      phase = .error(String(localized: "Keine Stimme für \(turn.targetLang.displayName) verfügbar. In den Einstellungen eine ElevenLabs-Stimme hinterlegen oder eine Apple-Stimme für diese Sprache installieren."))
    }
  }

  func clearConversation() {
    do { try store.clear() }
    catch { phase = .error(Self.message(for: error)) }
  }

  static func message(for error: Error) -> String {
    if let e = error as? AudioRecorder.RecorderError {
      switch e {
      case .permissionDenied: return String(localized: "Mikrofon-Zugriff fehlt. Bitte in den iOS-Einstellungen erlauben.")
      case .inputUnavailable: return String(localized: "Mikrofon ist nicht verfügbar.")
      }
    }
    return String(localized: "Ein Fehler ist aufgetreten: \(error.localizedDescription)")
  }

  func phaseResetToIdle() { if case .error = phase { phase = .idle } }
}
