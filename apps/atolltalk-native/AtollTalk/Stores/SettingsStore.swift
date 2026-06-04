import Foundation
import Observation

@MainActor @Observable
final class SettingsStore {
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    model    = defaults.string(forKey: "model") ?? Config.defaultModel
    context  = defaults.string(forKey: "context") ?? Config.defaultContext
    langA    = AppLanguage(rawValue: defaults.string(forKey: "lang.a") ?? "") ?? .de
    langB    = AppLanguage(rawValue: defaults.string(forKey: "lang.b") ?? "") ?? .uk

    if let data = defaults.data(forKey: "voiceIDs"),
       let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
      voiceIDs = decoded.reduce(into: [:]) { acc, kv in
        if let lang = AppLanguage(rawValue: kv.key) { acc[lang] = kv.value }
      }
    } else {
      // Migrate legacy per-language keys, if present.
      var seed: [AppLanguage: String] = [:]
      if let de = defaults.string(forKey: "voice.de"), !de.isEmpty { seed[.de] = de }
      if let uk = defaults.string(forKey: "voice.uk"), !uk.isEmpty { seed[.uk] = uk }
      voiceIDs = seed
    }
  }

  var model: String   { didSet { defaults.set(model, forKey: "model") } }
  var context: String { didSet { defaults.set(context, forKey: "context") } }
  // Auto-swap: picking a language already on the other side swaps the two,
  // so the pair is never A==B (which would be a pointless self-translation).
  var langA: AppLanguage {
    didSet {
      defaults.set(langA.rawValue, forKey: "lang.a")
      if langA == langB { langB = oldValue }
    }
  }
  var langB: AppLanguage {
    didSet {
      defaults.set(langB.rawValue, forKey: "lang.b")
      if langB == langA { langA = oldValue }
    }
  }

  var voiceIDs: [AppLanguage: String] { didSet { persistVoices() } }

  var pair: LanguagePair { LanguagePair(a: langA, b: langB) }
  var voices: [AppLanguage: String] { voiceIDs }
  var modelOptions: [String] { [Config.defaultModel, Config.fastModel] }

  func voiceID(for lang: AppLanguage) -> String { voiceIDs[lang] ?? "" }
  func setVoiceID(_ id: String, for lang: AppLanguage) {
    if id.isEmpty { voiceIDs[lang] = nil } else { voiceIDs[lang] = id }
  }

  private func persistVoices() {
    let raw = voiceIDs.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value }
    if let data = try? JSONEncoder().encode(raw) { defaults.set(data, forKey: "voiceIDs") }
  }
}
