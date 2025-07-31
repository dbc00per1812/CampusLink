import Foundation
import Supabase

struct UserProfileCreate: Codable {
    let id: String
    let email: String
    let name: String
    let bio: String?
    
    init(id: String, email: String, name: String, bio: String? = nil) {
        self.id = id
        self.email = email
        self.name = name
        self.bio = bio
    }
}

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
        // Get initial session if exists
        Task {
            do {
                let currentSession = try await supabase.auth.session
                await MainActor.run {
                    self.session = currentSession
                }
            } catch {
                // No existing session, which is fine
            }
        }
        
        // Listen for auth changes
        authTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    self.session = session
                }
                
                // If user just signed in/confirmed email, ensure profile exists
                if let session = session {
                    await ensureProfileExists(for: session)
                }
            }
        }
    }
    
    private func ensureProfileExists(for session: Session) async {
        do {
            // Check if profile already exists
            let existingProfile: [UserProfile] = try await supabase
                .from("users")
                .select()
                .eq("id", value: session.user.id)
                .execute()
                .value
            
            // If no profile exists, create one from user metadata
            if existingProfile.isEmpty {
                let name = session.user.userMetadata["name"]?.stringValue ?? ""
                let newProfile = UserProfileCreate(
                    id: session.user.id.uuidString,
                    email: session.user.email ?? "",
                    name: name
                )
                
                try await supabase
                    .from("users")
                    .insert(newProfile, returning: .minimal)
                    .execute()
                
                print("✅ AuthManager: Created profile for confirmed user")
            }
        } catch {
            print("❌ AuthManager: Failed to ensure profile exists: \(error)")
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
            // Create the user account
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            
            // Immediately sign them in, bypassing any email confirmation
            let signInResponse = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
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