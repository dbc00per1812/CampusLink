//
//  ContentView.swift
//  CampusLinkTest
//
//  Created by Eileen Murphy on 7/26/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var router = AppRouter.shared
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcomeSheet = false

    var body: some View {
        MainTabView()
            // Animate and force view reload on session change
            .id(authManager.session?.user.id.uuidString ?? "loggedOut")
            .animation(.easeInOut, value: authManager.session != nil)
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .sheet(isPresented: $showWelcomeSheet) {
                WelcomeView(showAsSheet: true, onDismiss: {
                    showWelcomeSheet = false
                    hasSeenWelcome = true
                })
                .environmentObject(authManager)
            }
            .onAppear {
                checkAndShowWelcome()
            }
            .onChange(of: authManager.session) { newSession in
                // If user signs in, mark welcome as seen and hide the sheet
                if newSession != nil {
                    hasSeenWelcome = true
                    showWelcomeSheet = false
                }
            }
    }
    
    private func checkAndShowWelcome() {
        // Only show welcome sheet if:
        // 1. User is NOT authenticated AND
        // 2. Haven't seen welcome before
        if authManager.session == nil && !hasSeenWelcome {
            // Delay slightly to ensure smooth animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showWelcomeSheet = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthManager())
    }
}
