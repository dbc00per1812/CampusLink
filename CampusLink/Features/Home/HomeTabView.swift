import SwiftUI
import Supabase

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
    // Ratings trust filter (Phase 3)
    
    // Search functionality (Phase 1)
    @State private var searchQuery = SearchQuery()
    @State private var isSearchActive = false
    @State private var showingSearchResults = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    
    // Debug states for visual debugging
    
    private let pageSize = 10
    private let enableDomainFilter = false  // Disabled for v1.0 release
    
    enum ListingFilter: String, CaseIterable {
        case all = "All"
        case forSale = "Selling"
        case wanted = "Buying"
        
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
                Task { await loadAllListings() }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSearchResults) {
            if AppConfig.enableSearch {
                NavigationView {
                    SearchResultsView(searchQuery: searchQuery)
                    .navigationTitle("Search Results")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSearchResults = false
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sections

extension HomeTabView {
    @ViewBuilder
    private func filterView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ResponsiveHStack(spacing: 12) {
                ForEach(ListingFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        Task {
                            switch filter {
                            case .all:
                                await loadAllListings()
                            case .forSale:
                                await loadOfferListings()
                            case .wanted:
                                await loadSeekListings()
                            }
                        }
                    }) {
                        Text(filter.rawValue)
                            .responsiveFont(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .foregroundColor(selectedFilter == filter ? .white : Color("ThemeColor"))
                            .responsiveHorizontalSpacing(16)
                            .responsiveSpacing(8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedFilter == filter ? Color("ThemeColor") : Color("ThemeColor").opacity(0.1))
                            )
                    }
                    .accessibleButton("Filter by \(filter.rawValue)")
                }
                
            }
            .responsiveHorizontalSpacing(16)
        }
        .responsiveSpacing(8)
    }
    
    @ViewBuilder
    private func headerView() -> some View {
        ResponsiveVStack(spacing: 12) {
            HStack {
                Image(systemName: "graduationcap.circle.fill")
                    .responsiveFontSize(40)
                    .foregroundColor(Color("ThemeColor"))
                Spacer()
            }
            
            // Search bar (Phase 1)
            if AppConfig.enableSearch {
                SearchBarWithFiltersView(
                    searchQuery: $searchQuery,
                    onSearchChanged: { query in
                        handleSearchChanged(query)
                    },
                    onSearchSubmitted: { query in
                        performSearch(query)
                    }
                )
            }
        }
        .responsivePadding(16)
        .background(Color(UIColor.systemGray6))
        .responsiveCornerRadius(12)
        .responsiveHorizontalSpacing(16)
        .responsiveSpacing(4)
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
            Image(systemName: selectedFilter == .wanted ? "magnifyingglass" : "list.bullet.below.rectangle")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(selectedFilter == .all ? "No listings yet" : 
                 selectedFilter == .forSale ? "No items for sale yet" : 
                 "No wanted posts yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(selectedFilter == .all ? "Be the first to post something!" :
                 selectedFilter == .forSale ? "Be the first to post something for sale!" :
                 "Be the first to post what you're looking for!")
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
            ResponsiveVStack(spacing: 16) {
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
                    HStack { Spacer(); ProgressView().responsivePadding(16); Spacer() }
                }

                if !hasMorePages && !listings.isEmpty {
                    HStack {
                        Spacer()
                        Text("You've reached the end")
                            .responsiveFont(.caption)
                            .foregroundColor(.secondary)
                            .responsivePadding(16)
                        Spacer()
                    }
                }
            }
            .responsivePadding(16)
        }
        .refreshable { await refreshListings() }
    }
}

// MARK: - Data (Unified filters + pagination)

extension HomeTabView {

    // Trust filter threshold (60/80) from UI

    // Client-side trust filter with caching & concurrency
    private func applyTrustFilter(_ input: [ListingWithUser]) async -> [ListingWithUser] {
        // Trust filtering removed - ratings kept private to profiles
        return input
    }

    // If we filter client-side for trust, fetch extra rows so we can still fill a page visually.
    private var overscanMultiplier: Int { 1 }


    private func loadListings() async {
        // Load listings based on current filter
        switch selectedFilter {
        case .all:
            await loadAllListings()
        case .forSale:
            await loadOfferListings()
        case .wanted:
            await loadSeekListings()
        }
    }

    private func loadMoreListings() async {
        // Load more using current filter (though we limit to 20 for now)
        await refreshListings()
        await MainActor.run { 
            isLoadingMore = false
            hasMorePages = false
        }
    }

