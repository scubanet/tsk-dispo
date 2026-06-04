import Foundation
import Observation

@MainActor @Observable
final class SettingsStore {
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    model    = defaults.string(forKey: "model") ?? Config.defaultModel
    context  = defaults.string(forKey: "context") ?? Config.defaultContext
    hasConsented = defaults.bool(forKey: "hasConsented")
    basicUsageDay   = defaults.string(forKey: "basicUsageDay") ?? ""
    basicUsageCount = defaults.integer(forKey: "basicUsageCount")
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
  /// User agreed to cloud processing (Scribe STT, Claude, ElevenLabs). Required
  /// before any cloud call (App Review policy, since 2025-11-13).
  var hasConsented: Bool { didSet { defaults.set(hasConsented, forKey: "hasConsented") } }

  private var basicUsageDay: String   { didSet { defaults.set(basicUsageDay, forKey: "basicUsageDay") } }
  private var basicUsageCount: Int    { didSet { defaults.set(basicUsageCount, forKey: "basicUsageCount") } }

  private static func todayKey() -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
  }

  /// Basic translations used today (auto-resets on a new day).
  func basicUsageToday() -> Int { basicUsageDay == Self.todayKey() ? basicUsageCount : 0 }

  /// Count one Basic translation against today's fair-use quota.
  func bumpBasicUsage() {
    let today = Self.todayKey()
    if basicUsageDay != today { basicUsageDay = today; basicUsageCount = 0 }
    basicUsageCount += 1
  }
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
  var modelOptions: [String] { [Config.defaultModel, Config.fastModel] }

  /// Effective voices for synthesis: per-language override, else hardwired default.
  var voices: [AppLanguage: String] {
    Dictionary(uniqueKeysWithValues: AppLanguage.allCases.map { ($0, effectiveVoiceID(for: $0)) })
  }

  /// The override the user typed (empty when none) — for the editable field.
  func voiceID(for lang: AppLanguage) -> String { voiceIDs[lang] ?? "" }

  /// Override if set, otherwise the hardwired default.
  func effectiveVoiceID(for lang: AppLanguage) -> String {
    let override = voiceIDs[lang] ?? ""
    return override.isEmpty ? lang.defaultElevenVoiceID : override
  }
  func setVoiceID(_ id: String, for lang: AppLanguage) {
    if id.isEmpty { voiceIDs[lang] = nil } else { voiceIDs[lang] = id }
  }

  private func persistVoices() {
    let raw = voiceIDs.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value }
    if let data = try? JSONEncoder().encode(raw) { defaults.set(data, forKey: "voiceIDs") }
  }
}
