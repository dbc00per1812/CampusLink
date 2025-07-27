import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 16) {
                    Image(systemName: "graduationcap.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Color("ThemeColor"))
                    
                    Text("Welcome to CampusLink")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    if let userEmail = authManager.session?.user.email {
                        Text("Hello, \(userEmail.components(separatedBy: "@").first ?? userEmail)")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("The best place to buy and sell on campus.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Quick actions or recent activity could go here
                VStack(spacing: 16) {
                    Text("Start exploring CampusLink")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Use the tabs below to search for items, post your own listings, manage payments, and customize your profile.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct HomeTabView_Previews: PreviewProvider {
    static var previews: some View {
        HomeTabView()
            .environmentObject(AuthManager())
    }
} 