import SwiftUI

// Simple struct just for fetching email
private struct UserEmailFetch: Codable {
    let email: String?
}

struct HomeTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var listings: [ListingWithUser] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var currentPage = 0
    
    private let pageSize = 10
    
    // Domain filtering - DISABLED for App Store submission
    // The filter has issues with the current Supabase query structure
    // TODO: Fix post-launch with proper RPC function
    private let enableDomainFilter = false  // Disabled for v1.0 release

    var body: some View {
        VStack {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            if let userEmail = authManager.session?.user.email {
                                Text("Hello, \(userEmail.components(separatedBy: "@").first ?? userEmail)!")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            Text("Welcome to CampusLink")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "graduationcap.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color("ThemeColor"))
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Listings Feed
                if isLoading {
                    Spacer()
                    ProgressView("Loading listings...")
                    Spacer()
                } else if listings.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.below.rectangle")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No listings yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Be the first to post something for sale!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(listings) { listing in
                                NavigationLink(destination: ListingDetailView(listing: listing)) {
                                    ListingCard(listing: listing)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    // Load more when we reach the last few items
                                    if listing.id == listings.suffix(3).first?.id {
                                        Task {
                                            await loadMoreListings()
                                        }
                                    }
                                }
                            }
                            
                            // Loading indicator at the bottom
                            if isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                            }
                            
                            // End of list indicator
                            if !hasMorePages && !listings.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("You've reached the end")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshListings()
                    }
                }
        }
        .onAppear {
            // Clear any stale payment state when returning to home
            PaymentService.shared.paymentResult = nil
            PaymentService.shared.paymentSheet = nil
            
            Task {
                await loadListings()
            }
        }
    }
    
    private func loadListings() async {
        
        await MainActor.run {
            isLoading = true
            currentPage = 0
            hasMorePages = true
        }
        
        do {
            let from = 0
            let to = pageSize - 1
            
            // Build query based on whether domain filtering is enabled
            var query = supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
            
            // Apply domain filter if enabled (currently disabled for v1.0)
            if enableDomainFilter {
                // Try to get email from session first
                var userEmail: String? = authManager.session?.user.email
                
                // If no email in session, fetch from database
                if userEmail == nil, let userId = authManager.session?.user.id.uuidString {
                    do {
                        let userResponse: [UserEmailFetch] = try await supabase
                            .from("users")
                            .select("email")
                            .eq("id", value: userId)
                            .execute()
                            .value
                        
                        if let profile = userResponse.first {
                            userEmail = profile.email
                        }
                    } catch {
                        // Silently fail and show all listings
                    }
                }
                
                // Apply filter if we have an email
                if let email = userEmail,
                   let domain = email.components(separatedBy: "@").last {
                    query = query.ilike("user.email", pattern: "%@\(domain)")
                }
            }
            
            // Apply ordering and pagination
            let response: [ListingWithUser] = try await query
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
            
            await MainActor.run {
                self.listings = response
                self.isLoading = false
                self.currentPage = 1
                self.hasMorePages = response.count == pageSize
            }
            
        } catch {
            #if DEBUG
            print("Failed to load listings: \(error)")
            #endif
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadMoreListings() async {
        guard !isLoadingMore, hasMorePages else { return }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        do {
            let from = currentPage * pageSize
            let to = from + pageSize - 1
            
            // Build query based on whether domain filtering is enabled
            var query = supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
            
            // Domain filter disabled for v1.0
            // Future: Add domain filtering in v1.1
            
            let response: [ListingWithUser] = try await query
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
            
            await MainActor.run {
                self.listings.append(contentsOf: response)
                self.currentPage += 1
                self.hasMorePages = response.count == pageSize
                self.isLoadingMore = false
            }
            
        } catch {
            #if DEBUG
            print("Failed to load more listings: \(error)")
            #endif
            await MainActor.run {
                self.isLoadingMore = false
            }
        }
    }
    
    private func refreshListings() async {
        await MainActor.run {
            currentPage = 0
            hasMorePages = true
        }
        
        do {
            let from = 0
            let to = pageSize - 1
            
            // Build query based on whether domain filtering is enabled
            var query = supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
            
            // Domain filter disabled for v1.0
            // Future: Add domain filtering in v1.1
            
            let response: [ListingWithUser] = try await query
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
            
            await MainActor.run {
                self.listings = response
                self.currentPage = 1
                self.hasMorePages = response.count == pageSize
            }
            
        } catch {
            #if DEBUG
            print("Failed to refresh listings: \(error)")
            #endif
        }
    }
}

struct ListingCard: View {
    let listing: ListingWithUser
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Photo
            if let photoURL = listing.photo, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(listing.title)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    Text("$\(listing.price, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("ThemeColor"))
                }
                
                Text(listing.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Text(listing.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color("ThemeColor").opacity(0.2))
                        .foregroundColor(Color("ThemeColor"))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Text("by \(listing.user.name ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct HomeTabView_Previews: PreviewProvider {
    static var previews: some View {
        HomeTabView()
            .environmentObject(AuthManager())
    }
} 