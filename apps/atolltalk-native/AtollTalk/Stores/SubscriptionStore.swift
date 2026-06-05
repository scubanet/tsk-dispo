import Foundation
import StoreKit
import Observation

/// StoreKit 2 entitlement source of truth. `isPro` drives the tier switch in
/// the composition root (`RootView.rebuild()`).
@MainActor @Observable
final class SubscriptionStore {
  private(set) var products: [Product] = []
  private(set) var isPro = false
  private let productIDs: Set<String>
  // Set once in init, cancelled in deinit (nonisolated). Not observed.
  @ObservationIgnored private nonisolated(unsafe) var updates: Task<Void, Never>?

  init(productIDs: Set<String> = ["swiss.atoll.talk.pro.monthly",
                                  "swiss.atoll.talk.pro.yearly",
                                  "swiss.atoll.talk.pro.lifetime"]) {  // Lifetime = Non-Consumable
    self.productIDs = productIDs
    updates = observeTransactions()
  }
  deinit { updates?.cancel() }

  func load() async {
    products = (try? await Product.products(for: productIDs)) ?? []
    await refreshEntitlements()
  }

  func purchase(_ product: Product) async throws {
    let result = try await product.purchase()
    if case let .success(verification) = result,
       case let .verified(transaction) = verification {
      await transaction.finish()
      await refreshEntitlements()
    }
  }

  func restore() async { try? await AppStore.sync(); await refreshEntitlements() }

  /// The signed transaction (JWS) for the active Pro entitlement, for the
  /// translate proxy to verify server-side. Nil when not Pro.
  func currentJWS() async -> String? {
    for await result in Transaction.currentEntitlements {
      if case let .verified(t) = result, productIDs.contains(t.productID),
         t.revocationDate == nil {
        return result.jwsRepresentation
      }
    }
    return nil
  }

  func refreshEntitlements() async {
    var active = false
    for await result in Transaction.currentEntitlements {
      if case let .verified(t) = result, productIDs.contains(t.productID),
         t.revocationDate == nil { active = true }
    }
    isPro = active
  }

  private func observeTransactions() -> Task<Void, Never> {
    Task { [weak self] in
      for await update in Transaction.updates {
        if case let .verified(t) = update { await t.finish() }
        await self?.refreshEntitlements()
      }
    }
  }
}
