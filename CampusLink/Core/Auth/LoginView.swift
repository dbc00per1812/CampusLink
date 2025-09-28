import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isResettingPassword = false
    @State private var showingPasswordResetAlert = false
    @State private var passwordResetMessage = ""
    
    @EnvironmentObject private var authManager: AuthManager
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
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

            Text("Log In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 40)
            
            VStack(spacing: 20) {
                TextField("E-mail", text: $email)
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

            // Forgot Password Button
            HStack {
                Spacer()
                Button(action: {
                    Task {
                        await resetPassword()
                    }
                }) {
                    if isResettingPassword {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("ThemeColor")))
                            Text("Sending...")
                                .foregroundColor(Color("ThemeColor"))
                        }
                    } else {
                        Text("Forgot Password?")
                            .foregroundColor(Color("ThemeColor"))
                    }
                }
                .disabled(isResettingPassword || email.isEmpty)
                .opacity(email.isEmpty ? 0.5 : 1.0)
                Spacer()
            }
            .padding(.top, 8)
            
            Spacer()
            
            Button(action: {
                Task {
                    await authenticate()
                }
            }) {
                Text("Log In")
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
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Login Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Password Reset", isPresented: $showingPasswordResetAlert) {
            Button("OK") { }
        } message: {
            Text(passwordResetMessage)
        }
    }
    
    private func authenticate() async {
        let result = await authManager.signIn(email: email, password: password)
        
        if case .failure(let error) = result {
            if case .signInFailed(let underlyingError) = error {
                alertMessage = "Sign in failed: \(underlyingError.localizedDescription)"
                showingAlert = true
            }
        }
    }
    
    private func resetPassword() async {
        guard !email.isEmpty else {
            alertMessage = "Please enter your email address first"
            showingAlert = true
            return
        }
        
        await MainActor.run {
            isResettingPassword = true
        }
        
        let result = await authManager.resetPassword(email: email)
        
        await MainActor.run {
            isResettingPassword = false
            
            switch result {
            case .success:
                passwordResetMessage = "Password reset email sent to \(email). Check your inbox and follow the link to reset your password."
                showingPasswordResetAlert = true
            case .failure(let error):
                switch error {
                case .invalidEmail:
                    alertMessage = "Please use a valid .edu email address"
                case .passwordResetFailed(let underlyingError):
                    alertMessage = "Failed to send password reset email: \(underlyingError.localizedDescription)"
                default:
                    alertMessage = "Failed to send password reset email"
                }
                showingAlert = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthManager())
    }
} 