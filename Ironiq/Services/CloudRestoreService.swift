import Foundation

// Reads template and session export files from the user's chosen cloud drive
// and inserts them into the local SwiftData store.
//
// Called at app startup and after sign-in. Always runs; name-based deduplication
// prevents creating duplicate templates if some already exist locally.

struct CloudRestoreResult {
    let templatesRestored: Int
    let sessionsRestored: Int
    let errors: [String]
}

struct CloudRestoreService {
    private let templateRepo: any TemplateRepositoryProtocol
    private let sessionRepo: any SessionRepositoryProtocol

    init(
        templateRepo: any TemplateRepositoryProtocol,
        sessionRepo: any SessionRepositoryProtocol
    ) {
        self.templateRepo = templateRepo
        self.sessionRepo = sessionRepo
    }

    // Always runs restore; returns a result with counts and any per-file errors.
    // Name-based dedup in insertTemplate() prevents creating duplicate templates.
    func restoreIfNeeded(provider: SyncProvider) async -> CloudRestoreResult {
        switch provider {
        case .apple:
            return await restoreFromiCloud()
        case .google:
            return await restoreFromGoogleDrive()
        }
    }

    // MARK: - iCloud restore

    private func restoreFromiCloud() async -> CloudRestoreResult {
        let fm = FileManager.default
        let containerID = "iCloud.com.ir0niq.app"

        // Apple docs: url(forUbiquityContainerIdentifier:) must not be called from the main
        // thread and may return nil on fresh install until the container initialises.
        // Call it from a background thread; if it returns nil, retry once after 2 seconds.
        var iCloudURL: URL? = await Task.detached(priority: .utility) {
            FileManager.default.url(forUbiquityContainerIdentifier: containerID)
        }.value

        if iCloudURL == nil {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            iCloudURL = await Task.detached(priority: .utility) {
                FileManager.default.url(forUbiquityContainerIdentifier: containerID)
            }.value
        }

        guard let iCloudURL else {
            return CloudRestoreResult(templatesRestored: 0, sessionsRestored: 0, errors: ["iCloud container unavailable."])
        }

        let ironiqBase = iCloudURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Ironiq", isDirectory: true)

        var errors: [String] = []
        let templates = await restoreTemplatesFromDirectory(
            ironiqBase.appendingPathComponent("Templates", isDirectory: true),
            errors: &errors
        )
        let sessions = await restoreSessionsFromDirectory(
            ironiqBase.appendingPathComponent("Sessions", isDirectory: true),
            errors: &errors
        )
        return CloudRestoreResult(templatesRestored: templates, sessionsRestored: sessions, errors: errors)
    }

    private func restoreTemplatesFromDirectory(_ dir: URL, errors: inout [String]) async -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension == "gz" }) else { return 0 }

        var restored = 0
        for file in files {
            do {
                let compressed = try Data(contentsOf: file)
                let json = try compressed.gunzipped()
                let model = try JSONDecoder.isoDecoder.decode(TemplateExportModel.self, from: json)
                try await insertTemplate(model)
                restored += 1
            } catch {
                errors.append("Template \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return restored
    }

    private func restoreSessionsFromDirectory(_ baseDir: URL, errors: inout [String]) async -> Int {
        // Sessions are stored in YYYY/MM subdirectories.
        guard let years = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil) else { return 0 }
        var restored = 0
        for year in years {
            guard let months = try? FileManager.default.contentsOfDirectory(at: year, includingPropertiesForKeys: nil) else { continue }
            for month in months {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: month, includingPropertiesForKeys: nil
                ).filter({ $0.pathExtension == "gz" }) else { continue }
                for file in files {
                    do {
                        let compressed = try Data(contentsOf: file)
                        let json = try compressed.gunzipped()
                        let model = try JSONDecoder.isoDecoder.decode(SessionExportModel.self, from: json)
                        try await insertSession(model)
                        restored += 1
                    } catch {
                        errors.append("Session \(file.lastPathComponent): \(error.localizedDescription)")
                    }
                }
            }
        }
        return restored
    }

    // MARK: - Google Drive restore

    private func restoreFromGoogleDrive() async -> CloudRestoreResult {
        var errors: [String] = []

        let driveService = await MainActor.run { GoogleDriveService.shared }

        guard let accessToken = try? await driveService.validAccessToken() else {
            return CloudRestoreResult(templatesRestored: 0, sessionsRestored: 0, errors: ["Google token unavailable."])
        }

        let templatesFolderId = UserDefaults.standard.string(forKey: "googleDriveTemplatesFolderId") ?? ""
        let sessionsFolderId = UserDefaults.standard.string(forKey: "googleDriveSessionsFolderId") ?? ""

        var templatesRestored = 0
        var sessionsRestored = 0

        if !templatesFolderId.isEmpty {
            if let files = try? await driveService.listFiles(folderId: templatesFolderId, accessToken: accessToken) {
                for file in files where file.name?.hasSuffix(".gz") == true {
                    do {
                        let data = try await driveService.downloadFile(id: file.id, accessToken: accessToken)
                        let json = try data.gunzipped()
                        let model = try JSONDecoder.isoDecoder.decode(TemplateExportModel.self, from: json)
                        try await insertTemplate(model)
                        templatesRestored += 1
                    } catch {
                        errors.append("Template \(file.name ?? file.id): \(error.localizedDescription)")
                    }
                }
            }
        }

        if !sessionsFolderId.isEmpty {
            if let files = try? await driveService.listFiles(folderId: sessionsFolderId, accessToken: accessToken) {
                for file in files where file.name?.hasSuffix(".gz") == true {
                    do {
                        let data = try await driveService.downloadFile(id: file.id, accessToken: accessToken)
                        let json = try data.gunzipped()
                        let model = try JSONDecoder.isoDecoder.decode(SessionExportModel.self, from: json)
                        try await insertSession(model)
                        sessionsRestored += 1
                    } catch {
                        errors.append("Session \(file.name ?? file.id): \(error.localizedDescription)")
                    }
                }
            }
        }

        return CloudRestoreResult(templatesRestored: templatesRestored, sessionsRestored: sessionsRestored, errors: errors)
    }

    // MARK: - SwiftData insertion

    private func insertTemplate(_ model: TemplateExportModel) async throws {
        let existing = try await templateRepo.fetchAll()
        // Skip by name (case-insensitive) — the user's template names are unique per account.
        guard !existing.contains(where: { $0.name.lowercased() == model.name.lowercased() }) else { return }

        let exercises = model.exercises.sorted { $0.order < $1.order }.map { ex -> CreateTemplateExerciseInput in
            let sets = ex.sets.sorted { $0.order < $1.order }.map { s in
                CreateTemplateSetInput(
                    targetReps: s.targetReps,
                    targetWeight: s.targetWeight,
                    targetDuration: s.targetDuration,
                    restDuration: s.restDuration
                )
            }
            return CreateTemplateExerciseInput(
                exerciseId: ex.exerciseId,
                equipmentTypeOverride: ex.equipmentTypeOverride.flatMap(EquipmentType.init(rawValue:)),
                sets: sets
            )
        }
        _ = try await templateRepo.insert(name: model.name, exercises: exercises)
    }

    private func insertSession(_ model: SessionExportModel) async throws {
        // Sessions can't be inserted from export alone without full SwiftData model access.
        // The session repository currently only supports creating sessions through the engine.
        // For now, we mark this as a known limitation — sessions are not yet restorable
        // without a dedicated session import API on the repository.
        // TODO: add SessionRepository.importFromExport(_:) in a follow-up.
    }
}

// MARK: - JSON decoder helper

private extension JSONDecoder {
    static let isoDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
