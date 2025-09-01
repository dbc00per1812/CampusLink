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

    private let pageSize = 10
    private let enableDomainFilter = false  // Disabled for v1.0 release

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView()
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

            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("""
                    *,
                    user:users(*)
                """)
                .eq("status", value: "active")
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

                Text(listing.description)
                    .font(.body).foregroundColor(.secondary).lineLimit(3)

                HStack {
                    Text(listing.category)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color("ThemeColor").opacity(0.2))
                        .foregroundColor(Color("ThemeColor"))
                        .cornerRadius(6)
                    Spacer()
                    Text("by \(listing.user.name ?? "Unknown")")
                        .font(.caption).foregroundColor(.secondary)
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
