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
                        .padding()
                        .background(Color("ThemeColor"))
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                NavigationLink(destination: SignUpView().environmentObject(authManager)) {
                    Text("Sign Up")
                        .fontWeight(.bold)
                        .foregroundColor(Color("ThemeColor"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("ThemeColor"), lineWidth: 2)
                        )
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
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