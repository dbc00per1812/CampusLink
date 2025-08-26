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

    var body: some View {
        Group {
            if authManager.session != nil {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        // Animate and force view reload on session change
        .id(authManager.session?.user.id.uuidString ?? "loggedOut")
        .animation(.easeInOut, value: authManager.session != nil)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthManager())
    }
}
