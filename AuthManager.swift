import Foundation
import Supabase

@MainActor
class AuthManager: ObservableObject {
    
    @Published var session: Session?

    private var authTask: Task<Void, Never>? = nil

    enum AuthError: Error {
        case invalidEmail
        case signUpFailed(Error)
        case signInFailed(Error)
        case profileUpdateFailed(Error)
        case signOutFailed(Error)
    }
    
    init() {
        authTask = Task {
            for await (_, session) in supabase.auth.authStateChanges {
                self.session = session
            }
        }
    }

    deinit {
        authTask?.cancel()
    }

    func signUp(email: String, password: String, name: String) async -> Result<Void, AuthError> {
        guard email.hasSuffix(".edu") else {
            return .failure(.invalidEmail)
        }

        do {
            let session = try await supabase.auth.signUp(
                email: email,
                password: password
            )

            let user = session.user
            let userProfile = ["name": name]

            do {
                try await supabase
                    .from("users")
                    .update(userProfile, returning: .minimal)
                    .eq("id", value: user.id)
                    .execute()
            } catch {
                return .failure(.profileUpdateFailed(error))
            }

            return .success(())
        } catch {
            return .failure(.signUpFailed(error))
        }
    }

    func signIn(email: String, password: String) async -> Result<Void, AuthError> {
        do {
            try await supabase.auth.signIn(email: email, password: password)
            return .success(())
        } catch {
            return .failure(.signInFailed(error))
        }
    }

    func signOut() async -> Result<Void, AuthError> {
        do {
            try await supabase.auth.signOut()
            return .success(())
        } catch {
            return .failure(.signOutFailed(error))
        }
    }
} 