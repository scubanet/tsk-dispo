import Testing
import SwiftData
@testable import AtollTalk

@MainActor @Suite struct ConversationStoreTests {
  @Test func addPersistsAndFetchesNewestFirst() throws {
    let container = try ModelContainer(
      for: Turn.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let store = ConversationStore(context: container.mainContext)
    store.add(Turn(sourceText: "Hallo", sourceLang: .de, targetText: "Привіт", targetLang: .uk))
    let turns = try store.allNewestFirst()
    #expect(turns.count == 1)
    #expect(turns.first?.targetText == "Привіт")
    #expect(turns.first?.targetLang == .uk)
  }
}
