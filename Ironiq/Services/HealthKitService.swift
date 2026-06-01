import Foundation
@preconcurrency import HealthKit

// MARK: - Protocol

protocol HealthKitServiceProtocol: Sendable {
    func isAvailable() -> Bool
    func requestAuthorization() async throws
    func startWorkout(sessionId: UUID, startDate: Date) async throws
    func endWorkout(sessionId: UUID, endDate: Date) async throws -> UUID?
    func addActiveEnergyBurned(_ kcal: Double, at date: Date) async throws
}

// MARK: - Errors

enum HealthKitError: Error, Equatable {
    case unavailable
    case authorizationDenied
    case workoutAlreadyStarted
    case noActiveWorkout
    case saveFailed(String)
}

// MARK: - Production Implementation

actor HealthKitService: HealthKitServiceProtocol {
    private let healthStore: HKHealthStore
    private var workoutBuilder: HKWorkoutBuilder?
    private var activeSessionId: UUID?

    static let shared = HealthKitService()

    private init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }

    nonisolated func isAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAvailable() else { throw HealthKitError.unavailable }

        let shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func startWorkout(sessionId: UUID, startDate: Date) async throws {
        guard isAvailable() else { throw HealthKitError.unavailable }
        guard workoutBuilder == nil else { throw HealthKitError.workoutAlreadyStarted }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: config,
            device: .local()
        )
        try await builder.beginCollection(at: startDate)
        workoutBuilder = builder
        activeSessionId = sessionId
    }

    func endWorkout(sessionId: UUID, endDate: Date) async throws -> UUID? {
        guard let builder = workoutBuilder else { throw HealthKitError.noActiveWorkout }
        try await builder.endCollection(at: endDate)
        let workout = try await builder.finishWorkout()
        workoutBuilder = nil
        activeSessionId = nil
        return workout?.uuid
    }

    func addActiveEnergyBurned(_ kcal: Double, at date: Date) async throws {
        guard let builder = workoutBuilder else { return }
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        let sample = HKQuantitySample(
            type: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            quantity: quantity,
            start: date,
            end: date
        )
        // Bridge completion handler to async/await
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add([sample]) { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
