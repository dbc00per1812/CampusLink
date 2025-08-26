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
        case deleteFailed(Error)
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
                
                // Profile creation is now handled by database trigger automatically
                // No manual profile creation needed
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
            
            // Update session immediately
            await MainActor.run {
                self.session = signInResponse
            }
            
            return .success(())
        } catch {
            return .failure(.signUpFailed(error))
        }
    }

    func signIn(email: String, password: String) async -> Result<Void, AuthError> {
        do {
            let response = try await supabase.auth.signIn(email: email, password: password)
            
            // Update session immediately
            await MainActor.run {
                self.session = response
            }
            
            return .success(())
        } catch {
            return .failure(.signInFailed(error))
        }
    }

    func signOut() async -> Result<Void, AuthError> {
        do {
            try await supabase.auth.signOut()
            
            // Clear session immediately
            await MainActor.run {
                self.session = nil
            }
            
            return .success(())
        } catch {
            return .failure(.signOutFailed(error))
        }
    }

    /// Deletes the currently authenticated user account from Supabase via edge function.
    func deleteCurrentUser() async throws {
        // Build edge function URL similar to PaymentService helper
        let base = Secrets.supabaseURL.absoluteString
        guard base.hasPrefix("https://"), base.hasSuffix(".supabase.co") else {
            throw AuthError.deleteFailed(NSError(domain: "AuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL"]))
        }
        let ref = base
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: ".supabase.co", with: "")
        guard let url = URL(string: "https://\(ref).functions.supabase.co/delete_user") else {
            throw AuthError.deleteFailed(NSError(domain: "AuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid edge function URL"]))
        }

        guard session?.accessToken != nil else {
            throw AuthError.deleteFailed(NSError(domain: "AuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No active session"]))
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = session?.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Send empty body - edge function will use the token to identify the user
        req.httpBody = try JSONEncoder().encode([String: String]())

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.deleteFailed(NSError(domain: "AuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AuthError.deleteFailed(NSError(domain: "AuthManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message]))
        }
        // On success, the caller should sign out and clear local state.
    }
} 