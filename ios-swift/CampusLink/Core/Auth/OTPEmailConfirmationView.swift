import SwiftUI

struct OTPEmailConfirmationView: View {
    let email: String
    let name: String
    let campus: String
    
    @State private var otpCode = ""
    @State private var isConfirming = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingInterestSelection = false
    
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Debug info
                Text("Debug: OTP Screen Loaded")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
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
                    
                    // Spam folder tip
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Didn't receive it? Check your spam/junk folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    
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
        .onAppear {
            print("🎯 OTP Email Confirmation View appeared!")
            print("🎯 Email: \(email)")
            print("🎯 Name: \(name)")
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .fullScreenCover(isPresented: $showingInterestSelection) {
            InterestSelectionView(onComplete: {
                // Interest selection complete - session is now activated
                // Navigate to home tab
                TabCoordinator.shared.navigateToTab(.home)
                // Dismiss the entire sign-up flow
                presentationMode.wrappedValue.dismiss()
            })
            .environmentObject(authManager)
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
                // Directly show interest selection on success (no alert needed)
                print("✅ Email confirmed! Showing interest selection...")
                showingInterestSelection = true
                
            case .failure(let error):
                // Only show alert on error
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
            name: name,
            campus: campus
        )
        
        await MainActor.run {
            switch result {
            case .success(_):
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
    OTPEmailConfirmationView(email: "test@iu.edu", name: "Test User", campus: "Indiana University Bloomington")
        .environmentObject(AuthManager())
}
