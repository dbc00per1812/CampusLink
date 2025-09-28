import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isUpdating = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var resetSuccessful = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.rotation")
                        .foregroundColor(Color("ThemeColor"))
                        .font(.system(size: 60))
                    
                    Text("Reset Your Password")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Enter your new password below")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Password Fields
                VStack(spacing: 16) {
                    // New Password
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("Enter new password", text: $newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Confirm Password
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Confirm Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    // Update Button
                    Button(action: {
                        Task {
                            await updatePassword()
                        }
                    }) {
                        if isUpdating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Updating...")
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("ThemeColor"))
                            .cornerRadius(10)
                        } else {
                            Text("Update Password")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("ThemeColor"))
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isUpdating || newPassword.isEmpty || confirmPassword.isEmpty)
                    .opacity(isUpdating || newPassword.isEmpty || confirmPassword.isEmpty ? 0.6 : 1.0)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Cancel Button
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
        .alert("Password Reset", isPresented: $showingAlert) {
            if resetSuccessful {
                Button("Continue") {
                    dismiss()
                }
            } else {
                Button("OK") { }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func updatePassword() async {
        guard !newPassword.isEmpty && !confirmPassword.isEmpty else {
            alertMessage = "Please fill in all fields"
            showingAlert = true
            return
        }
        
        guard newPassword == confirmPassword else {
            alertMessage = "Passwords do not match"
            showingAlert = true
            return
        }
        
        guard newPassword.count >= 6 else {
            alertMessage = "Password must be at least 6 characters long"
            showingAlert = true
            return
        }
        
        await MainActor.run {
            isUpdating = true
        }
        
        let result = await authManager.updatePassword(newPassword: newPassword)
        
        await MainActor.run {
            isUpdating = false
            
            switch result {
            case .success:
                alertMessage = "Password updated successfully! You can now sign in with your new password."
                resetSuccessful = true
                showingAlert = true
            case .failure(let error):
                switch error {
                case .passwordResetFailed(let underlyingError):
                    alertMessage = "Failed to update password: \(underlyingError.localizedDescription)"
                default:
                    alertMessage = "Failed to update password. Please try again."
                }
                showingAlert = true
            }
        }
    }
}

struct PasswordResetView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordResetView()
            .environmentObject(AuthManager())
    }
}
