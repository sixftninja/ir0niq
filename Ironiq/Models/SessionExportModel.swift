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
        let durationSeconds: TimeInterval?
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
                    durationSeconds: set.durationSeconds,
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

// MARK: - AI-ready workout history export scaffold

/// AI-ready workout history export schema shared by completion, history, and future exports.
struct WorkoutHistoryExport: Codable, Sendable, Equatable {
    static let currentVersion = 1

    let version: Int
    let exportedAt: Date
    let sessions: [WorkoutExportSession]

    init(sessions: [SessionDTO], exportedAt: Date = Date()) {
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.sessions = sessions.map(WorkoutExportSession.init(from:))
    }
}

struct WorkoutExportSession: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let status: String
    let durationSeconds: TimeInterval
    let exerciseCount: Int
    let setsLogged: Int
    let totalVolumeKg: Double
    let totalRestSeconds: TimeInterval
    let peakHeartRateBPM: Double?
    let exercises: [WorkoutExportExercise]

    init(from session: SessionDTO) {
        id = session.id
        startedAt = session.startedAt
        endedAt = session.endedAt
        status = session.status.rawValue
        durationSeconds = session.actualDurationSeconds
        exercises = session.exercises.sorted { $0.order < $1.order }.map(WorkoutExportExercise.init(from:))
        exerciseCount = exercises.count
        setsLogged = exercises.reduce(0) { $0 + $1.setsLogged }
        totalVolumeKg = exercises.reduce(0) { $0 + $1.totalVolumeKg }
        totalRestSeconds = exercises.reduce(0) { $0 + $1.totalRestSeconds }
        peakHeartRateBPM = nil
    }
}

struct WorkoutExportExercise: Codable, Sendable, Equatable {
    let name: String
    let order: Int
    let status: String
    let setsLogged: Int
    let totalVolumeKg: Double
    let totalRestSeconds: TimeInterval
    let sets: [WorkoutExportSet]

    init(from exercise: SessionExerciseDTO) {
        name = exercise.exerciseName
        order = exercise.order
        status = exercise.status.rawValue
        sets = exercise.sets.sorted { $0.order < $1.order }.map(WorkoutExportSet.init(from:))
        setsLogged = sets.filter { $0.status == SetStatus.logged.rawValue }.count
        totalVolumeKg = sets.reduce(0) { $0 + $1.volumeKg }
        totalRestSeconds = sets.compactMap(\.restDurationSeconds).reduce(0, +)
    }
}

struct WorkoutExportSet: Codable, Sendable, Equatable {
    let order: Int
    let status: String
    let reps: Int?
    let durationSeconds: TimeInterval?
    let weightKg: Double?
    let volumeKg: Double
    let setDurationSeconds: TimeInterval?
    let restDurationSeconds: TimeInterval?
    let isUnrecorded: Bool

    init(from set: SessionSetDTO) {
        order = set.order
        status = set.status.rawValue
        reps = set.reps
        durationSeconds = set.durationSeconds
        weightKg = set.weight
        volumeKg = Double(set.reps ?? 0) * (set.weight ?? 0)
        setDurationSeconds = set.setDuration
        restDurationSeconds = set.restDuration
        isUnrecorded = set.isUnrecorded
    }
}

extension WorkoutHistoryExport {
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func jsonData() throws -> Data {
        try Self.jsonEncoder.encode(self)
    }

    func markdown() -> String {
        var lines: [String] = [
            "# Ironiq Workout History",
            "",
            "Exported: \(exportedAt.formatted(date: .abbreviated, time: .shortened))",
            ""
        ]
        for session in sessions {
            lines.append("## \(session.startedAt.formatted(date: .abbreviated, time: .shortened))")
            lines.append("- Duration: \(Int(session.durationSeconds)) seconds")
            lines.append("- Exercises: \(session.exerciseCount)")
            lines.append("- Sets logged: \(session.setsLogged)")
            lines.append("- Total volume: \(String(format: "%.0f", session.totalVolumeKg)) kg")
            if let peak = session.peakHeartRateBPM {
                lines.append("- Peak heart rate: \(Int(peak.rounded())) bpm")
            }
            lines.append("- Total rest: \(Int(session.totalRestSeconds)) seconds")
            lines.append("")
            for exercise in session.exercises {
                lines.append("### \(exercise.name)")
                for set in exercise.sets {
                    let result = set.reps.map { "\($0) reps" } ?? set.durationSeconds.map { "\(Int($0)) sec" } ?? set.status
                    let weight = set.weightKg.map { String(format: " @ %.0f kg", $0) } ?? ""
                    let rest = set.restDurationSeconds.map { ", rest \(Int($0)) sec" } ?? ""
                    lines.append("- Set \(set.order + 1): \(result)\(weight)\(rest)")
                }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }
}
