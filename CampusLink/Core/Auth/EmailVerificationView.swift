import SwiftUI

struct EmailVerificationView: View {
    let email: String
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isResending = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "envelope.circle")
                .font(.system(size: 80))
                .foregroundColor(Color("ThemeColor"))
            
            VStack(spacing: 16) {
                Text("Check Your Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("We sent a verification link to:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(email)
                    .font(.headline)
                    .foregroundColor(Color("ThemeColor"))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("ThemeColor").opacity(0.1))
                    )
            }
            
            VStack(spacing: 12) {
                Text("Click the link in your email to verify your account. You can close this app and return after clicking the link.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("The app will automatically log you in once verified.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        await resendVerificationEmail()
                    }
                }) {
                    HStack {
                        if isResending {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isResending ? "Sending..." : "Resend Email")
                    }
                    .fontWeight(.medium)
                    .foregroundColor(Color("ThemeColor"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color("ThemeColor"), lineWidth: 2)
                    )
                }
                .disabled(isResending)
                .padding(.horizontal)
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Back to Sign Up")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer().frame(height: 50)
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Resend Email"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    private func resendVerificationEmail() async {
        await MainActor.run {
            isResending = true
        }
        
        do {
            try await supabase.auth.resend(email: email, type: .signup)
            await MainActor.run {
                alertMessage = "Verification email sent successfully!"
                showingAlert = true
                isResending = false
            }
        } catch {
            await MainActor.run {
                alertMessage = "Failed to resend email. Please try again."
                showingAlert = true
                isResending = false
            }
        }
    }
}

struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailVerificationView(email: "test@university.edu")
            .environmentObject(AuthManager())
    }
} 