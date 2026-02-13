import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    let authManager: AuthenticationManager
    @State private var currentPage: OnboardingPage = .welcome

    var body: some View {
        Group {
            switch currentPage {
            case .welcome:
                WelcomeScreen(onContinue: { currentPage = .guardrail })
            case .guardrail:
                GuardrailScreen(onContinue: { currentPage = .signIn })
            case .signIn:
                SignInView(authManager: authManager)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }
}

// MARK: - OnboardingPage

enum OnboardingPage: Int, Hashable {
    case welcome
    case guardrail
    case signIn
}

// MARK: - WelcomeScreen

struct WelcomeScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(.blue.opacity(0.8))

                VStack(spacing: 12) {
                    Text("Waterline")
                        .font(.largeTitle.bold())

                    Text("Waterline helps you pace and drink less by adding water breaks.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - GuardrailScreen

struct GuardrailScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.orange.opacity(0.8))

                VStack(spacing: 12) {
                    Text("Before you begin")
                        .font(.title2.bold())

                    Text("This is a pacing tool. It does not estimate intoxication or guarantee how you'll feel tomorrow.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("I understand")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
    }
}
