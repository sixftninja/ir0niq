import Foundation

// MARK: - Protocol

protocol iCloudServiceProtocol: Sendable {
    /// Exports a session as a gzipped JSON file. Returns the written file URL.
    func exportSession(_ model: SessionExportModel, templateSlug: String?) async throws -> URL
}

// MARK: - Errors

enum iCloudError: Error, Equatable {
    case containerUnavailable
    case serializationFailed
    case compressionFailed
    case fileAlreadyExists
    case writeFailed(String)
}

// MARK: - Production implementation

actor iCloudService: iCloudServiceProtocol {
    private let containerIdentifier = "iCloud.com.forgegym.app"
    private let fileManager: FileManager

    static let shared = iCloudService()
    private init(fileManager: FileManager = .default) { self.fileManager = fileManager }

    func exportSession(_ model: SessionExportModel, templateSlug: String? = nil) async throws -> URL {
        let directory = try resolveDirectory(for: model.startedAt)
        let filename = buildFilename(date: model.startedAt, slug: templateSlug)
        let fileURL = directory.appendingPathComponent(filename)

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw iCloudError.fileAlreadyExists
        }

        let jsonData = try model.jsonData()
        let compressed = try jsonData.gzipped()

        do {
            try compressed.write(to: fileURL, options: .atomic)
        } catch {
            throw iCloudError.writeFailed(error.localizedDescription)
        }
        return fileURL
    }

    // MARK: - Helpers

    private func resolveDirectory(for date: Date) throws -> URL {
        let baseURL: URL

        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) {
            // Use iCloud Drive when available
            baseURL = iCloudURL.appendingPathComponent("Documents", isDirectory: true)
        } else {
            // Fall back to local documents (simulator / no iCloud sign-in)
            baseURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let directory = baseURL
            .appendingPathComponent("Forge", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent(String(year), isDirectory: true)
            .appendingPathComponent(String(format: "%02d", month), isDirectory: true)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func buildFilename(date: Date, slug: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: date)

        if let slug = slug?.lowercased()
                        .replacingOccurrences(of: " ", with: "-")
                        .filter({ $0.isLetter || $0.isNumber || $0 == "-" }),
           !slug.isEmpty {
            return "forge_\(timestamp)_\(slug).json.gz"
        }
        return "forge_\(timestamp).json.gz"
    }
}
