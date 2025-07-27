//
//  CampusLinkTestApp.swift
//  CampusLinkTest
//
//  Created by Eileen Murphy on 7/26/25.
//

import SwiftUI
import Supabase

let supabase = SupabaseClient(
  supabaseURL: Secrets.supabaseURL,
  supabaseKey: Secrets.supabaseKey
)

@main
struct CampusLinkTestApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}
