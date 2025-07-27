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
                .onOpenURL { url in
                    Task {
                        do {
                            try await supabase.auth.session(from: url)
                            print("✅ Successfully handled auth URL: \(url)")
                        } catch {
                            print("❌ Failed to handle auth URL: \(error)")
                        }
                    }
                }
        }
    }
}
