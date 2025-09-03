import SwiftUI

// Simple struct just for fetching email
private struct UserEmailFetch: Codable { let email: String? }

struct HomeTabView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var listings: [ListingWithUser] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var currentPage = 0
    
    // Seek mode filter (Phase 2)
    @State private var selectedFilter: ListingFilter = .all

    private let pageSize = 10
    private let enableDomainFilter = false  // Disabled for v1.0 release
    
    enum ListingFilter: String, CaseIterable {
        case all = "All"
        case forSale = "For Sale"
        case wanted = "Wanted"
        
        var intentFilter: ListingIntent? {
            switch self {
            case .all: return nil
            case .forSale: return .offer
            case .wanted: return .seek
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView()
                if AppConfig.enableSeekMode {
                    filterView()
                }
                contentView()
            }
            // keep this screen interactable even if a parent mistakenly disabled it
            .disabled(false)
            .allowsHitTesting(true)
            .onAppear {
                PaymentService.shared.paymentResult = nil
                PaymentService.shared.paymentSheet  = nil
                Task { await loadListings() }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Sections

extension HomeTabView {
    @ViewBuilder
    private func filterView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ListingFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        Task { await refreshListings() }
                    }) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .foregroundColor(selectedFilter == filter ? .white : Color("ThemeColor"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedFilter == filter ? Color("ThemeColor") : Color("ThemeColor").opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func headerView() -> some View {
        let userEmail = authManager.session?.user.email
        let greeting = (userEmail?.split(separator: "@").first.map(String.init)) ?? userEmail ?? "there"

        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Hello, \(greeting)!")
                        .font(.title2)
                        .fontWeight(.semibold)
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
        .padding(.top, 4)
    }

    @ViewBuilder
    private func contentView() -> some View {
        if isLoading {
            loadingView()
        } else if listings.isEmpty {
            emptyStateView()
        } else {
            listView()
        }
    }

    @ViewBuilder
    private func loadingView() -> some View {
        Spacer()
        ProgressView("Loading listings...")
        Spacer()
    }

    @ViewBuilder
    private func emptyStateView() -> some View {
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
        .padding(.horizontal)
        Spacer()
    }

    @ViewBuilder
    private func listView() -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(listings) { listing in
                    NavigationLink(destination: ListingDetailView(listing: listing)) {
                        ListingCard(listing: listing)
                    }
                    .buttonStyle(.plain)
                    .id(listing.id) // Ensure stable identity
                    .onAppear {
                        if listing.id == listings.suffix(3).first?.id {
                            Task { await loadMoreListings() }
                        }
                    }
                    .onTapGesture {
                        // Prevent navigation if data is being modified
                        guard !isLoading && !isLoadingMore else { return }
                    }
                }

                if isLoadingMore {
                    HStack { Spacer(); ProgressView().padding(); Spacer() }
                }

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
        .refreshable { await refreshListings() }
    }
}

// MARK: - Data

extension HomeTabView {
    private func loadListings() async {
        await MainActor.run {
            isLoading = true
            currentPage = 0
            hasMorePages = true
        }

        do {
            let from = 0
            let to = pageSize - 1

            var query = supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
                .eq("status", value: "active")
                
            // Apply intent filter (Phase 2)
            if AppConfig.enableSeekMode, let intent = selectedFilter.intentFilter {
                query = query.eq("intent", value: intent.rawValue)
            }

            if enableDomainFilter {
                var userEmail: String? = authManager.session?.user.email
                if userEmail == nil, let userId = authManager.session?.user.id.uuidString {
                    do {
                        let userResponse: [UserEmailFetch] = try await supabase
                            .from("users")
                            .select("email")
                            .eq("id", value: userId)
                            .execute()
                            .value
                        userEmail = userResponse.first?.email
                    } catch { /* ignore filter on failure */ }
                }
                if let email = userEmail, let domain = email.split(separator: "@").last {
                    query = query.ilike("user.email", pattern: "%@\(domain)")
                }
            }

            let response: [ListingWithUser] = try await query
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value

            // Ensure we're on the main thread and the response is valid
            await MainActor.run {
                guard !response.isEmpty else {
                    listings = []
                    isLoading = false
                    currentPage = 1
                    hasMorePages = false
                    return
                }
                
                // Validate that each listing has a unique ID
                let uniqueListings = Array(Set(response.map { $0.id })).compactMap { id in
                    response.first { $0.id == id }
                }
                
                listings = uniqueListings
                isLoading = false
                currentPage = 1
                hasMorePages = response.count == pageSize
            }
        } catch {
            #if DEBUG
            print("Failed to load listings: \(error)")
            #endif
            await MainActor.run { isLoading = false }
        }
    }

    private func loadMoreListings() async {
        guard !isLoadingMore, hasMorePages else { return }
        await MainActor.run { isLoadingMore = true }

        do {
            let from = currentPage * pageSize
            let to = from + pageSize - 1

            var query = supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
                .eq("status", value: "active")
                
            // Apply intent filter (Phase 2)
            if AppConfig.enableSeekMode, let intent = selectedFilter.intentFilter {
                query = query.eq("intent", value: intent.rawValue)
            }
            
            let response: [ListingWithUser] = try await query
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value

            await MainActor.run {
                // Ensure no duplicate listings are added
                let existingIds = Set(listings.map { $0.id })
                let newListings = response.filter { !existingIds.contains($0.id) }
                
                listings.append(contentsOf: newListings)
                currentPage += 1
                hasMorePages = response.count == pageSize
                isLoadingMore = false
            }
        } catch {
            #if DEBUG
            print("Failed to load more listings: \(error)")
            #endif
            await MainActor.run { isLoadingMore = false }
        }
    }

    private func refreshListings() async {
        await MainActor.run {
            currentPage = 0
            hasMorePages = true
        }

        do {
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .range(from: 0, to: pageSize - 1)
                .execute()
                .value

            await MainActor.run {
                listings = response
                currentPage = 1
                hasMorePages = response.count == pageSize
            }
        } catch {
            #if DEBUG
            print("Failed to refresh listings: \(error)")
            #endif
        }
    }
}

// MARK: - Listing Card (unchanged)

struct ListingCard: View {
    let listing: ListingWithUser

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let photoURL = listing.photo, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(UIColor.systemGray5)).overlay(ProgressView())
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(12)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(listing.title).font(.headline).lineLimit(2)
                    Spacer()
                    if AppConfig.enableSeekMode && listing.intent == .seek {
                        // Show budget for seek posts
                        VStack(alignment: .trailing, spacing: 2) {
                            if let min = listing.budgetMin, let max = listing.budgetMax {
                                Text("$\(min, specifier: "%.0f")-$\(max, specifier: "%.0f")")
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundColor(Color("ThemeColor"))
                            } else if let max = listing.budgetMax {
                                Text("Up to $\(max, specifier: "%.0f")")
                                    .font(.title3).fontWeight(.bold)
                                    .foregroundColor(Color("ThemeColor"))
                            }
                            Text("Budget")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Show price for offer posts
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(listing.price, specifier: "%.2f")")
                                .font(.title3).fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                            let totalWithFee = listing.price * 1.029 + 0.30 // Include 2.9% + $0.30
                            Text("$\(totalWithFee, specifier: "%.2f") total")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Text(listing.description)
                    .font(.body).foregroundColor(.secondary).lineLimit(3)

                HStack {
                    HStack(spacing: 6) {
                        if AppConfig.enableSeekMode && listing.intent == .seek {
                            Text("Wanted")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        
                        Text(listing.category)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color("ThemeColor").opacity(0.2))
                            .foregroundColor(Color("ThemeColor"))
                            .cornerRadius(6)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("by \(listing.user.name ?? "Unknown")")
                            .font(.caption).foregroundColor(.secondary)
                        
                        if AppConfig.enableSeekMode && listing.intent == .seek,
                           let expiresAt = listing.expiresAt {
                            Text("• Expires \(expiresAt, style: .relative)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
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
