import AuthenticationServices
import SwiftUI
import SwiftData

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    let authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("WATERLINE")
                    .font(.wlDisplayLarge)
                    .foregroundStyle(Color.wlInk)

                Text("PACING INSTRUMENT")
                    .wlTechnical()
            }

            Spacer()

            if authManager.isLoading {
                WLStatusFlag("AUTHENTICATING")
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleAuthorization(result, modelContext: modelContext)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(Rectangle())
                .padding(.horizontal, 40)
            }

            #if DEBUG
            Button("Dev Sign In (Skip Apple)") {
                authManager.devSignIn(modelContext: modelContext)
            }
            .font(.wlTechnicalMono)
            .foregroundStyle(Color.wlSecondary)
            #endif

            Spacer()
                .frame(height: 48)
        }
        .background(Color.wlBase)
        .alert("Sign In Error", isPresented: .init(
            get: { authManager.errorMessage != nil },
            set: { if !$0 { authManager.dismissError() } }
        )) {
            Button("Try Again", role: .cancel) {
                authManager.dismissError()
            }
        } message: {
            if let msg = authManager.errorMessage {
                Text(msg)
            }
        }
    }
}
