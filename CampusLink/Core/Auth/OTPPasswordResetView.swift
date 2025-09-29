import SwiftUI

struct OTPPasswordResetView: View {
    let email: String
    
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isResetting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccessful = false
    
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Reset Password")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Enter the code from your email and choose a new password")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 16) {
                    // Email sent to
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email sent to:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    // OTP Code input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verification Code")
                            .font(.headline)
                        
                        TextField("Enter 6-digit code", text: $otpCode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                    }
                    
                    // New password inputs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.headline)
                        
                        SecureField("Enter new password", text: $newPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                        
                        SecureField("Confirm new password", text: $confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.newPassword)
                    }
                }
                .padding()
                
                // Reset button
                Button(action: resetPassword) {
                    if isResetting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Resetting Password...")
                        }
                    } else {
                        Text("Reset Password")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isFormValid || isResetting)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .alert("Password Reset", isPresented: $showingAlert) {
            Button("OK") {
                if isSuccessful {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        otpCode.count == 6 && 
        newPassword.count >= 6 && 
        newPassword == confirmPassword
    }
    
    private func resetPassword() {
        Task {
            await performPasswordReset()
        }
    }
    
    private func performPasswordReset() async {
        await MainActor.run {
            isResetting = true
        }
        
        let result = await authManager.verifyOTPAndResetPassword(
            email: email,
            otp: otpCode,
            newPassword: newPassword
        )
        
        await MainActor.run {
            isResetting = false
            
            switch result {
            case .success:
                alertMessage = "Password reset successfully! You can now sign in with your new password."
                isSuccessful = true
                showingAlert = true
                
            case .failure(let error):
                switch error {
                case .passwordResetFailed(let underlyingError):
                    alertMessage = "Failed to reset password: \(underlyingError.localizedDescription)"
                default:
                    alertMessage = "An error occurred. Please try again."
                }
                showingAlert = true
            }
        }
    }
}

#Preview {
    OTPPasswordResetView(email: "test@iu.edu")
        .environmentObject(AuthManager())
}
