import SwiftUI

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingOTPConfirmation = false

    @EnvironmentObject private var authManager: AuthManager
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(Color.primary)
                    }
                    Spacer()
                }
                .padding()

                Text("Sign Up")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 40)

                VStack(spacing: 20) {
                    TextField("Full Name", text: $name)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        .autocapitalization(.words)

                    TextField("E-mail Address", text: $email)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()

                Button(action: {
                    Task {
                        await authenticate()
                    }
                }) {
                    Text("Create Account")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("ThemeColor"))
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationBarHidden(true)
            .hideKeyboardOnTap()
            .fullScreenCover(isPresented: $showingOTPConfirmation) {
                OTPEmailConfirmationView(email: email, name: name)
                    .environmentObject(authManager)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Sign Up Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func authenticate() async {
        print("🔄 Starting sign-up process for \(email)...")
        
        // Validate inputs
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            await MainActor.run {
                alertMessage = "Please fill in all fields."
                showingAlert = true
            }
            return
        }
        
        guard email.hasSuffix(".edu") else {
            await MainActor.run {
                alertMessage = "Please use a valid .edu email address."
                showingAlert = true
            }
            return
        }
        
        let result = await authManager.signUpWithEmailConfirmation(email: email, password: password, name: name)
        
        switch result {
        case .success:
            print("✅ Sign-up successful! Email confirmation required.")
            await MainActor.run {
                // Show OTP screen immediately - no alert needed
                showingOTPConfirmation = true
                print("📱 Showing OTP confirmation screen")
            }
            
        case .failure(let error):
            print("❌ Sign-up failed: \(error)")
            handle(error)
        }
    }

    private func handle(_ error: AuthManager.AuthError) {
        switch error {
        case .invalidEmail:
            alertMessage = "Please use a valid .edu email address."
        case .signUpFailed(let underlyingError):
            alertMessage = "Sign up failed: \(underlyingError.localizedDescription)"
        case .profileUpdateFailed(let underlyingError):
            alertMessage = "Could not update profile: \(underlyingError.localizedDescription)"
        case .deleteFailed(let underlyingError):
            alertMessage = "Delete account failed: \(underlyingError.localizedDescription)"
        case .signInFailed:
            // This case is not applicable here but is needed for the switch to be exhaustive.
            break
        case .signOutFailed:
            // This case is not applicable here but is needed for the switch to be exhaustive.
            break
        case .emailConfirmationRequired:
            alertMessage = "Email confirmation is required. Please check your inbox."
        case .emailConfirmationFailed(let underlyingError):
            alertMessage = "Email confirmation failed: \(underlyingError.localizedDescription)"
        case .passwordResetFailed:
            // This case is not applicable here but is needed for the switch to be exhaustive.
            break
        }
        showingAlert = true
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthManager())
    }
}
