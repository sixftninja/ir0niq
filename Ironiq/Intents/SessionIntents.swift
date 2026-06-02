import AppIntents

// MARK: - Next Set

struct NextSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Set"
    static let description = IntentDescription("Advance to the next set in your Ironiq workout.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = await MainActor.run { SessionIntentBridge.shared.engine() }
        guard let engine else { return .result(dialog: "No active Ironiq session.") }
        do {
            try await engine.advanceToNext()
            return .result(dialog: "Advanced to the next set.")
        } catch SessionEngineError.allSetsNotLogged {
            return .result(dialog: "Please log all sets before moving to the next exercise.")
        } catch {
            return .result(dialog: "Could not advance: \(error.localizedDescription)")
        }
    }
}

// MARK: - Previous Set

struct PreviousSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Previous Set"
    static let description = IntentDescription("Navigate to the previous set in your Ironiq workout.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = await MainActor.run { SessionIntentBridge.shared.engine() }
        guard let engine else { return .result(dialog: "No active Ironiq session.") }
        do {
            try await engine.goToPreviousSet()
            return .result(dialog: "Went back to the previous set.")
        } catch {
            return .result(dialog: "Already at the first set.")
        }
    }
}

// MARK: - Skip Set

struct SkipSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Skip Set"
    static let description = IntentDescription("Skip the current set in your Ironiq workout.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = await MainActor.run { SessionIntentBridge.shared.engine() }
        guard let engine else { return .result(dialog: "No active Ironiq session.") }
        do {
            try await engine.skipCurrentSet()
            return .result(dialog: "Set skipped.")
        } catch {
            return .result(dialog: "Could not skip: \(error.localizedDescription)")
        }
    }
}

// MARK: - Pause Session

struct PauseSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Workout"
    static let description = IntentDescription("Pause your active Ironiq workout session.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = await MainActor.run { SessionIntentBridge.shared.engine() }
        guard let engine else { return .result(dialog: "No active Ironiq session.") }
        do {
            try await engine.pauseSession()
            return .result(dialog: "Workout paused.")
        } catch {
            return .result(dialog: "Could not pause: \(error.localizedDescription)")
        }
    }
}

// MARK: - Resume Session

struct ResumeSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Workout"
    static let description = IntentDescription("Resume your paused Ironiq workout session.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = await MainActor.run { SessionIntentBridge.shared.engine() }
        guard let engine else { return .result(dialog: "No active Ironiq session.") }
        do {
            try await engine.resumeSession()
            return .result(dialog: "Workout resumed.")
        } catch {
            return .result(dialog: "Could not resume: \(error.localizedDescription)")
        }
    }
}

// MARK: - End Session

struct EndSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "End Workout"
    static let description = IntentDescription("End and save your current Ironiq workout session.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = await MainActor.run { SessionIntentBridge.shared.engine() }
        guard let engine else { return .result(dialog: "No active Ironiq session.") }
        do {
            _ = try await engine.endSession()
            try await engine.confirmEnd()
            return .result(dialog: "Workout saved.")
        } catch {
            return .result(dialog: "Could not end session: \(error.localizedDescription)")
        }
    }
}

// MARK: - App Shortcuts

struct IroniqShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PauseSessionIntent(),
            phrases: ["Pause my \(.applicationName) workout", "Pause \(.applicationName)"],
            shortTitle: "Pause Workout",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: ResumeSessionIntent(),
            phrases: ["Resume my \(.applicationName) workout", "Resume \(.applicationName)"],
            shortTitle: "Resume Workout",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: NextSetIntent(),
            phrases: ["Next set in \(.applicationName)", "Advance \(.applicationName) set"],
            shortTitle: "Next Set",
            systemImageName: "arrow.right.circle"
        )
        AppShortcut(
            intent: EndSessionIntent(),
            phrases: ["End my \(.applicationName) workout", "Finish \(.applicationName)"],
            shortTitle: "End Workout",
            systemImageName: "stop.fill"
        )
    }
}
