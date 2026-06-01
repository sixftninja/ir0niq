import AuthenticationServices
import SwiftUI

struct ContentView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    if !appState.hasCompletedRequiredSync {
      SyncGateView()
    } else if appState.hasCompletedOnboarding {
      IroniqTabView()
    } else {
      OnboardingView()
    }
  }
}

struct SyncGateView: View {
  @Environment(AppState.self) private var appState
  @State private var errorMessage: String?
  @State private var showGoogleUnavailable = false

  var body: some View {
    ZStack {
      Color.ironiqDark.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 24) {
        Spacer()

        Image(systemName: "icloud.and.arrow.up.fill")
          .font(.system(size: 54, weight: .semibold))
          .foregroundStyle(Color.ironiqOrange)

        VStack(alignment: .leading, spacing: 10) {
          Text("Keep your history yours")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)

          Text(
            "Choose where Ironiq stores your workouts and templates. Your history lives in your own cloud drive, not on Ironiq servers."
          )
          .font(.body)
          .foregroundStyle(.white.opacity(0.68))
          .fixedSize(horizontal: false, vertical: true)
        }

        VStack(spacing: 12) {
          SignInWithAppleButton(.continue) { request in
            request.requestedScopes = [.fullName, .email]
          } onCompletion: { result in
            Task { await handleAppleResult(result) }
          }
          .signInWithAppleButtonStyle(.white)
          .frame(height: 54)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .disabled(appState.isPreparingSync)
          .accessibilityIdentifier("apple_sync_button")

          Button {
            Task { await handleGoogleSignIn() }
          } label: {
            HStack(spacing: 10) {
              Image(systemName: "g.circle.fill")
              Text("Continue with Google")
                .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white.opacity(0.12))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .disabled(appState.isPreparingSync)
          .accessibilityIdentifier("google_sync_button")
        }

        if appState.isPreparingSync {
          HStack(spacing: 8) {
            ProgressView()
              .tint(Color.ironiqOrange)
            Text("Preparing sync folders…")
              .font(.footnote)
              .foregroundStyle(.white.opacity(0.7))
          }
        }

        if let errorMessage {
          Text(errorMessage)
            .font(.footnote)
            .foregroundStyle(Color.ironiqRed)
            .fixedSize(horizontal: false, vertical: true)
        }

        Text(
          "Ironiq creates Sessions and Templates folders in the drive you choose. Switching providers later will not move old history until migration is added."
        )
        .font(.caption)
        .foregroundStyle(.white.opacity(0.45))
        .fixedSize(horizontal: false, vertical: true)

        Spacer()
      }
      .padding(24)
    }
  }

  @MainActor
  private func handleGoogleSignIn() async {
    appState.isPreparingSync = true
    errorMessage = nil
    defer { appState.isPreparingSync = false }

    do {
      let account = try await GoogleDriveService.shared.connectAndPrepareSyncFolders()
      appState.completeSync(provider: .google, accountId: account.id, accountLabel: account.email)
    } catch GoogleDriveError.authorizationCancelled {
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
    appState.isPreparingSync = true
    errorMessage = nil
    defer { appState.isPreparingSync = false }

    do {
      let authorization = try result.get()
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
        errorMessage = "Apple login did not return a usable account. Try again."
        return
      }

      try await iCloudService.shared.prepareSyncFolders()
      let label = credential.email ?? credential.fullName?.formatted()
      appState.completeSync(provider: .apple, accountId: credential.user, accountLabel: label)
    } catch iCloudError.containerUnavailable {
      errorMessage =
        "iCloud Drive is not available. Sign into iCloud and enable iCloud Drive, then try again."
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

#Preview {
  ContentView()
    .environment(AppState())
    .environment(
      SessionViewModel(
        engine: SessionEngine(
          templateRepository: PreviewRepositories.template,
          sessionRepository: PreviewRepositories.session
        ))
    )
    .environment(
      TemplateViewModel(
        templateRepo: PreviewRepositories.template,
        exerciseRepo: PreviewRepositories.exercise
      )
    )
    .environment(
      HistoryViewModel(
        sessionRepo: PreviewRepositories.session,
        appState: AppState()
      )
    )
    .environment(SettingsViewModel())
}
