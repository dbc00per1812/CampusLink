import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Home Tab
            HomeTabView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            // Search Tab
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            // Post Tab
            PostView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Post")
                }
            
            // Payments Tab
            PaymentsView()
                .tabItem {
                    Image(systemName: "dollarsign.circle.fill")
                    Text("Payments")
                }
            
            // Profile Tab
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
        }
        .accentColor(Color("ThemeColor"))
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthManager())
    }
} 