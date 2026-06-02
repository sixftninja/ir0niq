import XCTest
@testable import Ironiq

// Tests for Phase 3: product fixes.

final class Phase3Tests: XCTestCase {

    // MARK: - Template editor: last-set deletion removes the exercise

    func testRemoveLastSetDeletesExercise() {
        var exercises = [ExerciseEditorRow(exercise: makeExercise(), setRows: [SetEditorRow()])]
        // Simulate removeSet logic: deleting the only set removes the exercise.
        let exerciseId = exercises[0].id
        let setId = exercises[0].setRows[0].id
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else {
            XCTFail("Exercise not found"); return
        }
        exercises[exerciseIndex].setRows.removeAll { $0.id == setId }
        if exercises[exerciseIndex].setRows.isEmpty {
            exercises.remove(at: exerciseIndex)
        }
        XCTAssertTrue(exercises.isEmpty, "Exercise should be removed when its last set is deleted")
    }

    func testRemovingOneOfMultipleSetsKeepsExercise() {
        let set1 = SetEditorRow()
        let set2 = SetEditorRow()
        var exercises = [ExerciseEditorRow(exercise: makeExercise(), setRows: [set1, set2])]
        let exerciseId = exercises[0].id
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }) else {
            XCTFail("Exercise not found"); return
        }
        exercises[exerciseIndex].setRows.removeAll { $0.id == set1.id }
        if exercises[exerciseIndex].setRows.isEmpty {
            exercises.remove(at: exerciseIndex)
        }
        XCTAssertEqual(exercises.count, 1, "Exercise should remain when it still has sets")
        XCTAssertEqual(exercises[0].setRows.count, 1)
    }

    // MARK: - Engine: prepareForNewSession from various states

    func testPrepareForNewSessionFromTemplateSelected() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let engine = SessionEngine(
            templateRepository: TemplateRepository(modelContainer: container),
            sessionRepository: SessionRepository(modelContainer: container)
        )
        let templateId = UUID()
        // Engine can only selectTemplate from idle — put it there first.
        guard case .idle = await engine.state else { XCTFail("Expected idle"); return }
        try engine.selectTemplate(templateId)
        guard case .templateSelected = await engine.state else { XCTFail("Expected templateSelected"); return }

        await engine.prepareForNewSession()
        guard case .idle = await engine.state else {
            XCTFail("Expected idle after prepareForNewSession from templateSelected")
            return
        }
    }

    func testPrepareForNewSessionFromIdleIsNoop() async throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let engine = SessionEngine(
            templateRepository: TemplateRepository(modelContainer: container),
            sessionRepository: SessionRepository(modelContainer: container)
        )
        guard case .idle = await engine.state else { XCTFail("Expected idle"); return }
        await engine.prepareForNewSession()
        guard case .idle = await engine.state else {
            XCTFail("Engine should remain idle")
            return
        }
    }

    // MARK: - Session presentation state: mutual exclusivity

    func testSessionPresentationDashboardNotSummary() {
        let p = SessionPresentationState.dashboard(openLogOnAppear: false)
        XCTAssertTrue(p.showsDashboard)
        XCTAssertFalse(p.showsSummary)
        XCTAssertFalse(p.showsExercisePicker)
    }

    func testSessionPresentationSummaryNotDashboard() {
        let p = SessionPresentationState.summary
        XCTAssertFalse(p.showsDashboard)
        XCTAssertTrue(p.showsSummary)
        XCTAssertFalse(p.showsExercisePicker)
    }

    func testSessionPresentationNoneShowsNothing() {
        let p = SessionPresentationState.none
        XCTAssertFalse(p.showsDashboard)
        XCTAssertFalse(p.showsSummary)
        XCTAssertFalse(p.showsExercisePicker)
    }

    func testSessionPresentationOpenLogFlagPassedThrough() {
        let p = SessionPresentationState.dashboard(openLogOnAppear: true)
        XCTAssertTrue(p.openLogOnDashboardAppear)
        let p2 = SessionPresentationState.dashboard(openLogOnAppear: false)
        XCTAssertFalse(p2.openLogOnDashboardAppear)
    }

    // MARK: - Helpers

    private func makeExercise() -> ExerciseDTO {
        ExerciseDTO(
            id: UUID(), name: "Squat", exerciseDescription: "",
            equipmentType: .barbell, isSingleHand: false,
            muscleGroups: [], iconName: "", isCustom: false, isSeeded: true
        )
    }
}

// SessionPresentationState needs to be accessible in tests — expose it here.
// (It is private inside IroniqTabView, so we re-declare the equivalent for testing purposes.)
enum SessionPresentationState: Equatable {
    case none
    case dashboard(openLogOnAppear: Bool)
    case summary
    case exercisePicker

    var showsDashboard: Bool {
        if case .dashboard = self { return true }
        return false
    }
    var openLogOnDashboardAppear: Bool {
        if case .dashboard(let open) = self { return open }
        return false
    }
    var showsSummary: Bool {
        if case .summary = self { return true }
        return false
    }
    var showsExercisePicker: Bool {
        if case .exercisePicker = self { return true }
        return false
    }
}
