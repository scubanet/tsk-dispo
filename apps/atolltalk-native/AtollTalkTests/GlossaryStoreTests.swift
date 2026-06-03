import Testing
import Foundation
@testable import AtollTalk

@MainActor @Suite struct GlossaryStoreTests {
  @Test func addPersistsAndRendersPromptLines() {
    let defaults = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let store = GlossaryStore(defaults: defaults)
    store.add(de: "Maria", uk: "Марія")
    store.add(de: "Schnittlauch", uk: "Цибуля-різанець")
    #expect(store.entries.count == 2)

    let reopened = GlossaryStore(defaults: defaults)
    #expect(reopened.entries.count == 2)
    #expect(reopened.promptLines().contains("Maria ↔ Марія"))
  }
}
