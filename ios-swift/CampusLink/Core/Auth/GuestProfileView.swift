import SwiftUI

/// Profile tab view for guest (unauthenticated) users
struct GuestProfileView: View {
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("guestSelectedCampus") private var guestSelectedCampus: String = ""
    @State private var showingLogin = false
    @State private var showingSignUp = false
    @State private var showingCampusSelection = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Guest profile info section
                    guestInfoSection
                    
                    // Settings section
                    settingsSection
                    
                    // Legal links section
                    legalSection
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingSignUp) {
            SignUpView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showingCampusSelection) {
            GuestCampusSelectionView(onCampusSelected: {})
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Profile")
                .responsiveFont(.largeTitle, weight: .bold)
            
            Spacer()
        }
        .responsiveHorizontalSpacing(16)
        .responsiveSpacing(10)
    }
    
    private var guestInfoSection: some View {
        ResponsiveVStack(spacing: 20) {
            // Guest avatar
            Circle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                )
            
            // Guest info
            ResponsiveVStack(spacing: 8) {
                Text("Guest User")
                    .responsiveFont(.title2, weight: .semibold)
                
                Text("Sign in to access all features")
                    .responsiveFont(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Auth buttons
            VStack(spacing: 12) {
                Button(action: { showingLogin = true }) {
                    Text("Log In")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .responsiveSpacing(12)
                        .background(Color("ThemeColor"))
                        .responsiveCornerRadius(12)
                }
                
                Button(action: { showingSignUp = true }) {
                    Text("Sign Up")
                        .fontWeight(.semibold)
                        .foregroundColor(Color("ThemeColor"))
                        .frame(maxWidth: .infinity)
                        .responsiveSpacing(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("ThemeColor"), lineWidth: 2)
                        )
                }
            }
            .responsiveHorizontalSpacing(40)
        }
        .responsiveSpacing(20)
        .responsiveHorizontalSpacing(16)
    }
    
    private var settingsSection: some View {
        ResponsiveVStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Settings")
                    .responsiveFont(.headline, weight: .semibold)
                Spacer()
            }
            .responsiveHorizontalSpacing(16)
            .responsiveSpacing(12)
            
            Divider()
            
            // Campus Selection
            Button(action: { showingCampusSelection = true }) {
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(Color("ThemeColor"))
                        .frame(width: 24)
                    
                    Text("Campus")
                        .responsiveFont(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if !guestSelectedCampus.isEmpty {
                        Text(campusAbbreviation(guestSelectedCampus))
                            .responsiveFont(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .responsiveSpacing(16)
                .responsiveHorizontalSpacing(16)
            }
            .background(Color(UIColor.secondarySystemBackground))
            
            Divider()
                .padding(.leading, 56)
            
            // Dark Mode Toggle
            HStack {
                Image(systemName: "moon.fill")
                    .foregroundColor(Color("ThemeColor"))
                    .frame(width: 24)
                
                Text("Dark Mode")
                    .responsiveFont(.body)
                
                Spacer()
                
                Toggle("", isOn: $isDarkMode)
                    .labelsHidden()
            }
            .responsiveSpacing(16)
            .responsiveHorizontalSpacing(16)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .responsiveSpacing(8)
    }
    
    private var legalSection: some View {
        ResponsiveVStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Legal")
                    .responsiveFont(.headline, weight: .semibold)
                Spacer()
            }
            .responsiveHorizontalSpacing(16)
            .responsiveSpacing(12)
            
            Divider()
            
            // Legal links
            VStack(spacing: 0) {
                legalLink(title: "Privacy Policy", url: "https://dbc00per1812.github.io/CampusLink/privacy.html")
                
                Divider()
                    .padding(.leading, 56)
                
                legalLink(title: "Terms of Service", url: "https://dbc00per1812.github.io/CampusLink/terms.html")
            }
            .background(Color(UIColor.secondarySystemBackground))
        }
        .responsiveSpacing(8)
    }
    
    private func legalLink(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(Color("ThemeColor"))
                    .frame(width: 24)
                
                Text(title)
                    .responsiveFont(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .responsiveSpacing(16)
            .responsiveHorizontalSpacing(16)
        }
    }
    
    private func campusAbbreviation(_ campus: String) -> String {
        switch campus {
        case "Indiana University Bloomington":
            return "IU"
        case "Purdue University":
            return "Purdue"
        case "UIUC":
            return "UIUC"
        default:
            return campus
        }
    }
}

struct GuestProfileView_Previews: PreviewProvider {
    static var previews: some View {
        GuestProfileView()
            .environmentObject(AuthManager())
    }
}

