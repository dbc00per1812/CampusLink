import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Home Tab
            HomeTabView()
                .tabItem {
                    Image(systemName: "house.fill")
                        .font(.system(size: 40))
                }
            
            // Messages Tab
            ConversationListView()
                .tabItem {
                    Image(systemName: "message.fill")
                        .font(.system(size: 40))
                }
            
            // Post Tab
            PostView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                }
            
            // My Listings Tab
            PaymentsView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 40))
                }
            
            // Profile Tab
            ProfileTabView()
                .tabItem {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
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