    private func loadAllListings() async {
        do {
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            print("🔍 Loaded \(result.count) listings")
            
            await MainActor.run {
                listings = result
                isLoading = false
            }
        } catch {
            print("❌ Error loading listings: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadOfferListings() async {
        do {
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "offer")
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            await MainActor.run {
                listings = result
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadSeekListings() async {
        do {
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "seek")
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            print("🔍 SEEK FILTER: Found \(result.count) seeking posts")
            for listing in result.prefix(3) {
                print("   - \(listing.title) (intent: \(listing.intent.rawValue), archived: \(listing.archived ?? false))")
            }
            
            await MainActor.run {
                listings = result
                isLoading = false
            }
        } catch {
            print("❌ Error loading seek listings: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }


    private func refreshListings() async {
        // Refresh using current filter
        switch selectedFilter {
        case .all:
            await loadAllListings()
        case .forSale:
            await loadOfferListings()
        case .wanted:
            await loadSeekListings()
        }
    }
}

// MARK: - Listing Card (unchanged except optional trust loading usage)

struct ListingCard: View {
    let listing: ListingWithUser
    @State private var currentImageIndex: Int = 0

    var body: some View {
        ResponsiveVStack(spacing: 12, alignment: .leading) {
            // Single centered square with paging between photos
            listingImagesCarousel()

            ResponsiveVStack(spacing: 8, alignment: .leading) {
                HStack {
                    Text(listing.title)
                        .responsiveFont(.headline)
                        .lineLimit(2)
                    Spacer()
                    if AppConfig.enableSeekMode && listing.intent == .seek {
                        // Show budget for seek posts
                        VStack(alignment: .trailing, spacing: 2) {
                            if let min = listing.budgetMin, let max = listing.budgetMax {
                                Text("$\(min, specifier: "%.0f")-$\(max, specifier: "%.0f")")
                                    .responsiveFont(.title3, weight: .bold)
                                    .foregroundColor(Color("ThemeColor"))
                            } else if let max = listing.budgetMax {
                                Text("Up to $\(max, specifier: "%.0f")")
                                    .responsiveFont(.title3, weight: .bold)
                                    .foregroundColor(Color("ThemeColor"))
                            }
                            Text("Budget")
                                .responsiveFont(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Show price for offer posts
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\((listing.price ?? 0), specifier: "%.2f")")
                                .responsiveFont(.title3, weight: .bold)
                                .foregroundColor(Color("ThemeColor"))
                            Text("$\(((listing.price ?? 0) * 1.029 + 0.30), specifier: "%.2f") total")
                                .responsiveFont(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }


                Text(listing.description)
                    .responsiveFont(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                HStack {
                    ResponsiveHStack(spacing: 6) {
                        if AppConfig.enableSeekMode && listing.intent == .seek {
                            Text("Buying")
                                .responsiveFont(.caption, weight: .medium)
                                .responsiveHorizontalSpacing(8)
                                .responsiveSpacing(4)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .responsiveCornerRadius(6)
                        } else if AppConfig.enableSeekMode && listing.intent == .offer {
                            Text("Selling")
                                .responsiveFont(.caption, weight: .medium)
                                .responsiveHorizontalSpacing(8)
                                .responsiveSpacing(4)
                                .background(Color("ThemeColor"))
                                .foregroundColor(.white)
                                .responsiveCornerRadius(6)
                        }
                        
                        Text(listing.category)
                            .responsiveFont(.caption)
                            .responsiveHorizontalSpacing(8)
                            .responsiveSpacing(4)
                            .background(Color("ThemeColor").opacity(0.2))
                            .foregroundColor(Color("ThemeColor"))
                            .responsiveCornerRadius(6)
                    }
                    
                    Spacer()
                    
                    ResponsiveHStack(spacing: 4) {
                        Text("by \(listing.user.name ?? "Unknown")")
                            .responsiveFont(.caption)
                            .foregroundColor(.secondary)
                        
                        if AppConfig.enableSeekMode && listing.intent == .seek,
                           let expiresAt = listing.expiresAt {
                            Text("• Expires \(expiresAt, style: .relative)")
                                .responsiveFont(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .responsiveHorizontalSpacing(12)
            .responsiveSpacing(12)
        }
        .background(Color(UIColor.systemBackground))
        .responsiveCornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func listingImagesCarousel() -> some View {
        let urls: [String] = !listing.photos.isEmpty ? listing.photos : (listing.photo != nil ? [listing.photo!] : [])
        if urls.isEmpty {
            Rectangle()
                .fill(Color(UIColor.systemGray6))
                .overlay(ProgressView())
                .responsiveFrame(height: 200)
                .responsiveCornerRadius(12)
        } else if urls.count == 1 {
            // Single image - no TabView to avoid scroll conflicts
            if let url = URL(string: urls[0]) {
                ResponsiveAsyncImage(
                    url: url,
                    maxWidth: .infinity,
                    maxHeight: 250,
                    aspectRatio: nil,
                    contentMode: .fit,
                    cornerRadius: 12
                )
                .clipped()
            }
        } else {
            // Multiple images - use ScrollView instead of TabView to prevent scroll conflicts
            VStack(spacing: 8) {
                // Main image
                if currentImageIndex < urls.count,
                   let url = URL(string: urls[currentImageIndex]) {
                    ResponsiveAsyncImage(
                        url: url,
                        maxWidth: .infinity,
                        maxHeight: 250,
                        aspectRatio: nil,
                        contentMode: .fit,
                        cornerRadius: 12
                    )
                    .clipped()
                    .overlay(
                        // Image counter
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(currentImageIndex + 1) / \(urls.count)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(12)
                                    .padding(.trailing, 8)
                                    .padding(.bottom, 8)
                            }
                        }
                    )
                }
                
                // Thumbnail navigation
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(urls.enumerated()), id: \.offset) { index, photoURL in
                            if let url = URL(string: photoURL) {
                                Button(action: {
                                    currentImageIndex = index
                                }) {
                                    ResponsiveAsyncImage(
                                        url: url,
                                        width: 60,
                                        height: 60,
                                        aspectRatio: 1,
                                        contentMode: .fill,
                                        cornerRadius: 6
                                    )
                                    .clipped()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color("ThemeColor"), lineWidth: index == currentImageIndex ? 2 : 0.5)
                                            .opacity(index == currentImageIndex ? 1 : 0.3)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 68)
            }
        }
    }

}

// MARK: - Search Methods Extension

extension HomeTabView {
    private func handleSearchChanged(_ query: SearchQuery) {
        guard AppConfig.enableSearch else { return }
        
        searchQuery = query
        
        // Cancel previous search work item
        searchWorkItem?.cancel()
        
        // Create new search work item with debouncing
        let currentQuery = query
        let workItem = DispatchWorkItem {
            Task { @MainActor in
                // Only trigger search if query is active (has text or filters)
                if currentQuery.isActive {
                    performSearch(currentQuery)
                }
            }
        }
        
        searchWorkItem = workItem
        
        // Execute after 500ms delay for debouncing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    private func performSearch(_ query: SearchQuery) {
        guard AppConfig.enableSearch && query.isActive else { return }
        
        searchQuery = query
        showingSearchResults = true
        
        // Save search query for analytics (Phase 3)
        Task {
            await SearchService.shared.saveRecentSearch(query, resultCount: 0)
        }
    }
    
    // TEMPORARY DEBUG METHOD (kept for your troubleshooting; optional)
    private func testFilters() async {
        print("🧪 TESTING FILTERS EXPLICITLY:")
        
        // Test 1: All listings (no filter)
        do {
            let allListings: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .order("created_at", ascending: false)
                .limit(10)
                .execute()
                .value
            print("🧪 ALL LISTINGS: \(allListings.count)")
            for listing in allListings {
                print("🧪   - \"\(listing.title)\": intent=\(listing.intent.rawValue), price=\(listing.price)")
            }
            
            let intents = allListings.map { $0.intent.rawValue }
            let uniqueIntents = Set(intents)
            await MainActor.run {
            }
            
        } catch {
            await MainActor.run {
            }
            print("🧪 ERROR in test: \(error)")
        }
        
        // Test 2: Seek listings only  
        do {
            let seekListings: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "seek")
                .order("created_at", ascending: false)
                .execute()
                .value
            print("🧪 SEEK LISTINGS: \(seekListings.count)")
            for listing in seekListings {
                print("🧪   - SEEK: \"\(listing.title)\": intent=\(listing.intent.rawValue)")
            }
        } catch {
            print("🧪 ERROR loading seek listings: \(error)")
        }
        
        // Test 3: Offer listings only
        do {
            let offerListings: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "offer")
                .order("created_at", ascending: false)
                .execute()
                .value
            print("🧪 OFFER LISTINGS: \(offerListings.count)")
            for listing in offerListings {
                print("🧪   - OFFER: \"\(listing.title)\": intent=\(listing.intent.rawValue)")
            }
        } catch {
            print("🧪 ERROR loading offer listings: \(error)")
        }
        
        await MainActor.run {
        }
    }
}
