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
        RouterView(router: router) {
            if authManager.session != nil {
                MainTabView()
            } else {
                WelcomeView()
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
