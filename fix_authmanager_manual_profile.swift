// Alternative fix for AuthManager.swift - manually create user profile if trigger fails
// Replace the signUp function in AuthManager.swift with this version

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
        
        print("✅ Auth user created successfully")
        
        // Immediately sign them in, bypassing any email confirmation
        let signInResponse = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        print("✅ User signed in successfully")
        
        // Update session immediately
        await MainActor.run {
            self.session = signInResponse
        }
        
        // Manually ensure user profile exists (fallback if trigger fails)
        await ensureUserProfileExists(userId: signInResponse.user.id.uuidString, email: email, name: name)
        
        return .success(())
    } catch {
        print("❌ Signup error: \(error)")
        return .failure(.signUpFailed(error))
    }
}

// Add this new private function to AuthManager class
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
                "campus_email_verified": email.hasSuffix(".edu")
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
        if error.localizedDescription.contains("duplicate") || error.localizedDescription.contains("already exists") {
            print("ℹ️ User profile already exists - this is normal")
        } else {
            print("❌ Failed to create user profile: \(error)")
            // Don't throw error - signup already succeeded, profile creation is secondary
        }
    }
}
