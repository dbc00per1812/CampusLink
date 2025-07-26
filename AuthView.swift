import SwiftUI

struct AuthView: View {
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    @StateObject private var authManager = AuthManager()

    var body: some View {
        VStack {
            Text("CampusLink")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 30)

            Picker("Authentication", selection: $isSignUp) {
                Text("Sign In").tag(false)
                Text("Sign Up").tag(true)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            Form {
                Section(header: Text(isSignUp ? "Create an account" : "Sign in to your account")) {
                    if isSignUp {
                        TextField("Name", text: $name)
                            .autocapitalization(.words)
                    }
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                }
            }
            .frame(height: isSignUp ? 230 : 180)


            Button(action: {
                Task {
                    await authenticate()
                }
            }) {
                Text(isSignUp ? "Sign Up" : "Sign In")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Authentication Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func authenticate() async {
        let result = isSignUp
            ? await authManager.signUp(email: email, password: password, name: name)
            : await authManager.signIn(email: email, password: password)

        switch result {
        case .success:
            // Navigate to main content view
            print("Authentication successful")
        case .failure(let error):
            handle(error)
        }
    }

    private func handle(_ error: AuthManager.AuthError) {
        switch error {
        case .invalidEmail:
            alertMessage = "Please use a valid .edu email address."
        case .signUpFailed(let underlyingError):
            alertMessage = "Sign up failed: \(underlyingError.localizedDescription)"
        case .signInFailed(let underlyingError):
            alertMessage = "Sign in failed: \(underlyingError.localizedDescription)"
        case .profileUpdateFailed(let underlyingError):
            alertMessage = "Could not update profile: \(underlyingError.localizedDescription)"
        }
        showingAlert = true
    }
}


struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
} 