import SwiftUI

struct SignUpView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var selectedCampus: Campus? = nil
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingOTPConfirmation = false
    
    // Legal acceptance
    @State private var acceptedTerms = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showCommunityGuidelines = false

    @EnvironmentObject private var authManager: AuthManager
    
    @Environment(\.presentationMode) var presentationMode
    
    // Computed property to combine first and last name
    private var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))".trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
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
                            TextField("First Name", text: $firstName)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                                .autocapitalization(.words)
                            
                            TextField("Last Name", text: $lastName)
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
                            
                            // Warning about school email
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Please use a personal email address, not your school email")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            
                            // Campus Picker
                            Menu {
                                ForEach(Campus.allCases, id: \.self) { campus in
                                    Button(action: {
                                        selectedCampus = campus
                                    }) {
                                        HStack {
                                            Text(campus.displayName)
                                            if let selected = selectedCampus, selected == campus {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCampus?.displayName ?? "Choose a campus")
                                        .foregroundColor(selectedCampus == nil ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(10)
                            }

                            ZStack(alignment: .trailing) {
                                if showPassword {
                                    TextField("Password", text: $password)
                                        .padding()
                                        .padding(.trailing, 40)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(10)
                                        .textContentType(.newPassword)
                                        .autocorrectionDisabled()
                                        .autocapitalization(.none)
                                } else {
                                    SecureField("Password", text: $password)
                                        .padding()
                                        .padding(.trailing, 40)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(10)
                                        .textContentType(.newPassword)
                                        .autocorrectionDisabled()
                                }
                                
                                Button(action: {
                                    showPassword.toggle()
                                }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 12)
                                }
                            }
                            
                            ZStack(alignment: .trailing) {
                                if showConfirmPassword {
                                    TextField("Confirm Password", text: $confirmPassword)
                                        .padding()
                                        .padding(.trailing, 40)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(10)
                                        .textContentType(.newPassword)
                                        .autocorrectionDisabled()
                                        .autocapitalization(.none)
                                } else {
                                    SecureField("Confirm Password", text: $confirmPassword)
                                        .padding()
                                        .padding(.trailing, 40)
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(10)
                                        .textContentType(.newPassword)
                                        .autocorrectionDisabled()
                                }
                                
                                Button(action: {
                                    showConfirmPassword.toggle()
                                }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 12)
                                }
                            }
                        }
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 24)
                        
                        // Legal Acceptance Section
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                acceptedTerms.toggle()
                            }) {
                                Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundColor(acceptedTerms ? Color("ThemeColor") : .gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("I accept the ")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                +
                                Text("Terms of Service")
                                    .font(.footnote)
                                    .foregroundColor(Color("ThemeColor"))
                                    .underline()
                                +
                                Text(", ")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                +
                                Text("Privacy Policy")
                                    .font(.footnote)
                                    .foregroundColor(Color("ThemeColor"))
                                    .underline()
                                +
                                Text(", and ")
                                    .font(.footnote)
                                    .foregroundColor(.primary)
                                +
                                Text("Community Guidelines")
                                    .font(.footnote)
                                    .foregroundColor(Color("ThemeColor"))
                                    .underline()
                                
                                // Individual links
                                HStack(spacing: 16) {
                                    Button("Terms") {
                                        showTermsOfService = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color("ThemeColor"))
                                    
                                    Button("Privacy") {
                                        showPrivacyPolicy = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color("ThemeColor"))
                                    
                                    Button("Guidelines") {
                                        showCommunityGuidelines = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(Color("ThemeColor"))
                                }
                                .padding(.top, 4)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 24)
                        .padding(.top, 12)

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
                                .background(acceptedTerms ? Color("ThemeColor") : Color.gray)
                                .cornerRadius(10)
                        }
                        .disabled(!acceptedTerms)
                        .opacity(acceptedTerms ? 1.0 : 0.6)
                        .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 60 : 24)
                        .padding(.top, 20)
                        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 40 : 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Dismiss keyboard when tapping on background
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
            )
            .fullScreenCover(isPresented: $showingOTPConfirmation) {
                OTPEmailConfirmationView(email: email, name: fullName, campus: selectedCampus?.rawValue ?? "")
                    .environmentObject(authManager)
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Sign Up Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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
        }
    }
    
    private func authenticate() async {
        print("🔄 Starting sign-up process for \(email)...")
        
        // Validate inputs
        guard !email.isEmpty, !password.isEmpty, !confirmPassword.isEmpty, !firstName.isEmpty, !lastName.isEmpty else {
            await MainActor.run {
                alertMessage = "Please fill in all fields."
                showingAlert = true
            }
            return
        }
        
        guard let campus = selectedCampus else {
            await MainActor.run {
                alertMessage = "Please select your campus."
                showingAlert = true
            }
            return
        }
        
        guard password == confirmPassword else {
            await MainActor.run {
                alertMessage = "Passwords do not match. Please try again."
                showingAlert = true
            }
            return
        }
        
        guard acceptedTerms else {
            await MainActor.run {
                alertMessage = "You must accept the Terms of Service, Privacy Policy, and Community Guidelines to continue."
                showingAlert = true
            }
            return
        }
        
        let result = await authManager.signUpWithEmailConfirmation(email: email, password: password, name: fullName, campus: campus.rawValue)
        
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
            alertMessage = "Please enter a valid email address."
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
