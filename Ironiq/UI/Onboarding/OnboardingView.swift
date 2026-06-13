import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var page = 0
    @State private var showPreferences = false

    // Preference fields with defaults
    @State private var selectedUnit: UnitSystem = .imperial
    @State private var logReminderText = "120"
    @State private var sessionsPerWeekText = "5"
    @State private var logReminderError: String? = nil
    @State private var sessionsPerWeekError: String? = nil

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "dumbbell.fill",
            title: "Track Every Rep",
            body: "Ironiq keeps every set, rep, and rest time so you can focus on lifting."
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "See Your Progress",
            body: "Review your history and watch your strength grow over time."
        ),
        OnboardingPage(
            icon: "applewatch",
            title: "Lift with Your Watch",
            body: "Control your session from your wrist with the companion Apple Watch app."
        )
    ]

    var body: some View {
        ZStack {
            Color.ironiqDark.ignoresSafeArea()

            if showPreferences {
                preferencesView
                    .transition(.move(edge: .trailing))
            } else {
                carouselView
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.32), value: showPreferences)
    }

    // MARK: - Carousel

    private var carouselView: some View {
        VStack(spacing: 32) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: .infinity)

            Button(action: advance) {
                Text(page == pages.count - 1 ? "Get Started" : "Next")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.ironiqOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .accessibilityIdentifier("onboarding_cta")
        }
    }

    @ViewBuilder
    private func pageView(_ pg: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Image(systemName: pg.icon)
                .font(.system(size: 72))
                .foregroundStyle(Color.ironiqOrange)
            Text(pg.title)
                .font(.largeTitle).bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(pg.body)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            showPreferences = true
        }
    }

    // MARK: - Preferences screen

    private var preferencesView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Preferences")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    Text("You can change these anytime in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                }

                // Units
                VStack(alignment: .leading, spacing: 8) {
                    Text("Units")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Picker("Units", selection: $selectedUnit) {
                        Text("Imperial (lbs)").tag(UnitSystem.imperial)
                        Text("Metric (kg)").tag(UnitSystem.metric)
                    }
                    .pickerStyle(.segmented)
                }

                // Log reminder
                VStack(alignment: .leading, spacing: 6) {
                    Text("Log Reminder")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("How long after a set before we remind you to log it.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                    TextField("", text: $logReminderText)
                        .keyboardType(.numberPad)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { logReminderText = "" }
                        .onChange(of: logReminderText) { _, v in
                            logReminderText = v.filter(\.isNumber)
                            validateLogReminder()
                        }
                        .overlay(alignment: .trailing) {
                            Text("sec")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .padding(.trailing, 14)
                        }
                    if let err = logReminderError {
                        Text(err).font(.caption).foregroundStyle(Color.ironiqRed)
                    }
                }

                // Sessions per week
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sessions per Week")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Your target workouts per week. Used to calculate your consistency score.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                    TextField("", text: $sessionsPerWeekText)
                        .keyboardType(.numberPad)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { sessionsPerWeekText = "" }
                        .onChange(of: sessionsPerWeekText) { _, v in
                            sessionsPerWeekText = v.filter(\.isNumber)
                            validateSessionsPerWeek()
                        }
                    if let err = sessionsPerWeekError {
                        Text(err).font(.caption).foregroundStyle(Color.ironiqRed)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: finishOnboarding) {
                Text("Next")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.ironiqOrange : Color.ironiqOrange.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canProceed)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .accessibilityIdentifier("preferences_next_button")
        }
    }

    private var canProceed: Bool {
        logReminderError == nil && sessionsPerWeekError == nil
            && !logReminderText.isEmpty && !sessionsPerWeekText.isEmpty
    }

    private func validateLogReminder() {
        guard let v = Int(logReminderText) else {
            logReminderError = "Enter a number"
            return
        }
        logReminderError = (v < 30 || v > 300) ? "Must be between 30 and 300" : nil
    }

    private func validateSessionsPerWeek() {
        guard let v = Int(sessionsPerWeekText) else {
            sessionsPerWeekError = "Enter a number"
            return
        }
        sessionsPerWeekError = (v < 1 || v > 14) ? "Must be between 1 and 14" : nil
    }

    private func finishOnboarding() {
        guard canProceed,
              let reminderSecs = Int(logReminderText),
              let weekTarget = Int(sessionsPerWeekText) else { return }
        appState.unitSystem = selectedUnit
        appState.restReminderSeconds = reminderSecs
        appState.sessionsPerWeekTarget = weekTarget
        appState.hasCompletedOnboarding = true
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
