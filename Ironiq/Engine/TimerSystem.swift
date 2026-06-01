import Foundation

/// Manages concurrent one-shot timers using structured concurrency.
/// All timers of the same kind are exclusive — scheduling a new one cancels the previous.
actor TimerSystem {
    private var activeTasks: [TimerKind: Task<Void, Never>] = [:]

    /// Schedules a timer that fires `onFire` after `duration` seconds.
    /// Cancels any existing timer of the same kind.
    func schedule(
        _ kind: TimerKind,
        after duration: TimeInterval,
        onFire: @escaping @Sendable () async -> Void
    ) {
        activeTasks[kind]?.cancel()
        activeTasks[kind] = Task {
            do {
                try await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                await onFire()
            } catch {
                // CancellationError — expected when cancel() is called
            }
        }
    }

    func cancel(_ kind: TimerKind) {
        activeTasks[kind]?.cancel()
        activeTasks[kind] = nil
    }

    func cancelAll() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
    }

    func isActive(_ kind: TimerKind) -> Bool {
        activeTasks[kind] != nil
    }
}
