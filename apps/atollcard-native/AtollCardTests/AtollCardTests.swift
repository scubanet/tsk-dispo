import Testing
@testable import AtollCard

@Suite("AtollCard smoke")
struct AtollCardSmokeTests {
  @Test func mockSeedHasThreeCards() throws {
    #expect(MockSeed.cards.count == 3)
  }

  @Test func defaultCardExists() throws {
    #expect(MockSeed.cards.contains(where: { $0.isDefault }))
  }

  @Test func cardPublicURLContainsSlug() throws {
    let card = MockSeed.cards.first!
    #expect(card.publicURL.absoluteString.contains(card.slug))
  }

  @Test func deterministicUUIDsAreStable() throws {
    #expect(MockSeed.uuid("test") == MockSeed.uuid("test"))
    #expect(MockSeed.uuid("a") != MockSeed.uuid("b"))
  }

  @Test func leadGroupingFindsToday() async throws {
    let store = await MainActor.run { LeadStore(repository: MockLeadRepository()) }
    await store.refresh()
    let sections = await store.groupedByDay()
    #expect(sections.contains(where: { $0.label == "HEUTE" }))
  }
}
