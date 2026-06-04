import Testing
import Foundation
@testable import AtollTalk

@MainActor @Suite struct VoiceDefaultsTests {
  @Test func voicesFallBackToHardwiredDefaults() {
    let d = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let s = SettingsStore(defaults: d)
    for lang in AppLanguage.allCases {
      #expect(s.voices[lang] == lang.defaultElevenVoiceID)
      #expect(!(s.voices[lang] ?? "").isEmpty)
    }
    #expect(s.voices[.fr] != s.voices[.de])   // French uses a distinct voice
  }
  @Test func overrideWinsOverDefault() {
    let d = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let s = SettingsStore(defaults: d)
    s.setVoiceID("custom-id", for: .de)
    #expect(s.voices[.de] == "custom-id")
    #expect(s.voices[.uk] == AppLanguage.uk.defaultElevenVoiceID)   // others unchanged
  }
}
