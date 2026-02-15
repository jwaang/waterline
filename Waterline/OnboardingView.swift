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
        .animation(.easeInOut(duration: 0.15), value: currentPage)
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
                Text("WATERLINE")
                    .font(.wlDisplayLarge)
                    .foregroundStyle(Color.wlInk)

                Text("Waterline helps you pace and drink less by adding water breaks.")
                    .font(.wlBody)
                    .foregroundStyle(Color.wlSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            WLActionBlock(label: "Continue", action: onContinue)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
        }
        .background(Color.wlBase)
    }
}

// MARK: - GuardrailScreen

struct GuardrailScreen: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Text("NOTICE")
                    .wlTechnical()

                VStack(spacing: 12) {
                    Text("Before you begin")
                        .font(.wlHeadline)
                        .foregroundStyle(Color.wlInk)

                    Text("This is a pacing tool. It does not estimate intoxication or guarantee how you'll feel tomorrow.")
                        .font(.wlBody)
                        .foregroundStyle(Color.wlSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()

            WLActionBlock(label: "I understand", action: onContinue)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
        }
        .background(Color.wlBase)
    }
}
