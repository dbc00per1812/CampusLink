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
    
    // Expose current user id for convenience in views
    var currentUserId: String? {
        session?.user.id.uuidString
    }

    private var authTask: Task<Void, Never>? = nil

    enum AuthError: Error {
        case invalidEmail
        case signUpFailed(Error)
        case signInFailed(Error)
        case profileUpdateFailed(Error)
        case signOutFailed(Error)
        case deleteFailed(Error)
        case passwordResetFailed(Error)
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
            print("🔄 Starting signup process for \(email)")
            
            // Create the user account
            print("🔄 Creating auth user...")
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["name": .string(name)]
            )
            
            print("✅ Auth user created successfully: \(authResponse.user.id)")
            
            // Immediately sign them in, bypassing any email confirmation
            print("🔄 Signing in user...")
            let signInResponse = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            print("✅ User signed in successfully: \(signInResponse.user.id)")
            
            // Update session immediately
            await MainActor.run {
                self.session = signInResponse
            }
            
            // Manually ensure user profile exists (more reliable than trigger)
            print("🔄 Creating user profile manually...")
            await ensureUserProfileExists(userId: signInResponse.user.id.uuidString, email: email, name: name)
            
            print("🎉 Signup completed successfully!")
            return .success(())
        } catch {
            print("❌ Signup error at step: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            
            // Try to provide more specific error information
            if error.localizedDescription.contains("User already registered") {
                print("ℹ️ User already exists - this might be expected")
                return .failure(.signUpFailed(NSError(domain: "Auth", code: 409, userInfo: [NSLocalizedDescriptionKey: "User already exists. Try signing in instead."])))
            }
            
            return .failure(.signUpFailed(error))
        }
    }
    
    // Manual user profile creation - more reliable than database triggers
    private func ensureUserProfileExists(userId: String, email: String, name: String) async {
        do {
            print("🔧 Ensuring user profile exists for \(userId)")
            
            // Try to create user profile manually
            let _: User = try await supabase
                .from("users")
                .insert([
                    "id": userId,
                    "email": email,
                    "name": name,
                    "created_at": ISO8601DateFormatter().string(from: Date()),
                    "campus_email_verified": email.hasSuffix(".edu") ? "true" : "false"
                ])
                .select()
                .single()
                .execute()
                .value
            
            print("✅ User profile created successfully")
            
            // Also create notification preferences
            try await supabase
                .from("user_notification_preferences")
                .insert(["user_id": userId])
                .execute()
            
            print("✅ Notification preferences created successfully")
            
        } catch {
            // Check if user already exists (which is fine)
            if error.localizedDescription.contains("duplicate") || 
               error.localizedDescription.contains("already exists") ||
               error.localizedDescription.contains("violates unique constraint") {
                print("ℹ️ User profile already exists - this is normal")
            } else {
                print("❌ Failed to create user profile: \(error)")
                // Don't throw error - signup already succeeded, profile creation is secondary
            }
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
    
    func resetPassword(email: String) async -> Result<Void, AuthError> {
        guard email.hasSuffix(".edu") else {
            return .failure(.invalidEmail)
        }
        
        do {
            print("🔄 Sending password reset to \(email)")
            
            // Build redirect URL with config parameters (more secure than hardcoding)
            let redirectURL = "https://campuslink-reset.netlify.app?supabase_url=\(Secrets.supabaseURL.absoluteString)&supabase_key=\(Secrets.supabaseKey)"
            
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: redirectURL)
            )
            
            print("✅ Password reset email sent successfully")
            return .success(())
        } catch {
            print("❌ Password reset failed: \(error)")
            return .failure(.passwordResetFailed(error))
        }
    }
    
    /// Verify OTP and set new password
    func verifyOTPAndSetPassword(email: String, otp: String, newPassword: String) async -> Result<Void, AuthError> {
        do {
            print("🔄 Verifying OTP and setting password...")
            
            // Verify the OTP first
            try await supabase.auth.verifyOTP(
                email: email,
                token: otp,
                type: .email
            )
            
            // Then update the password
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )
            
            print("✅ Password updated successfully via OTP")
            return .success(())
        } catch {
            print("❌ OTP verification or password update failed: \(error)")
            return .failure(.passwordResetFailed(error))
        }
    }
    
    /// Updates user password after reset token verification
    func updatePassword(newPassword: String) async -> Result<Void, AuthError> {
        do {
            print("🔄 Updating password...")
            
            try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )
            
            print("✅ Password updated successfully")
            return .success(())
        } catch {
            print("❌ Password update failed: \(error)")
            return .failure(.passwordResetFailed(error))
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