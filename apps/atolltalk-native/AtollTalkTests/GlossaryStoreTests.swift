import Testing
import Foundation
@testable import AtollTalk

@MainActor @Suite struct GlossaryStoreTests {
  @Test func addPersistsAndRendersPromptLines() {
    let defaults = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let pair = LanguagePair(a: .de, b: .uk)
    let store = GlossaryStore(defaults: defaults)
    store.add(for: pair) { $0 == .de ? "Maria" : "Марія" }
    store.add(for: pair) { $0 == .de ? "Schnittlauch" : "Цибуля-різанець" }
    #expect(store.entries(for: pair).count == 2)

    let reopened = GlossaryStore(defaults: defaults)
    #expect(reopened.entries(for: pair).count == 2)
    #expect(reopened.promptLines(for: pair).contains("Maria ↔ Марія"))
  }

  @Test func glossariesAreScopedPerPair() {
    let defaults = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let store = GlossaryStore(defaults: defaults)
    store.add(for: LanguagePair(a: .de, b: .en)) { $0 == .de ? "Teller" : "plate" }
    store.add(for: LanguagePair(a: .en, b: .tl)) { $0 == .en ? "plate" : "plato" }
    #expect(store.entries(for: LanguagePair(a: .de, b: .en)).count == 1)
    #expect(store.entries(for: LanguagePair(a: .de, b: .ceb)).isEmpty)
    #expect(store.promptLines(for: LanguagePair(a: .de, b: .en)).contains("Teller"))
    // Other pair's terms don't leak in.
    #expect(store.promptLines(for: LanguagePair(a: .de, b: .en)).contains("plato") == false)
  }

  @Test func pairIsOrderIndependent() {
    let defaults = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let store = GlossaryStore(defaults: defaults)
    store.add(for: LanguagePair(a: .de, b: .en)) { $0 == .de ? "Teller" : "plate" }
    // Same pair, reversed order → same glossary.
    #expect(store.entries(for: LanguagePair(a: .en, b: .de)).count == 1)
    #expect(store.promptLines(for: LanguagePair(a: .en, b: .de)).contains("Teller ↔ plate"))
  }

  @Test func settingsAutoSwapPreventsSameLanguageBothSides() {
    let defaults = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let s = SettingsStore(defaults: defaults)   // defaults: de / uk
    s.langA = .uk                               // == langB → must swap
    #expect(s.langA == .uk)
    #expect(s.langB == .de)
    s.langB = .uk                               // == langA → must swap back
    #expect(s.langB == .uk)
    #expect(s.langA == .de)
  }
}
