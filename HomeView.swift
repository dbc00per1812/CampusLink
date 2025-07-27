import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        VStack {
            Spacer()
            
            if let userEmail = authManager.session?.user.email {
                Text("Welcome, \(userEmail)")
                    .font(.title)
            }
            
            Spacer()

            Button(action: {
                Task {
                    await authManager.signOut()
                }
            }) {
                Text("Sign Out")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("ThemeColor"))
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthManager())
    }
} 