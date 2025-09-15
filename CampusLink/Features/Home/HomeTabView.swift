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
    @State private var selectedTrustFilter: TrustFilter = .all
    
    // Search functionality (Phase 1)
    @State private var searchQuery = SearchQuery()
    @State private var isSearchActive = false
    @State private var showingSearchResults = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    // Navigation states
    @State private var selectedListing: ListingWithUser?
    @State private var showingListingDetail = false
    
    // Debug states for visual debugging
    @State private var ratingCache: [String: UserRatingsSummary] = [:]
    
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

    enum TrustFilter: String, CaseIterable {
        case all = "All Trust"
        case reliable = "60+"
        case trusted = "80+"
        
        var minScore: Int? {
            switch self {
            case .all: return nil
            case .reliable: return 60
            case .trusted: return 80
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView()
                if AppConfig.enableSeekMode {
                    simpleFilterView()
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
        .navigationDestination(isPresented: $showingListingDetail) {
            if let listing = selectedListing {
                ListingDetailView(listing: listing)
            }
        }
        .sheet(isPresented: $showingSearchResults) {
            if AppConfig.enableSearch {
                NavigationView {
                    SearchResultsView(
                        searchQuery: searchQuery,
                        onListingTapped: { listing in
                            showingSearchResults = false
                            // Navigate to listing detail after dismissing sheet
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                selectedListing = listing
                                showingListingDetail = true
                            }
                        }
                    )
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
    private func simpleFilterView() -> some View {
        HStack(spacing: 12) {
            Button("All") {
                Task { await loadAllListings() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("ThemeColor"))
            .foregroundColor(.white)
            .cornerRadius(20)
            
            Button("Selling") {
                Task { await loadOfferListings() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("ThemeColor"))
            .foregroundColor(.white)
            .cornerRadius(20)
            
            Button("Buying") {
                Task { await loadSeekListings() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("ThemeColor"))
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func filterView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ListingFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        print("🔍 BUTTON TAPPED: \(filter.rawValue)")
                        selectedFilter = filter
                        print("🔍 selectedFilter set to: \(selectedFilter.rawValue)")
                        Task { 
                            await nuclearTest(filter: filter)
                        }
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
                
                if AppConfig.enableRatings {
                    Divider().frame(height: 24)
                    ForEach(TrustFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedTrustFilter = filter
                            Task { await refreshListings() }
                        }) {
                            Text(filter.rawValue)
                                .font(.caption)
                                .fontWeight(selectedTrustFilter == filter ? .semibold : .regular)
                                .foregroundColor(selectedTrustFilter == filter ? .white : Color("ThemeColor"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedTrustFilter == filter ? Color("ThemeColor") : Color("ThemeColor").opacity(0.1))
                                )
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func headerView() -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "graduationcap.circle.fill")
                    .font(.system(size: 40))
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

// MARK: - Data (Unified filters + pagination)

extension HomeTabView {

    // Trust filter threshold (60/80) from UI
    private func minTrustScore() -> Int? { selectedTrustFilter.minScore }

    // Client-side trust filter with caching & concurrency
    private func applyTrustFilter(_ input: [ListingWithUser]) async -> [ListingWithUser] {
        guard AppConfig.enableRatings, let minScore = minTrustScore() else { return input }
        if minScore <= 0 { return input }

        // We’ll treat averageRating (0–5 stars) as 0–100 by *20
        func passes(_ summary: UserRatingsSummary) -> Bool {
            let score = Int(summary.averageRating * 20.0)
            return score >= minScore
        }

        var kept: [(ListingWithUser, Bool)] = []
        kept.reserveCapacity(input.count)

        await withTaskGroup(of: (ListingWithUser, Bool).self) { group in
            for listing in input {
                group.addTask {
                    if let cached = ratingCache[listing.user.id] {
                        return (listing, passes(cached))
                    }
                    do {
                        let summary = try await RatingService.shared.getUserRatingsSummary(userId: listing.user.id)
                        await MainActor.run { ratingCache[listing.user.id] = summary }
                        return (listing, passes(summary))
                    } catch {
                        // On error retrieving rating, exclude (or flip to include if desired)
                        return (listing, false)
                    }
                }
            }
            for await pair in group { kept.append(pair) }
        }

        return kept.compactMap { $0.1 ? $0.0 : nil }
    }

    // If we filter client-side for trust, fetch extra rows so we can still fill a page visually.
    private var overscanMultiplier: Int { minTrustScore() == nil ? 1 : 3 }

    private func fetchPage(page: Int, size: Int) async throws -> [ListingWithUser] {
        let from = page * size
        let to = from + (size * overscanMultiplier) - 1

        let response: [ListingWithUser]
        
        switch selectedFilter {
        case .all:
            print("🔍 EXECUTING: .all (no intent filter)")
            response = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
                
        case .forSale:
            print("🔍 EXECUTING: .forSale (intent = offer)")
            response = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "offer")
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
                
        case .wanted:
            print("🔍 EXECUTING: .wanted (intent = seek)")
            response = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "seek")
                .order("created_at", ascending: false)
                .range(from: from, to: to)
                .execute()
                .value
        }

        print("🔍 QUERY RETURNED: \(response.count) listings")
        for (i, listing) in response.enumerated() {
            print("🔍   \(i): \(listing.title) - intent: \(listing.intent.rawValue)")
        }

        let filtered = await applyTrustFilter(response)
        return Array(filtered.prefix(size))
    }

    private func loadListings() async {
        await MainActor.run {
            isLoading = true
            isLoadingMore = false
            hasMorePages = true
            currentPage = 0
        }

        do {
            let first = try await fetchPage(page: 0, size: pageSize)

            await MainActor.run {
                listings = first
                isLoading = false
                currentPage = 1
                hasMorePages = first.count == pageSize
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
            let next = try await fetchPage(page: currentPage, size: pageSize)

            await MainActor.run {
                let existing = Set(listings.map { $0.id })
                let newOnes = next.filter { !existing.contains($0.id) }
                listings.append(contentsOf: newOnes)
                currentPage += 1
                hasMorePages = next.count == pageSize
                isLoadingMore = false
            }
        } catch {
            #if DEBUG
            print("Failed to load more listings: \(error)")
            #endif
            await MainActor.run { isLoadingMore = false }
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

    private func isolatedOfferTest() async {
        print("🔴 ISOLATED OFFER TEST STARTING")
        do {
            let offerListings: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("intent", value: "offer")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("🔴 OFFER RESULTS: \(offerListings.count) listings")
            for listing in offerListings {
                print("🔴   - \(listing.title) (intent: \(listing.intent.rawValue))")
            }
            
            await MainActor.run {
                listings = offerListings
            }
        } catch {
            print("🔴 OFFER ERROR: \(error)")
        }
    }
    
    private func isolatedSeekTest() async {
        print("🔵 ISOLATED SEEK TEST STARTING")
        do {
            let seekListings: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("intent", value: "seek")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("🔵 SEEK RESULTS: \(seekListings.count) listings")
            for listing in seekListings {
                print("🔵   - \(listing.title) (intent: \(listing.intent.rawValue))")
            }
            
            await MainActor.run {
                listings = seekListings
            }
        } catch {
            print("🔵 SEEK ERROR: \(error)")
        }
    }

    private func nuclearTest(filter: ListingFilter) async {
        print("🚨 NUCLEAR TEST: \(filter.rawValue)")
        
        do {
            let result: [ListingWithUser]
            
            switch filter {
            case .all:
                print("🚨 TESTING: ALL")
                result = try await supabase
                    .from("listings")
                    .select("*, user:users(*)")
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .order("created_at", ascending: false)
                    .limit(10)
                    .execute()
                    .value
                    
            case .forSale:
                print("🚨 TESTING: SELLING (offer)")
                result = try await supabase
                    .from("listings")
                    .select("*, user:users(*)")
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("intent", value: "offer")
                    .order("created_at", ascending: false)
                    .limit(10)
                    .execute()
                    .value
                    
            case .wanted:
                print("🚨 TESTING: BUYING (seek)")
                result = try await supabase
                    .from("listings")
                    .select("*, user:users(*)")
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("intent", value: "seek")
                    .order("created_at", ascending: false)
                    .limit(10)
                    .execute()
                    .value
            }
            
            print("🚨 RESULT: \(result.count) listings")
            for listing in result {
                print("🚨   - \(listing.title): \(listing.intent.rawValue)")
            }
            
            await MainActor.run {
                listings = result
                isLoading = false
            }
            
        } catch {
            print("🚨 ERROR: \(error)")
        }
    }

    private func refreshListings() async {
        print("🔍 refreshListings() called with selectedFilter: \(selectedFilter.rawValue)")
        await MainActor.run {
            currentPage = 0
            hasMorePages = true
            isLoading = true
            isLoadingMore = false
            ratingCache.removeAll()
        }

        do {
            print("🔍 Calling fetchPage with selectedFilter: \(selectedFilter.rawValue)")
            let first = try await fetchPage(page: 0, size: pageSize)

            await MainActor.run {
                listings = first
                currentPage = 1
                hasMorePages = first.count == pageSize
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}

// MARK: - Listing Card (unchanged except optional trust loading usage)

struct ListingCard: View {
    let listing: ListingWithUser
    @State private var ratingSummary: UserRatingsSummary?
    @State private var isLoadingRating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let photoURL = listing.photo, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                        .overlay(ProgressView())
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
                            Text("$\(listing.price * 1.029 + 0.30, specifier: "%.2f") total")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Ratings row (Phase 2)
                if AppConfig.enableRatings {
                    HStack(spacing: 8) {
                        if let summary = ratingSummary {
                            StarRatingView(rating: summary.averageRating, size: 12)
                            Text(summary.displayRating)
                                .font(.caption)
                            Text("(\(summary.totalRatings))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            TrustBadgeView(trustLevel: summary.trustLevel, showText: false)
                        } else if isLoadingRating {
                            ProgressView().scaleEffect(0.6)
                        }
                    }
                }

                Text(listing.description)
                    .font(.body).foregroundColor(.secondary).lineLimit(3)

                HStack {
                    HStack(spacing: 6) {
                        if AppConfig.enableSeekMode && listing.intent == .seek {
                            Text("Buying")
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
        .task {
            if AppConfig.enableRatings {
                await loadRatingSummary()
            }
        }
    }

    private func loadRatingSummary() async {
        guard AppConfig.enableRatings else { return }
        await MainActor.run { isLoadingRating = true }
        do {
            let summary = try await RatingService.shared.getUserRatingsSummary(userId: listing.user.id)
            await MainActor.run { self.ratingSummary = summary; self.isLoadingRating = false }
        } catch {
            await MainActor.run { self.isLoadingRating = false }
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
