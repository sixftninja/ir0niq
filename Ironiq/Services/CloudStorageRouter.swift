import Foundation

// Routes session and template exports to whichever cloud provider the user chose.
// Reads the provider from UserDefaults (the same key AppState writes to) so it
// works from actor contexts that can't touch @MainActor state directly.

actor CloudStorageRouter: iCloudServiceProtocol {
    static let shared = CloudStorageRouter()
    private init() {}

    private var currentProvider: SyncProvider? {
        UserDefaults.standard.string(forKey: "syncProvider").flatMap(SyncProvider.init(rawValue:))
    }

    func prepareSyncFolders() async throws {
        switch currentProvider {
        case .apple:
            try await iCloudService.shared.prepareSyncFolders()
        case .google:
            _ = try await GoogleDriveService.shared.connectAndPrepareSyncFolders()
        case nil:
            throw iCloudError.containerUnavailable
        }
    }

    func exportSession(_ model: SessionExportModel, templateSlug: String?) async throws -> URL {
        switch currentProvider {
        case .apple:
            return try await iCloudService.shared.exportSession(model, templateSlug: templateSlug)
        case .google:
            return try await GoogleDriveStorageService.shared.exportSession(model, templateSlug: templateSlug)
        case nil:
            throw iCloudError.containerUnavailable
        }
    }

    func exportTemplate(_ model: TemplateExportModel) async throws -> URL {
        switch currentProvider {
        case .apple:
            return try await iCloudService.shared.exportTemplate(model)
        case .google:
            return try await GoogleDriveStorageService.shared.exportTemplate(model)
        case nil:
            throw iCloudError.containerUnavailable
        }
    }
}

// MARK: - Google Drive implementation of iCloudServiceProtocol

actor GoogleDriveStorageService: iCloudServiceProtocol {
    static let shared = GoogleDriveStorageService()
    private init() {}

    private let tokenStore = GoogleTokenStore.shared

    // GoogleDriveService is @MainActor — hop to main actor to obtain the reference.
    private func driveService() async -> GoogleDriveService {
        await MainActor.run { GoogleDriveService.shared }
    }

    func prepareSyncFolders() async throws {
        // Folders are created during onboarding — nothing to do here.
    }

    func exportSession(_ model: SessionExportModel, templateSlug: String?) async throws -> URL {
        let folderId = try sessionsFolderId()
        let filename = buildFilename(date: model.startedAt, slug: templateSlug)
        let data = try model.jsonData().gzipped()
        let svc = await driveService()
        let accessToken = try await svc.validAccessToken()
        _ = try await svc.uploadFile(name: filename, data: data, folderId: folderId, accessToken: accessToken)
        return URL(string: "https://drive.google.com/file/\(filename)")!
    }

    func exportTemplate(_ model: TemplateExportModel) async throws -> URL {
        let folderId = try templatesFolderId()
        let filename = "ironiq_template_\(model.id.uuidString.lowercased()).json.gz"
        let data = try model.jsonData().gzipped()
        let svc = await driveService()
        let accessToken = try await svc.validAccessToken()
        _ = try await svc.uploadFile(name: filename, data: data, folderId: folderId, accessToken: accessToken)
        return URL(string: "https://drive.google.com/file/\(filename)")!
    }

    // MARK: - Helpers

    private func sessionsFolderId() throws -> String {
        guard let id = UserDefaults.standard.string(forKey: "googleDriveSessionsFolderId"), !id.isEmpty else {
            throw GoogleDriveError.driveRequestFailed("Sessions folder not configured.")
        }
        return id
    }

    private func templatesFolderId() throws -> String {
        guard let id = UserDefaults.standard.string(forKey: "googleDriveTemplatesFolderId"), !id.isEmpty else {
            throw GoogleDriveError.driveRequestFailed("Templates folder not configured.")
        }
        return id
    }

    private func buildFilename(date: Date, slug: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let ts = formatter.string(from: date)
        if let s = slug?.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter({ $0.isLetter || $0.isNumber || $0 == "-" }),
           !s.isEmpty {
            return "ironiq_\(ts)_\(s).json.gz"
        }
        return "ironiq_\(ts).json.gz"
    }
}
