import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var notificationManager: NotificationManager
    @Environment(\.presentationMode) var presentationMode
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var showDeleteConfirm = false
    @State private var showSignOutConfirm = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Legal document sheets
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showCommunityGuidelines = false
    @State private var showCommunityRules = false
    @State private var showVerification = false
    @State private var verificationStatus: String = "unverified"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(Color.primary)
                    }
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Invisible placeholder for balance
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Account Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                // Sign Out Button
                                Button(action: {
                                    showSignOutConfirm = true
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.title3)
                                            .foregroundColor(.primary)
                                        
                                        Text("Sign Out")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Delete Account Button
                                Button(action: {
                                    showDeleteConfirm = true
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .font(.title3)
                                            .foregroundColor(.facebookBlue)
                                        
                                        Text("Delete Account")
                                            .font(.body)
                                            .foregroundColor(.facebookBlue)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // Verification Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Verification")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                Button(action: {
                                    showVerification = true
                                }) {
                                    HStack {
                                        Image(systemName: verificationStatus == "verified" ? "checkmark.seal.fill" : "checkmark.seal")
                                            .font(.title3)
                                            .foregroundColor(verificationStatus == "verified" ? .green : Color("ThemeColor"))
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(verificationStatusTitle)
                                                .font(.body)
                                                .foregroundColor(.primary)
                                            
                                            if verificationStatus != "unverified" {
                                                Text(verificationStatusSubtitle)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // Appearance Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Appearance")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                        .font(.title3)
                                        .foregroundColor(isDarkMode ? .indigo : .orange)
                                    
                                    Text("Dark Mode")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: $isDarkMode)
                                        .labelsHidden()
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // Testing Section - Only visible in Debug builds
                        #if DEBUG
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Testing")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                NavigationLink(destination: PushNotificationTestView()) {
                                    HStack {
                                        Image(systemName: "bell.badge")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        
                                        Text("Push Notification Test")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        #endif
                        
                        // Legal Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Legal")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                // Privacy Policy Button
                                Button(action: {
                                    showPrivacyPolicy = true
                                }) {
                                    HStack {
                                        Image(systemName: "hand.raised")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        
                                        Text("Privacy Policy")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Terms of Service Button
                                Button(action: {
                                    showTermsOfService = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        
                                        Text("Terms of Service")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Community Guidelines Button
                                Button(action: {
                                    showCommunityGuidelines = true
                                }) {
                                    HStack {
                                        Image(systemName: "person.3")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        
                                        Text("Community Guidelines")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Community Rules Button
                                Button(action: {
                                    showCommunityRules = true
                                }) {
                                    HStack {
                                        Image(systemName: "list.bullet.clipboard")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        
                                        Text("Community Rules")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .padding(.leading)
                                
                                // Contact Support Link (keep as external link)
                                Link(destination: URL(string: "mailto:darragh.b3272@gmail.com")!) {
                                    HStack {
                                        Image(systemName: "envelope")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                        
                                        Text("Contact Support")
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.up.right.square")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Version")
                                        .font(.body)
                                    
                                    Spacer()
                                    
                                    Text("1.0.0 (1)")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .alert("Sign Out?", isPresented: $showSignOutConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task { await signOut() }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteAccount() }
                }
            } message: {
                Text("This will permanently delete your CampusLink account and all associated data. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                LegalDocumentView(
                    title: "Privacy Policy",
                    content: LegalContent.privacyPolicy
                )
            }
            .sheet(isPresented: $showTermsOfService) {
                LegalDocumentView(
                    title: "Terms of Service",
                    content: LegalContent.termsOfService
                )
            }
            .sheet(isPresented: $showCommunityGuidelines) {
                LegalDocumentView(
                    title: "Community Guidelines",
                    content: LegalContent.communityGuidelines
                )
            }
            .sheet(isPresented: $showCommunityRules) {
                LegalDocumentView(
                    title: "Community Rules",
                    content: LegalContent.communityRules
                )
            }
            .sheet(isPresented: $showVerification) {
                StudentVerificationView()
                    .environmentObject(authManager)
            }
            .onAppear {
                Task {
                    await loadVerificationStatus()
                }
            }
        }
    }
    
    // MARK: - Verification Computed Properties
    
    private var verificationStatusTitle: String {
        switch verificationStatus {
        case "verified":
            return "Verified Student"
        case "pending":
            return "Verification Pending"
        case "rejected":
            return "Verification Failed"
        default:
            return "Become a Verified Student"
        }
    }
    
    private var verificationStatusSubtitle: String {
        switch verificationStatus {
        case "verified":
            return "Active"
        case "pending":
            return "Under review"
        case "rejected":
            return "Please resubmit"
        default:
            return ""
        }
    }
    
    private func loadVerificationStatus() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        do {
            let user: User = try await supabase
                .from("users")
                .select("verification_status")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.verificationStatus = user.verificationStatus ?? "unverified"
            }
        } catch {
            print("❌ Error loading verification status: \(error)")
        }
    }
    
    private func signOut() async {
        let result = await authManager.signOut()
        switch result {
        case .success:
            // Session will automatically redirect to login
            break
        case .failure(let error):
            await MainActor.run {
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
    }
    
    private func deleteAccount() async {
        do {
            // Delete the account from Supabase
            try await authManager.deleteCurrentUser()
            print("✅ Account deleted from Supabase")
            
            // Account deletion successful - user will be automatically signed out
            // by the auth state change listener when the session becomes invalid
            print("✅ Account deletion completed successfully")
            
            // Force sign out locally to ensure user gets signed out
            let signOutResult = await authManager.signOut()
            switch signOutResult {
            case .success:
                print("✅ User signed out successfully after deletion")
            case .failure(let error):
                print("⚠️ Sign out failed after deletion: \(error.localizedDescription)")
                // Don't show error to user since account was deleted
            }
            
        } catch {
            print("❌ Account deletion failed: \(error.localizedDescription)")
            
            // Check if this is a 404 error (edge function not deployed)
            let nsError = error as NSError
            if nsError.code == 404 {
                // Edge function not deployed - sign out user and show message
                print("⚠️ Edge function not deployed, signing out user")
                await MainActor.run {
                    alertMessage = nsError.localizedDescription
                    showingAlert = true
                }
                // Sign out the user since deletion isn't available
                let _ = await authManager.signOut()
            } else {
                // Show error to user
                await MainActor.run {
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthManager())
            .environmentObject(NotificationManager.shared)
    }
}
