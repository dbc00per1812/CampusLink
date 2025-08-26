import SwiftUI

struct SignUpView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

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
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Sign Up Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func authenticate() async {
        #if DEBUG
        print("🔄 Starting sign-up process...")
        #endif
        let result = await authManager.signUp(email: email, password: password, name: name)
        
        switch result {
        case .success:
            #if DEBUG
            print("✅ Sign-up successful!")
            #endif
            // User will be automatically redirected via AuthManager session change
        case .failure(let error):
            #if DEBUG
            print("❌ Sign-up failed: \(error)")
            #endif
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
