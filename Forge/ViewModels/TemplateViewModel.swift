import Foundation
import Observation

@MainActor
@Observable
final class TemplateViewModel {

    private(set) var templates: [TemplateDTO] = []
    private(set) var exercises: [ExerciseDTO] = []
    private(set) var isLoading = false

    var alertMessage: String? = nil
    var showAlert = false

    private let templateRepo: any TemplateRepositoryProtocol
    private let exerciseRepo: any ExerciseRepositoryProtocol

    init(
        templateRepo: any TemplateRepositoryProtocol,
        exerciseRepo: any ExerciseRepositoryProtocol
    ) {
        self.templateRepo = templateRepo
        self.exerciseRepo = exerciseRepo
    }

    // MARK: - Load

    func loadAll() async {
        isLoading = true
        do {
            async let t = templateRepo.fetchAll()
            async let e = exerciseRepo.fetchAll()
            templates = try await t
            exercises = try await e
        } catch {
            setAlert(error)
        }
        isLoading = false
    }

    func seedExercisesIfNeeded() async {
        do {
            let data = try SeedDataService.loadExercises(from: .main)
            _ = try await exerciseRepo.seedIfNeeded(exercises: data)
            exercises = try await exerciseRepo.fetchAll()
        } catch {
            // Seed failure is non-fatal
        }
    }

    // MARK: - Templates

    func canCreateTemplate(appState: AppState) -> Bool {
        appState.isProUser || templates.count < AppState.freeTemplateLimit
    }

    func createTemplate(
        name: String,
        exercises exerciseInputs: [CreateTemplateExerciseInput]
    ) async throws -> UUID {
        let id = try await templateRepo.insert(name: name, exercises: exerciseInputs)
        templates = try await templateRepo.fetchAll()
        return id
    }

    func deleteTemplate(_ id: UUID) async {
        do {
            try await templateRepo.delete(id: id)
            templates.removeAll { $0.id == id }
        } catch { setAlert(error) }
    }

    // MARK: - Exercise search

    func searchExercises(query: String) -> [ExerciseDTO] {
        guard !query.isEmpty else { return exercises }
        let q = query.lowercased()
        return exercises.filter { $0.name.lowercased().contains(q) }
    }

    func exercisesByMuscleGroup() -> [(group: MuscleGroup, exercises: [ExerciseDTO])] {
        var grouped: [MuscleGroup: [ExerciseDTO]] = [:]
        for ex in exercises {
            for group in ex.muscleGroups {
                grouped[group, default: []].append(ex)
            }
        }
        return MuscleGroup.allCases.compactMap { group in
            guard let exs = grouped[group], !exs.isEmpty else { return nil }
            return (group: group, exercises: exs.sorted { $0.name < $1.name })
        }
    }

    private func setAlert(_ error: Error) {
        alertMessage = error.localizedDescription
        showAlert = true
    }
}
