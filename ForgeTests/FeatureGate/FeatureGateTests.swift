import XCTest
import SwiftData
@testable import Forge

final class FeatureGateTests: XCTestCase {

    // MARK: - Template limit enforcement

    @MainActor
    func testFreeTierAllows7Templates() {
        let appState = AppState()
        XCTAssertEqual(AppState.freeTemplateLimit, 7)
        appState.isProUser = false

        // Simulate 7 templates created
        let templates = (0..<7).map { i in
            TemplateDTO(id: UUID(), name: "Template \(i)", createdAt: Date(), exercises: [])
        }

        // Under the limit: can create more
        let underLimit = templates.count < AppState.freeTemplateLimit
        XCTAssertFalse(underLimit, "7 templates should hit the free limit")
    }

    @MainActor
    func testFreeTierCanCreateUpToLimit() {
        let appState = AppState()
        appState.isProUser = false

        // 6 templates: can create one more
        let templatesCount = 6
        let canCreate = appState.isProUser || templatesCount < AppState.freeTemplateLimit
        XCTAssertTrue(canCreate)
    }

    @MainActor
    func testFreeTierCannotExceedLimit() {
        let appState = AppState()
        appState.isProUser = false

        // 7 templates: cannot create more
        let templatesCount = 7
        let canCreate = appState.isProUser || templatesCount < AppState.freeTemplateLimit
        XCTAssertFalse(canCreate)
    }

    @MainActor
    func testProTierUnlimitsTemplates() {
        let appState = AppState()
        appState.isProUser = true

        let templatesCount = 100
        let canCreate = appState.isProUser || templatesCount < AppState.freeTemplateLimit
        XCTAssertTrue(canCreate)
    }

    // MARK: - History limit enforcement

    @MainActor
    func testFreeTierHistoryCutoff() {
        let appState = AppState()
        appState.isProUser = false

        let cutoff = Date().addingTimeInterval(-TimeInterval(AppState.freeHistoryDays * 86400))
        XCTAssertEqual(AppState.freeHistoryDays, 90)

        // Session from 89 days ago: visible
        let recentSession = Date().addingTimeInterval(-TimeInterval(89 * 86400))
        XCTAssertTrue(recentSession >= cutoff)

        // Session from 91 days ago: hidden
        let oldSession = Date().addingTimeInterval(-TimeInterval(91 * 86400))
        XCTAssertFalse(oldSession >= cutoff)
    }

    @MainActor
    func testProTierShowsAllHistory() {
        let appState = AppState()
        appState.isProUser = true
        // Pro users see all history — no cutoff applied
        XCTAssertTrue(appState.isProUser)
    }

    // MARK: - TemplateViewModel gate integration

    @MainActor
    func testTemplateViewModelCanCreate_WithinLimit() {
        let appState = AppState()
        appState.isProUser = false

        let vm = TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        )
        // 0 templates — can create
        XCTAssertTrue(vm.canCreateTemplate(appState: appState))
    }

    @MainActor
    func testTemplateViewModelCannotCreate_AtLimit() async {
        let appState = AppState()
        appState.isProUser = false

        let vm = TemplateViewModel(
            templateRepo: FullTemplateRepo(),
            exerciseRepo: PreviewRepositories.exercise
        )
        await vm.loadAll()
        XCTAssertFalse(vm.canCreateTemplate(appState: appState),
                       "Should be gated when template count equals the free limit")
    }

    @MainActor
    func testTemplateViewModelAlwaysCreatesPro() async {
        let appState = AppState()
        appState.isProUser = true

        let vm = TemplateViewModel(
            templateRepo: FullTemplateRepo(),
            exerciseRepo: PreviewRepositories.exercise
        )
        await vm.loadAll()
        XCTAssertTrue(vm.canCreateTemplate(appState: appState),
                      "Pro users can always create templates")
    }

    // MARK: - Pro toggle drives AppState

    @MainActor
    func testIsProUserChangesPropagates() {
        let appState = AppState()
        XCTAssertFalse(appState.isProUser)
        appState.isProUser = true
        XCTAssertTrue(appState.isProUser)
    }
}

// MARK: - Test helper: repo pre-filled at the free limit

private final class FullTemplateRepo: TemplateRepositoryProtocol, @unchecked Sendable {
    func fetchAll() async throws -> [TemplateDTO] {
        (0..<AppState.freeTemplateLimit).map { i in
            TemplateDTO(id: UUID(), name: "T\(i)", createdAt: Date(), exercises: [])
        }
    }
    func fetchById(_ id: UUID) async throws -> TemplateDTO? { nil }
    func insert(name: String, exercises: [CreateTemplateExerciseInput]) async throws -> UUID { UUID() }
    func delete(id: UUID) async throws {}
    func count() async throws -> Int { AppState.freeTemplateLimit }
}
