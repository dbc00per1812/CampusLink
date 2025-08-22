import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var listings: [ListingWithUser] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var currentPage = 0
    
    private let pageSize = 10

    var body: some View {
        NavigationView {
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
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await loadListings()
                }
            }
        }
    }
    
    private func loadListings() async {
        guard let userEmail = authManager.session?.user.email,
              let domain = userEmail.components(separatedBy: "@").last else { return }
        
        await MainActor.run {
            isLoading = true
            currentPage = 0
            hasMorePages = true
        }
        
        do {
            let from = 0
            let to = pageSize - 1
            
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
                .like("user.email", pattern: "%@\(domain)")
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
            print("Failed to load listings: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadMoreListings() async {
        guard !isLoadingMore, hasMorePages else { return }
        guard let userEmail = authManager.session?.user.email,
              let domain = userEmail.components(separatedBy: "@").last else { return }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        do {
            let from = currentPage * pageSize
            let to = from + pageSize - 1
            
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
                .like("user.email", pattern: "%@\(domain)")
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
            print("Failed to load more listings: \(error)")
            await MainActor.run {
                self.isLoadingMore = false
            }
        }
    }
    
    private func refreshListings() async {
        guard let userEmail = authManager.session?.user.email,
              let domain = userEmail.components(separatedBy: "@").last else { return }
        
        await MainActor.run {
            currentPage = 0
            hasMorePages = true
        }
        
        do {
            let from = 0
            let to = pageSize - 1
            
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
                .like("user.email", pattern: "%@\(domain)")
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
            print("Failed to refresh listings: \(error)")
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