import SwiftUI

struct OTPPasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    let email: String
    
    @State private var otp = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isVerifying = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var resetSuccessful = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "envelope.badge")
                        .foregroundColor(Color("ThemeColor"))
                        .font(.system(size: 60))
                    
                    Text("Check Your Email")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Enter the verification code sent to \(email)")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Form Fields
                VStack(spacing: 16) {
                    // OTP Code
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verification Code")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter 6-digit code", text: $otp)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    
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
                    
                    // Reset Button
                    Button(action: {
                        Task {
                            await resetPassword()
                        }
                    }) {
                        if isVerifying {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Resetting Password...")
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("ThemeColor"))
                            .cornerRadius(10)
                        } else {
                            Text("Reset Password")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("ThemeColor"))
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isVerifying || otp.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                    .opacity(isVerifying || otp.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty ? 0.6 : 1.0)
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
    
    private func resetPassword() async {
        guard !otp.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty else {
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
            isVerifying = true
        }
        
        let result = await authManager.verifyOTPAndSetPassword(
            email: email,
            otp: otp,
            newPassword: newPassword
        )
        
        await MainActor.run {
            isVerifying = false
            
            switch result {
            case .success:
                alertMessage = "Password reset successfully! You can now sign in with your new password."
                resetSuccessful = true
                showingAlert = true
            case .failure(let error):
                switch error {
                case .passwordResetFailed(let underlyingError):
                    alertMessage = "Failed to reset password: \(underlyingError.localizedDescription)"
                default:
                    alertMessage = "Failed to reset password. Please check your verification code and try again."
                }
                showingAlert = true
            }
        }
    }
}

struct OTPPasswordResetView_Previews: PreviewProvider {
    static var previews: some View {
        OTPPasswordResetView(email: "test@iu.edu")
            .environmentObject(AuthManager())
    }
}
