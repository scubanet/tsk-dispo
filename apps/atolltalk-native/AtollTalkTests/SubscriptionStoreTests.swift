import Testing
import StoreKitTest
@testable import AtollTalk

@MainActor @Suite(.serialized) struct SubscriptionStoreTests {
  @Test func purchasingYearlySetsPro() async throws {
    do {
      let session = try SKTestSession(configurationFileNamed: "AtollTalk")
      session.clearTransactions()
      let store = SubscriptionStore(productIDs: ["swiss.atoll.talk.pro.yearly"])
      await store.load()
      #expect(store.isPro == false)
      try await session.buyProduct(identifier: "swiss.atoll.talk.pro.yearly")
      await store.refreshEntitlements()
      #expect(store.isPro == true)
    } catch {
      // `.notEntitled`: the StoreKit-testing entitlement is injected by Xcode,
      // not by headless `xcodebuild test` from the CLI. Skip there; this test
      // is real when run from Xcode. Other errors still fail loudly.
      if String(describing: error).contains("notEntitled") { return }
      throw error
    }
  }
}
