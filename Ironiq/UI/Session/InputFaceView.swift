import SwiftUI

/// Reps and weight entry sheet.
struct InputFaceView: View {
    let set: ActiveSessionContext.ExerciseContext.SetContext
    let defaultLoggingType: SetLoggingType
    let onLog: (Int?, TimeInterval?, Double?) -> Void

    @Environment(AppState.self) private var appState
    @Environment(SessionViewModel.self) private var sessionVM
    @State private var loggingType: SetLoggingType
    @State private var reps: Int
    @State private var durationSeconds: Int
    @State private var displayWeightText = ""
    @State private var noWeight = false
    @Environment(\.dismiss) private var dismiss

    init(
        set: ActiveSessionContext.ExerciseContext.SetContext,
        defaultLoggingType: SetLoggingType = .reps,
        onLog: @escaping (Int?, TimeInterval?, Double?) -> Void
    ) {
        self.set = set
        self.defaultLoggingType = defaultLoggingType
        self.onLog = onLog
        _loggingType = State(initialValue: defaultLoggingType)
        _reps = State(initialValue: set.targetReps ?? 10)
        _durationSeconds = State(initialValue: set.targetDuration.map { Int($0) } ?? 30)
        _noWeight = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    logHeader

                    if isResting {
                        restTimerBanner
                    }

                    Picker("Log", selection: $loggingType) {
                        ForEach(SetLoggingType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("logging_type_picker")

                    if loggingType == .duration {
                        numberInputRow(label: "Seconds", value: $durationSeconds, defaultValue: 30)
                            .accessibilityIdentifier("duration_input")
                    } else {
                        numberInputRow(label: "Reps", value: $reps, defaultValue: 10)
                            .accessibilityIdentifier("reps_input")
                    }

                    Divider().background(.white.opacity(0.1))

                    VStack(spacing: 10) {
                        decimalInputRow(
                            label: "Weight (\(WeightFormatter.unitLabel(appState.unitSystem)))",
                            value: $displayWeightText,
                            placeholder: "0"
                        )
                        .disabled(noWeight)
                        .opacity(noWeight ? 0.4 : 1)
                        .accessibilityIdentifier("weight_input")

                        Toggle("Bodyweight", isOn: $noWeight)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))
                            .toggleStyle(.switch)
                            .tint(.ironiqOrange)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 76)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ironiqDark)
            .navigationTitle("Log Set")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                IroniqButton("Log Set") {
                    let enteredWeight = Double(displayWeightText.replacingOccurrences(of: ",", with: "."))
                    let kgWeight = noWeight ? nil : enteredWeight.map { WeightFormatter.toKg($0, unitSystem: appState.unitSystem) }
                    onLog(
                        loggingType == .reps && reps > 0 ? reps : nil,
                        loggingType == .duration && durationSeconds > 0 ? Double(durationSeconds) : nil,
                        kgWeight
                    )
                }
                .accessibilityIdentifier("confirm_log_button")
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color.ironiqDark)
            }
        }
    }


    private var logHeader: some View {
        VStack(spacing: 4) {
            Text(sessionVM.currentExercise?.exerciseName ?? "Exercise")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
            Text("Set \(sessionVM.currentSetIndex + 1) of \(sessionVM.currentExercise?.setContexts.count ?? 0)")
                .font(.system(.title2, design: .default).weight(.bold))
                .foregroundStyle(.white)
                .accessibilityIdentifier("log_set_header")
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
    }

    private var isResting: Bool {
        if case .resting = sessionVM.currentSet?.lifecycleState { return true }
        return false
    }

    private var restTimerBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Rest")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text(sessionVM.restElapsed.timerFormatted)
                    .font(.title2.weight(.black).monospacedDigit())
                    .foregroundStyle(restOverage > 0 ? Color.ironiqOrange : Color.ironiqGreen)
            }
            HStack {
                Text("Target \(restTarget.timerFormatted)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.52))
                Spacer()
                if restOverage > 0 {
                    Text("+\(restOverage.timerFormatted) over")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.ironiqOrange)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .accessibilityIdentifier("log_rest_timer_banner")
    }

    private var restTarget: TimeInterval {
        sessionVM.currentSet?.targetRestDuration ?? 30
    }

    private var restOverage: TimeInterval {
        max(0, sessionVM.restElapsed - restTarget)
    }

    private func numberInputRow(label: String, value: Binding<Int>, defaultValue: Int) -> some View {
        inputContainer(label: label) {
            DefaultPlaceholderIntField(value: value, defaultValue: defaultValue)
                .font(.title2.monospacedDigit().weight(.bold))
        }
    }

    private func decimalInputRow(label: String, value: Binding<String>, placeholder: String) -> some View {
        inputContainer(label: label) {
            TextField(placeholder, text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func inputContainer<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.72))
            Spacer()
            content()
                .frame(width: 110)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DefaultPlaceholderIntField: View {
    @Binding var value: Int
    let defaultValue: Int
    var width: CGFloat? = nil

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(value: Binding<Int>, defaultValue: Int, width: CGFloat? = nil) {
        _value = value
        self.defaultValue = defaultValue
        self.width = width
        _text = State(initialValue: value.wrappedValue == defaultValue ? "" : "\(value.wrappedValue)")
    }

    var body: some View {
        TextField("\(defaultValue)", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.white)
            .focused($isFocused)
            .frame(width: width)
            .onChange(of: isFocused) { _, focused in
                if focused, value == defaultValue {
                    text = ""
                } else if !focused {
                    commit()
                }
            }
            .onSubmit(commit)
            .onChange(of: text) { _, newValue in
                let filtered = newValue.filter(\.isNumber)
                if filtered != newValue {
                    text = filtered
                    return
                }
                if let parsed = Int(filtered), parsed > 0 {
                    value = parsed
                } else if filtered.isEmpty {
                    value = defaultValue
                }
            }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int(trimmed), parsed > 0 else {
            value = defaultValue
            text = ""
            return
        }
        value = parsed
        text = parsed == defaultValue ? "" : "\(parsed)"
    }
}
