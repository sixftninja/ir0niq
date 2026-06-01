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
    await exportTemplateIfNeeded(id)
    return id
  }

  func updateTemplate(
    id: UUID,
    name: String,
    exercises exerciseInputs: [CreateTemplateExerciseInput]
  ) async throws {
    try await templateRepo.update(id: id, name: name, exercises: exerciseInputs)
    templates = try await templateRepo.fetchAll()
    await exportTemplateIfNeeded(id)
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

  func createCustomExercise(name rawName: String) async -> ExerciseDTO? {
    let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      setAlert(message: "Enter an exercise name.")
      return nil
    }

    do {
      let latestExercises = try await exerciseRepo.fetchAll()
      exercises = latestExercises
      let normalizedName = name.normalizedExerciseName
      if latestExercises.contains(where: { $0.name.normalizedExerciseName == normalizedName }) {
        setAlert(message: "\(name) already exists. Select it from the exercise list.")
        return nil
      }

      let id = try await exerciseRepo.insert(
        id: UUID(),
        name: name,
        exerciseDescription: "Custom exercise added by the user.",
        equipmentType: .other,
        isSingleHand: false,
        muscleGroups: [.fullBody],
        iconName: "custom-exercise",
        isCustom: true,
        isSeeded: false,
        defaultLoggingType: .reps
      )
      exercises = try await exerciseRepo.fetchAll()
      return exercises.first { $0.id == id }
    } catch {
      setAlert(error)
      return nil
    }
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

  private func exportTemplateIfNeeded(_ id: UUID) async {
    guard let template = templates.first(where: { $0.id == id }) else { return }
    let model = TemplateExportModel(from: template)
    do {
      _ = try await iCloudService.shared.exportTemplate(model)
    } catch {
      // Template sync failure should not block local template creation.
      setAlert(
        message: "Template saved locally. Cloud sync will retry when drive access is available.")
    }
  }

  private func setAlert(_ error: Error) {

    setAlert(message: error.localizedDescription)
  }

  private func setAlert(message: String) {
    alertMessage = message
    showAlert = true
  }
}

extension String {
  fileprivate var normalizedExerciseName: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .lowercased()
  }
}
