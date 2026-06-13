import XCTest
@testable import Ironiq

/// StoreKit IAP has been removed — all features are free.
final class StoreKitServiceTests: XCTestCase {

    @MainActor
    func testAllFeaturesAvailableWithoutPurchase() {
        let appState = AppState()
        let vm = TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        )
        XCTAssertTrue(vm.canCreateTemplate(appState: appState))
    }
}
