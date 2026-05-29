import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "dumbbell.fill",
            title: "Track Every Rep",
            body: "Forge keeps every set, rep, and rest time so you can focus on lifting."
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
            Color.forgeDark.ignoresSafeArea()

            VStack(spacing: 32) {
                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .tag(i)
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
                        .background(Color.forgeOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .accessibilityIdentifier("onboarding_cta")
            }
        }
        
    }

    @ViewBuilder
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Image(systemName: page.icon)
                .font(.system(size: 72))
                .foregroundStyle(Color.forgeOrange)
            Text(page.title)
                .font(.largeTitle).bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(page.body)
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
            appState.hasCompletedOnboarding = true
        }
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
