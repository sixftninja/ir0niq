import Foundation
import Observation
import StoreKit

// MARK: - Protocol (for testability)
// Note: isPurchasing is not in protocol — it's @MainActor isolated and read directly from the concrete type in UI

protocol StoreKitServiceProtocol: AnyObject, Sendable {
  func initialize(appState: AppState) async
  func purchase(appState: AppState) async throws -> Bool
  func restorePurchases(appState: AppState) async
}

// MARK: - Errors

enum StoreError: Error, LocalizedError, Equatable {
  case productNotFound
  case purchaseFailed
  case verificationFailed

  var errorDescription: String? {
    switch self {
    case .productNotFound: return "Ironiq Pro is currently unavailable."
    case .purchaseFailed: return "Purchase could not be completed."
    case .verificationFailed: return "Purchase verification failed."
    }
  }
}

// MARK: - Production implementation

@MainActor
@Observable
final class StoreKitService: StoreKitServiceProtocol, @unchecked Sendable {

  nonisolated static let proProductId = "com.ir0niq.app.pro"
  static let shared = StoreKitService()

  private(set) var proProduct: Product? = nil
  private(set) var isPurchasing = false

  private var transactionTask: Task<Void, Never>? = nil

  private init() {}

  // MARK: - Lifecycle

  func initialize(appState: AppState) async {
    await loadProduct()
    await checkEntitlement(appState: appState)
    startListeningForTransactions(appState: appState)
  }

  private func loadProduct() async {
    do {
      let products = try await Product.products(for: [Self.proProductId])
      proProduct = products.first
    } catch {
      // Products unavailable (e.g. simulator without StoreKit config) — non-fatal
    }
  }

  // MARK: - Purchase

  func purchase(appState: AppState) async throws -> Bool {
    guard let product = proProduct else { throw StoreError.productNotFound }

    isPurchasing = true
    defer { isPurchasing = false }

    let result = try await product.purchase()

    switch result {
    case .success(let verificationResult):
      switch verificationResult {
      case .verified(let transaction):
        await transaction.finish()
        _ = appState  // Pro removed; purchase no longer gates features
        return true
      case .unverified:
        throw StoreError.verificationFailed
      }
    case .pending:
      return false  // Payment pending external approval (e.g. Ask to Buy)
    case .userCancelled:
      return false
    @unknown default:
      return false
    }
  }

  // MARK: - Restore

  func restorePurchases(appState: AppState) async {
    do {
      try await AppStore.sync()
    } catch {
      // Sync errors are non-fatal — checkEntitlement will report the truth
    }
    await checkEntitlement(appState: appState)
  }

  // MARK: - Entitlement check

  func checkEntitlement(appState: AppState) async {
    let currentEntitlement = await Transaction.currentEntitlement(for: Self.proProductId)
    switch currentEntitlement {
    case .verified(let transaction):
      _ = transaction.revocationDate  // Pro removed
    default:
      break
    }
  }

  // MARK: - Transaction listener

  private func startListeningForTransactions(appState: AppState) {
    transactionTask?.cancel()
    transactionTask = Task { @MainActor in
      for await update in Transaction.updates {
        switch update {
        case .verified(let transaction):
          if transaction.productID == Self.proProductId {
            if transaction.revocationDate == nil {
              _ = appState  // Pro removed; purchase no longer gates features
            } else {
              await self.checkEntitlement(appState: appState)
            }
            await transaction.finish()
          }
        case .unverified:
          break
        }
      }
    }
  }
}
