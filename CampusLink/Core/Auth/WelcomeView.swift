import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var showingLogin = false
    @State private var showingSignUp = false

    var body: some View {
        VStack {
                Spacer()
                
                Image(systemName: "graduationcap.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color("ThemeColor"))
                    .padding(.bottom, 20)

                Text("Welcome to CampusLink")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)

                Text("The best place to buy and sell on campus.")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Spacer()

                Button(action: { showingLogin = true }) {
                    Text("Log In")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color("ThemeColor"))
                        .cornerRadius(25)
                }
                .padding(.horizontal, 40)

                Button(action: { showingSignUp = true }) {
                    Text("Sign Up")
                        .fontWeight(.bold)
                        .foregroundColor(Color("ThemeColor"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color("ThemeColor"), lineWidth: 2)
                        )
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                
                Spacer().frame(height: 50)
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

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(AuthManager())
    }
} 