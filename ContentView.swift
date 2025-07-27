//
//  ContentView.swift
//  CampusLinkTest
//
//  Created by Eileen Murphy on 7/26/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.session != nil {
                HomeView()
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
