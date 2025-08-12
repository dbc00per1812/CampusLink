import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        NavigationView {
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

                NavigationLink(destination: LoginView().environmentObject(authManager)) {
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

                NavigationLink(destination: SignUpView().environmentObject(authManager)) {
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
            .navigationBarHidden(true)
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(AuthManager())
    }
} 