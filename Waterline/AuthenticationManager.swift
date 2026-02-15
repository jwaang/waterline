import AuthenticationServices
import Foundation
import SwiftData

// MARK: - AuthCredentialStore Protocol

protocol AuthCredentialStore: Sendable {
    func save(key: String, value: String)
    func read(key: String) -> String?
    func delete(key: String)
}

// MARK: - AuthenticationManager

@Observable
@MainActor
final class AuthenticationManager {
    enum AuthState: Equatable, Hashable {
        case unknown
        case signedOut
        case signedIn(appleUserId: String)
    }

    private(set) var authState: AuthState = .unknown
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var isSignedIn: Bool {
        if case .signedIn = authState { return true }
        return false
    }

    var currentAppleUserId: String? {
        if case .signedIn(let id) = authState { return id }
        return nil
    }

    private let convexService: ConvexService?
    private let store: AuthCredentialStore
    private let keychainKey = "com.waterline.appleUserId"

    init(convexService: ConvexService? = nil, store: AuthCredentialStore = KeychainStore()) {
        self.convexService = convexService
        self.store = store
    }

    // MARK: - Restore Session

    func restoreSession(modelContext: ModelContext) {
        if let storedUserId = store.read(key: keychainKey) {
            authState = .signedIn(appleUserId: storedUserId)
            createLocalUserIfNeeded(appleUserId: storedUserId, modelContext: modelContext)
        } else {
            authState = .signedOut
        }
    }

    // MARK: - Handle Sign In With Apple Result

    func handleAuthorization(_ result: Result<ASAuthorization, any Error>, modelContext: ModelContext) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected credential type."
                return
            }
            processCredential(credential, modelContext: modelContext)

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Sign Out

    func signOut() {
        store.delete(key: keychainKey)
        authState = .signedOut
        errorMessage = nil
    }

    // MARK: - Dev Bypass

    #if DEBUG
    /// Bypasses Apple Sign In for development. Creates a local user with a stable dev ID.
    func devSignIn(modelContext: ModelContext) {
        let devAppleUserId = "dev-user-00000"
        store.save(key: keychainKey, value: devAppleUserId)
        authState = .signedIn(appleUserId: devAppleUserId)
        createLocalUserIfNeeded(appleUserId: devAppleUserId, modelContext: modelContext)
    }
    #endif

    // MARK: - Dismiss Error

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    private func processCredential(_ credential: ASAuthorizationAppleIDCredential, modelContext: ModelContext) {
        let appleUserId = credential.user

        let identityTokenString: String? = credential.identityToken.flatMap {
            String(data: $0, encoding: .utf8)
        }

        let email = credential.email
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let fullNameParam = fullName.isEmpty ? nil : fullName

        store.save(key: keychainKey, value: appleUserId)
        authState = .signedIn(appleUserId: appleUserId)

        createLocalUserIfNeeded(appleUserId: appleUserId, modelContext: modelContext)

        if let convexService, let token = identityTokenString {
            Task {
                await syncToConvex(
                    convexService: convexService,
                    token: token,
                    appleUserId: appleUserId,
                    email: email,
                    fullName: fullNameParam
                )
            }
        }
    }

    private func createLocalUserIfNeeded(appleUserId: String, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.appleUserId == appleUserId }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if existing.isEmpty {
            let user = User(appleUserId: appleUserId)
            modelContext.insert(user)
            try? modelContext.save()
        }
    }

    private func syncToConvex(
        convexService: ConvexService,
        token: String,
        appleUserId: String,
        email: String?,
        fullName: String?
    ) async {
        do {
            _ = try await convexService.verifyAndCreateUser(
                appleIdentityToken: token,
                appleUserId: appleUserId,
                email: email,
                fullName: fullName
            )
        } catch {
            // Convex sync failure is non-fatal — local state is authoritative
        }
    }
}

// MARK: - KeychainStore (Production)

struct KeychainStore: AuthCredentialStore {
    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(key: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - InMemoryCredentialStore (Testing)

final class InMemoryCredentialStore: AuthCredentialStore, @unchecked Sendable {
    private var storage: [String: String] = [:]

    func save(key: String, value: String) {
        storage[key] = value
    }

    func read(key: String) -> String? {
        storage[key]
    }

    func delete(key: String) {
        storage[key] = nil
    }
}
