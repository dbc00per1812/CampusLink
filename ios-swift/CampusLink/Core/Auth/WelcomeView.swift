import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogin = false
    @State private var showingSignUp = false
    @State private var showingCampusSelection = false
    
    let showAsSheet: Bool
    let onDismiss: (() -> Void)?
    
    init(showAsSheet: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.showAsSheet = showAsSheet
        self.onDismiss = onDismiss
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack {
                    Spacer()
                        .frame(height: geometry.size.height * 0.15)
                    
                    Image("BrandIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .padding(.bottom, 20)

                    Text("Welcome to CampusLink")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)

                    Text("The best place to buy and sell on campus.")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Spacer()
                        .frame(height: geometry.size.height * 0.1)

                    VStack(spacing: 12) {
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
                        
                        // Browse as Guest option if shown as sheet
                        if showAsSheet {
                            Button(action: { 
                                showingCampusSelection = true
                            }) {
                                Text("Browse as Guest")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 16)
                            }
                        }
                    }
                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .pad ? 100 : 40)
                    
                    Spacer()
                        .frame(height: geometry.size.height * 0.15)
                }
                .frame(minHeight: geometry.size.height)
            }
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
            GuestCampusSelectionView(onCampusSelected: {
                onDismiss?()
                if showAsSheet {
                    dismiss()
                }
            })
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
            .environmentObject(AuthManager())
    }
} 