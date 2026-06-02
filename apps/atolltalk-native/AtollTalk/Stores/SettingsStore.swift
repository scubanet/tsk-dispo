import Foundation
import Observation

@MainActor @Observable
final class SettingsStore {
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    model     = defaults.string(forKey: "model") ?? Config.defaultModel
    voiceDE   = defaults.string(forKey: "voice.de") ?? ""
    voiceUK   = defaults.string(forKey: "voice.uk") ?? ""
    context   = defaults.string(forKey: "context") ?? Config.defaultContext
  }

  var model: String   { didSet { defaults.set(model, forKey: "model") } }
  var voiceDE: String { didSet { defaults.set(voiceDE, forKey: "voice.de") } }
  var voiceUK: String { didSet { defaults.set(voiceUK, forKey: "voice.uk") } }
  var context: String { didSet { defaults.set(context, forKey: "context") } }

  var voices: [AppLanguage: String] { [.de: voiceDE, .uk: voiceUK] }
  var modelOptions: [String] { [Config.defaultModel, Config.fastModel] }
}
