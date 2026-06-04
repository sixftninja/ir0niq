import Foundation
@preconcurrency import HealthKit
import WatchKit

@MainActor
final class WatchHealthKitService: NSObject, @unchecked Sendable {
    static let shared = WatchHealthKitService()

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var extendedRuntimeSession: WKExtendedRuntimeSession?
    private(set) var isSessionActive = false

    var onHeartRateUpdate: ((Double) -> Void)?

    // MARK: - Extended runtime (keeps watch app in foreground during workout)
    // WKExtendedRuntimeSession brings the app back to foreground on wrist-raise,
    // independent of HealthKit authorization. Belt-and-suspenders alongside HK.

    func startExtendedSession() {
        guard extendedRuntimeSession?.state != .running else { return }
        let s = WKExtendedRuntimeSession()
        s.delegate = self
        s.start()
        extendedRuntimeSession = s
    }

    func stopExtendedSession() {
        extendedRuntimeSession?.invalidate()
        extendedRuntimeSession = nil
    }

    // MARK: - HealthKit workout session (heart rate + calories)

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        let read: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        try await healthStore.requestAuthorization(toShare: share, read: read)
    }

    func startSession() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )
        builder.delegate = self

        self.workoutSession = session
        self.workoutBuilder = builder

        // startActivity is synchronous on watchOS 10+
        session.startActivity(with: Date())
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: Date()) { _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
        isSessionActive = true
    }

    func endSession() async throws {
        guard let session = workoutSession, let builder = workoutBuilder else { return }
        session.stopActivity(with: Date())
        try await builder.endCollection(at: Date())
        _ = try? await builder.finishWorkout()
        workoutSession = nil
        workoutBuilder = nil
        isSessionActive = false
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchHealthKitService: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        // Restart immediately to maintain continuous foreground coverage
        Task { @MainActor in
            self.extendedRuntimeSession = nil
            self.startExtendedSession()
        }
    }

    nonisolated func extendedRuntimeSession(
        _ session: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        // ObjectIdentifier is Sendable; WKExtendedRuntimeSession is not
        let invalidatedId = ObjectIdentifier(session)
        Task { @MainActor in
            if let current = self.extendedRuntimeSession,
               ObjectIdentifier(current) == invalidatedId {
                self.extendedRuntimeSession = nil
            }
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHealthKitService: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let hrType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        guard collectedTypes.contains(hrType),
              let stats = workoutBuilder.statistics(for: hrType) else { return }
        let bpm = stats.mostRecentQuantity()?.doubleValue(
            for: HKUnit.count().unitDivided(by: .minute())
        ) ?? 0
        Task { @MainActor in self.onHeartRateUpdate?(bpm) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
