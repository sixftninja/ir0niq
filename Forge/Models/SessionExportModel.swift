import Foundation

// MARK: - Export model (iCloud Drive JSON schema, version 1)

struct SessionExportModel: Codable, Sendable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let sessionId: String
    let templateName: String?
    let startedAt: Date
    let endedAt: Date
    let status: String
    let actualDurationSeconds: TimeInterval
    let totalPauseDurationSeconds: TimeInterval
    let exercises: [ExerciseExport]

    struct ExerciseExport: Codable, Sendable {
        let exerciseName: String
        let order: Int
        let status: String
        let sets: [SetExport]
    }

    struct SetExport: Codable, Sendable {
        let order: Int
        let status: String
        let reps: Int?
        let weight: Double?
        let setDurationSeconds: TimeInterval?
        let restDurationSeconds: TimeInterval?
        let isUnrecorded: Bool
    }
}

// MARK: - Factory

extension SessionExportModel {
    static func make(from dto: SessionDTO, templateName: String? = nil) -> SessionExportModel {
        let now = Date()
        let endedAt = dto.endedAt ?? now
        let actual = endedAt.timeIntervalSince(dto.startedAt) - dto.totalPauseDuration

        let exercises = dto.exercises.map { ex -> ExerciseExport in
            let sets = ex.sets.map { set -> SetExport in
                SetExport(
                    order: set.order,
                    status: set.status.rawValue,
                    reps: set.reps,
                    weight: set.weight,
                    setDurationSeconds: duration(from: set.setTimerStart, to: set.setTimerEnd),
                    restDurationSeconds: duration(from: set.restStart, to: set.restEnd),
                    isUnrecorded: set.isUnrecorded
                )
            }
            return ExerciseExport(
                exerciseName: ex.exerciseName,
                order: ex.order,
                status: ex.status.rawValue,
                sets: sets
            )
        }

        return SessionExportModel(
            version: currentVersion,
            exportedAt: now,
            sessionId: dto.id.uuidString,
            templateName: templateName,
            startedAt: dto.startedAt,
            endedAt: endedAt,
            status: dto.status.rawValue,
            actualDurationSeconds: max(0, actual),
            totalPauseDurationSeconds: dto.totalPauseDuration,
            exercises: exercises
        )
    }

    private static func duration(from start: Date?, to end: Date?) -> TimeInterval? {
        guard let start, let end else { return nil }
        return max(0, end.timeIntervalSince(start))
    }
}

// MARK: - JSON serialization

extension SessionExportModel {
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func jsonData() throws -> Data {
        try Self.jsonEncoder.encode(self)
    }
}
