import AuthenticationServices
import SwiftUI
import SwiftData

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    let authManager: AuthenticationManager

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "drop.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Waterline")
                    .font(.largeTitle.bold())
                Text("Pace your drinking. Stay balanced.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if authManager.isLoading {
                ProgressView()
                    .controlSize(.large)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    authManager.handleAuthorization(result, modelContext: modelContext)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(10)
                .padding(.horizontal, 40)
            }

            Spacer()
                .frame(height: 48)
        }
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
