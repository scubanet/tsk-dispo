import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class StoreManager {

    static let shared = StoreManager()

    static let instructorProID = "com.weckherlin.DiveLogPro.instructorPro"

    private(set) var instructorProduct: Product?
    private(set) var isPro: Bool = false
    private(set) var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task(priority: .background) { [weak self] in
            for await verificationResult in Transaction.updates {
                await self?.handle(verificationResult)
            }
        }
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    nonisolated deinit {
    }

    // MARK: - Load products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.instructorProID])
            instructorProduct = products.first
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Purchase

    func buyInstructorPro() async {
        guard let product = instructorProduct else { return }
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        for await verificationResult in Transaction.currentEntitlements {
            if case .verified(let tx) = verificationResult,
               tx.productID == Self.instructorProID,
               tx.revocationDate == nil {
                isPro = true
                return
            }
        }
        isPro = false
    }

    // MARK: - Handle transaction

    private func handle(_ verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = verificationResult else { return }
        if tx.productID == Self.instructorProID {
            isPro = tx.revocationDate == nil
        }
        await tx.finish()
    }
}
