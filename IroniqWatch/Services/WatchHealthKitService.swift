import Foundation
@preconcurrency import HealthKit
import WatchKit

// WKBackgroundModes: workout-processing in Info.plist enables both
// HKWorkoutSession and WKExtendedRuntimeSession to keep the app in
// the foreground during a workout.

@MainActor
final class WatchHealthKitService: NSObject, @unchecked Sendable {
    static let shared = WatchHealthKitService()

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var extendedRuntimeSession: WKExtendedRuntimeSession?
    private(set) var isSessionActive = false

    var onHeartRateUpdate: ((Double) -> Void)?

    // MARK: - Extended runtime (belt-and-suspenders alongside HKWorkoutSession)

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

    // MARK: - HealthKit authorization

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

    // MARK: - HKWorkoutSession (primary foreground mechanism)
    // With WKBackgroundModes: workout-processing, an HKWorkoutSession in
    // .running state keeps the app in the foreground and brings it back on
    // wrist-raise, identical to Apple's built-in workout apps.

    func startSession() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard !isSessionActive else { return }

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
        session.delegate = self

        workoutSession = session
        workoutBuilder = builder

        session.startActivity(with: Date())
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: Date()) { _, error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
        isSessionActive = true
    }

    func endSession() async throws {
        guard let session = workoutSession else { return }
        guard session.state != .ended && session.state != .stopped else {
            workoutSession = nil
            workoutBuilder = nil
            isSessionActive = false
            return
        }
        let builder = workoutBuilder
        session.stopActivity(with: Date())
        if let builder {
            try? await builder.endCollection(at: Date())
            try? await builder.finishWorkout()
        }
        workoutSession = nil
        workoutBuilder = nil
        isSessionActive = false
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchHealthKitService: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended || toState == .stopped else { return }
        Task { @MainActor in
            self.workoutSession = nil
            self.workoutBuilder = nil
            self.isSessionActive = false
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            self.workoutSession = nil
            self.workoutBuilder = nil
            self.isSessionActive = false
        }
    }
}

// MARK: - WKExtendedRuntimeSessionDelegate

extension WatchHealthKitService: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {}

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
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
