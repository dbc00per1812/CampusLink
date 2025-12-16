import SwiftUI

/// Reusable component that prompts guests to sign in or sign up
/// Used for tabs and features that require authentication
struct GuestPromptView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showingLogin = false
    @State private var showingSignUp = false
    
    let icon: String
    let title: String
    let message: String
    
    init(
        icon: String = "person.circle",
        title: String = "Sign in required",
        message: String = "This feature requires an account"
    ) {
        self.icon = icon
        self.title = title
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(Color("ThemeColor"))
                .padding(.bottom, 8)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Button(action: { showingLogin = true }) {
                    Text("Log In")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color("ThemeColor"))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                
                Button(action: { showingSignUp = true }) {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(Color("ThemeColor"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("ThemeColor"), lineWidth: 2)
                        )
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authManager)
        }
    }
}

struct GuestPromptView_Previews: PreviewProvider {
    static var previews: some View {
        GuestPromptView()
            .environmentObject(AuthManager())
    }
}

