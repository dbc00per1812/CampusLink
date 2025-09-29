import SwiftUI

struct OTPEmailConfirmationView: View {
    let email: String
    let name: String
    
    @State private var otpCode = ""
    @State private var isConfirming = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isSuccessful = false
    
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Confirm Email")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Enter the verification code from your email to confirm your account")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                VStack(spacing: 16) {
                    // Email sent to
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verification email sent to:")
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
                }
                .padding()
                
                // Confirm button
                Button(action: confirmEmail) {
                    if isConfirming {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Confirming Email...")
                        }
                    } else {
                        Text("Confirm Email")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(!isFormValid || isConfirming)
                .padding(.horizontal)
                
                Button("Resend Code") {
                    Task {
                        await resendCode()
                    }
                }
                .foregroundColor(.blue)
                .padding(.top, 10)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .alert("Email Confirmation", isPresented: $showingAlert) {
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
        otpCode.count == 6
    }
    
    private func confirmEmail() {
        Task {
            await performEmailConfirmation()
        }
    }
    
    private func performEmailConfirmation() async {
        await MainActor.run {
            isConfirming = true
        }
        
        let result = await authManager.verifyEmailAndCompleteSignup(
            email: email,
            otp: otpCode,
            name: name
        )
        
        await MainActor.run {
            isConfirming = false
            
            switch result {
            case .success:
                alertMessage = "Email confirmed successfully! Welcome to CampusLink!"
                isSuccessful = true
                showingAlert = true
                
            case .failure(let error):
                switch error {
                case .emailConfirmationFailed(let underlyingError):
                    alertMessage = "Failed to confirm email: \(underlyingError.localizedDescription)"
                default:
                    alertMessage = "An error occurred. Please try again."
                }
                showingAlert = true
            }
        }
    }
    
    private func resendCode() async {
        let result = await authManager.signUpWithEmailConfirmation(
            email: email,
            password: "", // We don't have the password here, but might not need to resend
            name: name
        )
        
        await MainActor.run {
            switch result {
            case .success:
                alertMessage = "Verification code resent to \(email)"
                showingAlert = true
            case .failure(let error):
                switch error {
                case .signUpFailed(let underlyingError):
                    alertMessage = "Failed to resend code: \(underlyingError.localizedDescription)"
                default:
                    alertMessage = "Failed to resend code. Please try again."
                }
                showingAlert = true
            }
        }
    }
}

#Preview {
    OTPEmailConfirmationView(email: "test@iu.edu", name: "Test User")
        .environmentObject(AuthManager())
}
