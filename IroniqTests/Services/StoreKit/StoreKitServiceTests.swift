import XCTest

@testable import Ironiq

final class StoreKitServiceTests: XCTestCase {

  // MARK: - MockStoreKitService for testing gate logic

  @MainActor
  final class MockStoreKitService: StoreKitServiceProtocol, @unchecked Sendable {

    var purchaseResult: Bool = true
    var purchaseError: Error? = nil
    var checkEntitlementResult = false

    var didInitialize = false
    var didPurchase = false
    var didRestore = false

    func initialize(appState: AppState) async {
      didInitialize = true
      appState.isProUser = checkEntitlementResult
    }

    func purchase(appState: AppState) async throws -> Bool {
      if let error = purchaseError { throw error }
      didPurchase = true
      if purchaseResult { appState.isProUser = true }
      return purchaseResult
    }

    func restorePurchases(appState: AppState) async {
      didRestore = true
      appState.isProUser = checkEntitlementResult
    }
  }

  // MARK: - Tests

  @MainActor
  func testInitializeChecksEntitlement() async {
    let mock = MockStoreKitService()
    mock.checkEntitlementResult = true
    let appState = AppState()
    await mock.initialize(appState: appState)
    XCTAssertTrue(mock.didInitialize)
    XCTAssertTrue(appState.isProUser, "AppState.isProUser should reflect entitlement result")
  }

  @MainActor
  func testInitializeNoEntitlement() async {
    let mock = MockStoreKitService()
    mock.checkEntitlementResult = false
    let appState = AppState()
    await mock.initialize(appState: appState)
    XCTAssertFalse(appState.isProUser)
  }

  @MainActor
  func testSuccessfulPurchaseSetsProUser() async throws {
    let mock = MockStoreKitService()
    mock.purchaseResult = true
    let appState = AppState()
    XCTAssertFalse(appState.isProUser)
    let result = try await mock.purchase(appState: appState)
    XCTAssertTrue(result)
    XCTAssertTrue(appState.isProUser)
  }

  @MainActor
  func testFailedPurchaseDoesNotSetProUser() async throws {
    let mock = MockStoreKitService()
    mock.purchaseResult = false
    let appState = AppState()
    let result = try await mock.purchase(appState: appState)
    XCTAssertFalse(result)
    XCTAssertFalse(appState.isProUser)
  }

  @MainActor
  func testPurchaseErrorPropagates() async {
    let mock = MockStoreKitService()
    mock.purchaseError = StoreError.productNotFound
    let appState = AppState()
    do {
      _ = try await mock.purchase(appState: appState)
      XCTFail("Expected error")
    } catch StoreError.productNotFound {
      // Expected
    } catch {
      XCTFail("Wrong error: \(error)")
    }
  }

  @MainActor
  func testRestoreCallsDelegate() async {
    let mock = MockStoreKitService()
    mock.checkEntitlementResult = true
    let appState = AppState()
    await mock.restorePurchases(appState: appState)
    XCTAssertTrue(mock.didRestore)
    XCTAssertTrue(appState.isProUser)
  }

  // MARK: - StoreError

  func testStoreErrorDescriptions() {
    XCTAssertNotNil(StoreError.productNotFound.errorDescription)
    XCTAssertNotNil(StoreError.purchaseFailed.errorDescription)
    XCTAssertNotNil(StoreError.verificationFailed.errorDescription)
  }

  func testStoreErrorEquality() {
    XCTAssertEqual(StoreError.productNotFound, StoreError.productNotFound)
    XCTAssertNotEqual(StoreError.productNotFound, StoreError.purchaseFailed)
  }

  // MARK: - Product ID

  func testProductIdConstant() {
    XCTAssertEqual(StoreKitService.proProductId, "com.ir0niq.app.pro")
  }
}
