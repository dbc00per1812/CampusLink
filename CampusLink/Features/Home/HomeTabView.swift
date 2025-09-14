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
    @State private var debugMessage = ""
    @State private var lastFilterTapped = ""
    @State private var queryResultCount = 0
    @State private var databaseIntents: Set<String> = []

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
                    filterView()
                    
                    // NUCLEAR DEBUG PANEL
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🚨 NUCLEAR DEBUG:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Text("🔥 SELECTED: \(selectedFilter.rawValue) (intent: \(selectedFilter.intentFilter?.rawValue ?? "NONE"))")
                        Text("🔥 ENABLE_SEEK: \(AppConfig.enableSeekMode)")
                        Text("🔥 LISTINGS.COUNT: \(listings.count)")
                        Text("🔥 QUERY_RESULTS: \(queryResultCount)")
                        Text("🔥 DB_INTENTS: \(Array(databaseIntents).joined(separator: ", "))")
                        Text("🔥 LAST_TAPPED: \(lastFilterTapped.isEmpty ? "NONE" : lastFilterTapped)")
                        if !debugMessage.isEmpty {
                            Text("🔥 STATUS: \(debugMessage)")
                                .foregroundColor(.red)
                        }
                        
                        // Show first few actual listings
                        Text("🔥 ACTUAL_LISTINGS:")
                        if listings.isEmpty {
                            Text("  ❌ EMPTY ARRAY!")
                                .foregroundColor(.red)
                        } else {
                            ForEach(listings.prefix(3), id: \.id) { listing in
                                Text("  • \(listing.title) (\(listing.intent.rawValue))")
                                    .font(.caption2)
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                } else {
                    Text("❌ FILTERS HIDDEN - enableSeekMode = false")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                contentView()
                    .id("\(selectedFilter.rawValue)-\(listings.count)") // Force refresh when filter or count changes
            }
            // keep this screen interactable even if a parent mistakenly disabled it
            .disabled(false)
            .allowsHitTesting(true)
            .onAppear {
                PaymentService.shared.paymentResult = nil
                PaymentService.shared.paymentSheet  = nil
                debugMessage = "App started - enableSeekMode: \(AppConfig.enableSeekMode)"
                Task { await loadListings() }
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
    private func filterView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ListingFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        print("🚨🚨🚨 BUTTON TAPPED: \(filter.rawValue)")
                        print("🚨 BEFORE - selectedFilter: \(selectedFilter.rawValue)")
                        print("🚨 BEFORE - listings.count: \(listings.count)")
                        
                        lastFilterTapped = filter.rawValue
                        debugMessage = "🚨 BUTTON TAPPED: \(filter.rawValue)"
                        selectedFilter = filter
                        
                        print("🚨 AFTER - selectedFilter: \(selectedFilter.rawValue)")
                        print("🚨 INTENT FILTER: \(filter.intentFilter?.rawValue ?? "NONE")")
                        
                        Task { 
                            debugMessage = "🚨 STARTING REFRESH FOR: \(filter.rawValue)..."
                            await refreshListings() 
                            debugMessage = "🚨 FINISHED REFRESH FOR: \(filter.rawValue)"
                            print("🚨 FINAL - listings.count: \(listings.count)")
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

            // SIMPLE APPROACH - Build complete query based on filter
            let response: [ListingWithUser]
            
            if AppConfig.enableSeekMode, let intent = selectedFilter.intentFilter {
                print("📋 loadListings: APPLYING INTENT FILTER: \(intent.rawValue)")
                
                response = try await supabase
                    .from("listings")
                    .select("""
                        *,
                        user:users(*)
                    """)
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("intent", value: intent.rawValue)
                    .order("created_at", ascending: false)
                    .range(from: from, to: to)
                    .execute()
                    .value
            } else {
                print("📋 loadListings: NO INTENT FILTER")
                
                response = try await supabase
                    .from("listings")
                    .select("""
                        *,
                        user:users(*)
                    """)
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .order("created_at", ascending: false)
                    .range(from: from, to: to)
                    .execute()
                    .value
            }

            #if DEBUG
            print("📋 HomeTabView: loadListings() - Selected filter: \(selectedFilter.rawValue)")
            print("📋 HomeTabView: loadListings() - Intent filter: \(selectedFilter.intentFilter?.rawValue ?? "none")")
            print("📋 HomeTabView: loadListings() - Response count: \(response.count)")
            for (index, listing) in response.enumerated() {
                print("📋 HomeTabView: loadListings() - Listing \(index): \"\(listing.title)\", intent: \(listing.intent.rawValue), price: \(listing.price)")
            }
            #endif
            
            // Update debug UI
            await MainActor.run {
                let intents = response.map { $0.intent.rawValue }
                let uniqueIntents = Set(intents)
                databaseIntents = uniqueIntents
                queryResultCount = response.count
            }

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

            // SIMPLE APPROACH - Build complete query based on filter
            let response: [ListingWithUser]
            
            if AppConfig.enableSeekMode, let intent = selectedFilter.intentFilter {
                print("📋 loadMoreListings: APPLYING INTENT FILTER: \(intent.rawValue)")
                
                response = try await supabase
                    .from("listings")
                    .select("""
                        *,
                        user:users(*)
                    """)
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("intent", value: intent.rawValue)
                    .order("created_at", ascending: false)
                    .range(from: from, to: to)
                    .execute()
                    .value
            } else {
                print("📋 loadMoreListings: NO INTENT FILTER")
                
                response = try await supabase
                    .from("listings")
                    .select("""
                        *,
                        user:users(*)
                    """)
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .order("created_at", ascending: false)
                    .range(from: from, to: to)
                    .execute()
                    .value
            }

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
        print("🚨🚨🚨 refreshListings() CALLED")
        print("🚨 Current selectedFilter: \(selectedFilter.rawValue)")
        print("🚨 Current selectedFilter.intentFilter: \(selectedFilter.intentFilter?.rawValue ?? "NONE")")
        print("🚨 AppConfig.enableSeekMode: \(AppConfig.enableSeekMode)")
        
        await MainActor.run {
            currentPage = 0
            hasMorePages = true
            debugMessage = "🚨 STARTING refreshListings for \(selectedFilter.rawValue)"
        }

        // BASIC CONNECTION TEST FIRST
        print("🚨 TESTING BASIC SUPABASE CONNECTION...")
        do {
            let connectionTest: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .limit(1)
                .execute()
                .value
            print("🚨 CONNECTION TEST: Got \(connectionTest.count) listings")
            if let first = connectionTest.first {
                print("🚨 CONNECTION TEST: First listing = \(first.title)")
            }
        } catch {
            print("🚨 CONNECTION TEST FAILED: \(error)")
            await MainActor.run {
                debugMessage = "❌ SUPABASE CONNECTION FAILED: \(error.localizedDescription)"
            }
            return
        }

        // TEMPORARY DEBUG: Test each filter explicitly
        await testFilters()

        print("🚨 About to execute REAL Supabase query...")
        do {
            // SIMPLE APPROACH - Build complete query based on filter
            let response: [ListingWithUser]
            
            if AppConfig.enableSeekMode, let intent = selectedFilter.intentFilter {
                await MainActor.run {
                    debugMessage = "🔍 Filtering by intent: \(intent.rawValue)"
                }
                print("🔥 APPLYING INTENT FILTER: \(intent.rawValue)")
                
                response = try await supabase
                    .from("listings")
                    .select("""
                        *,
                        user:users(*)
                    """)
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("intent", value: intent.rawValue)  // THE ACTUAL FILTER
                    .order("created_at", ascending: false)
                    .range(from: 0, to: pageSize - 1)
                    .execute()
                    .value
            } else {
                await MainActor.run {
                    debugMessage = "🔍 Showing all listings (no intent filter)"
                }
                print("🔥 NO INTENT FILTER - SHOWING ALL")
                
                response = try await supabase
                    .from("listings")
                    .select("""
                        *,
                        user:users(*)
                    """)
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .order("created_at", ascending: false)
                    .range(from: 0, to: pageSize - 1)
                    .execute()
                    .value
            }

            print("🚨🚨🚨 SUPABASE QUERY COMPLETED")
            print("🚨 Response count: \(response.count)")
            print("🚨 Response listings:")
            for (i, listing) in response.enumerated() {
                print("🚨   \(i): \(listing.title) - intent: \(listing.intent.rawValue)")
            }

            // Visual debug info will be shown in UI panel above

            await MainActor.run {
                queryResultCount = response.count
                
                // CRITICAL DEBUG: Log before and after updating listings
                print("🔥 BEFORE UPDATE - Current listings count: \(listings.count)")
                print("🔥 NEW RESPONSE - Response count: \(response.count)")
                
                listings = response
                
                print("🔥 AFTER UPDATE - Updated listings count: \(listings.count)")
                
                currentPage = 1
                hasMorePages = response.count == pageSize
                
                // Debug: Show intent values in the actual response
                let responseIntents = response.map { $0.intent.rawValue }
                let uniqueResponseIntents = Set(responseIntents)
                databaseIntents = uniqueResponseIntents
                
                debugMessage = "✅ Loaded \(response.count) listings for \(selectedFilter.rawValue). Intents: \(Array(uniqueResponseIntents).joined(separator: ", "))"
                
                // Extra debug: print first few listing titles
                for (index, listing) in listings.prefix(3).enumerated() {
                    print("🔥 Listing \(index): \(listing.title) - intent: \(listing.intent.rawValue)")
                }
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
        // SwiftUI views are structs; use value capture instead of [weak self]
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
    
    // TEMPORARY DEBUG METHOD
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
            
            // Check if all listings have intent values
            let intents = allListings.map { $0.intent.rawValue }
            let uniqueIntents = Set(intents)
            await MainActor.run {
                databaseIntents = uniqueIntents
            }
            
        } catch {
            await MainActor.run {
                debugMessage = "❌ Error loading listings: \(error.localizedDescription)"
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
        
        // TEMPORARY: If DB Intents is empty, it means listings don't have intent values
        // This helps confirm our diagnosis
        await MainActor.run {
            if databaseIntents.isEmpty {
                debugMessage = "❌ ISSUE: No intent values found in test query!"
            } else {
                debugMessage = "✅ Intent values found: \(Array(databaseIntents).joined(separator: ", "))"
            }
        }
    }
}
