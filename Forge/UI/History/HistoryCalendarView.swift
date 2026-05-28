import SwiftUI

struct HistoryCalendarView: View {
    @Environment(HistoryViewModel.self) private var vm
    @State private var selectedDate: Date? = nil

    private let calendar = Calendar.current
    private var today: Date { Date() }

    var body: some View {
        VStack(spacing: 0) {
            calendarGrid
                .padding(.horizontal, 16)

            Divider().background(.white.opacity(0.1))

            if let date = selectedDate {
                let sessions = vm.sessions(on: date)
                if sessions.isEmpty {
                    Text("No workouts on this day.")
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 24)
                } else {
                    List(sessions) { session in
                        NavigationLink(value: session) {
                            SessionRowView(session: session)
                        }
                        .listRowBackground(Color(white: 0.1))
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            } else {
                Text("Tap a day to see workouts.")
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.top, 24)
            }

            Spacer()
        }
        .background(Color.forgeDark)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SessionDTO.self) { session in
            SessionDetailView(session: session)
        }
        .preferredColorScheme(.dark)
    }

    private var calendarGrid: some View {
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let days = calendarDays(for: month)

        return VStack(spacing: 4) {
            // Day headers
            HStack {
                ForEach(["Su","Mo","Tu","We","Th","Fr","Sa"], id: \.self) { d in
                    Text(d)
                        .font(.caption2).bold()
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<(days.count / 7 + (days.count % 7 > 0 ? 1 : 0)), id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7) { col in
                        let index = row * 7 + col
                        if index < days.count, let date = days[index] {
                            dayCell(date)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 36)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let hasWorkout = vm.workoutDates.contains(comps)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let isToday = calendar.isDateInToday(date)

        Button {
            selectedDate = date
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.forgeOrange : (hasWorkout ? Color.forgeGreen.opacity(0.3) : Color.clear))
                    .frame(width: 34, height: 34)

                if isToday && !isSelected {
                    Circle()
                        .stroke(Color.forgeOrange.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? .black : (hasWorkout ? Color.forgeGreen : .white.opacity(0.8)))
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day \(calendar.component(.day, from: date))\(hasWorkout ? ", has workout" : "")")
    }

    private func calendarDays(for month: Date) -> [Date?] {
        guard let monthRange = calendar.range(of: .day, in: .month, for: month),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        let firstWeekday = (calendar.component(.weekday, from: firstDay) - 1 + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in monthRange {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        return days
    }
}

#Preview {
    NavigationStack {
        HistoryCalendarView()
            .environment(HistoryViewModel(sessionRepo: PreviewRepositories.session, appState: AppState()))
    }
}
