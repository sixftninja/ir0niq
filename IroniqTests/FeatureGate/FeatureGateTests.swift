import XCTest
import SwiftData
@testable import Ironiq

/// Pro feature gating has been removed. All features are free.
/// These tests verify that template creation is always permitted.
final class FeatureGateTests: XCTestCase {

    @MainActor
    func testAllFeaturesAreFree_CanAlwaysCreateTemplates() {
        let appState = AppState()
        let vm = TemplateViewModel(
            templateRepo: PreviewRepositories.template,
            exerciseRepo: PreviewRepositories.exercise
        )
        XCTAssertTrue(vm.canCreateTemplate(appState: appState))
    }

    @MainActor
    func testAllFeaturesAreFree_CanCreateManyTemplates() async {
        let appState = AppState()
        let vm = TemplateViewModel(
            templateRepo: FullTemplateRepo(),
            exerciseRepo: PreviewRepositories.exercise
        )
        await vm.loadAll()
        // Even with many templates, can always create more
        XCTAssertTrue(vm.canCreateTemplate(appState: appState))
    }

    @MainActor
    func testSessionsPerWeekTargetDefault() {
        let appState = AppState()
        XCTAssertGreaterThan(appState.sessionsPerWeekTarget, 0)
        XCTAssertLessThanOrEqual(appState.sessionsPerWeekTarget, 14)
    }
}

private final class FullTemplateRepo: TemplateRepositoryProtocol, @unchecked Sendable {
    private let limit = 100
    func fetchAll() async throws -> [TemplateDTO] {
        (0..<limit).map { i in TemplateDTO(id: UUID(), name: "T\(i)", createdAt: Date(), exercises: []) }
    }
    func fetchById(_ id: UUID) async throws -> TemplateDTO? { nil }
    func insert(name: String, exercises: [CreateTemplateExerciseInput]) async throws -> UUID { UUID() }
    func update(id: UUID, name: String, exercises: [CreateTemplateExerciseInput]) async throws {}
    func appendExercise(templateId: UUID, exercise: CreateTemplateExerciseInput) async throws {}
    func delete(id: UUID) async throws {}
    func count() async throws -> Int { limit }
    func hasAssociatedSessions(id: UUID) async throws -> Bool { false }
}
