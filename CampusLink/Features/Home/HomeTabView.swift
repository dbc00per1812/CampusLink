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
    
    // Unified filter selection
    @State private var selectedFilter: ListingFilter = .forYou
    // Ratings trust filter (Phase 3)
    
    // Search functionality (Phase 1)
    @State private var searchQuery = SearchQuery()
    @State private var isSearchActive = false
    @State private var showingSearchResults = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    // Seller dashboard
    @State private var showingSellerDashboard = false
    
    
    // Debug states for visual debugging
    
    private let pageSize = 10
    private let enableDomainFilter = true  // Enabled for production - campus-specific filtering
    
    enum ListingFilter: String, CaseIterable {
        case forYou = "For you"
        case all = "All"
        case forSale = "Selling"
        case wanted = "Buying"
        case more = "More"
        
        var icon: String? {
            switch self {
            case .forYou: return "star.fill"
            case .more: return "square.grid.2x2.fill"
            default: return nil
            }
        }
        
        var intentFilter: ListingIntent? {
            switch self {
            case .forYou: return nil
            case .all: return nil
            case .forSale: return .offer
            case .wanted: return .seek
            case .more: return nil
            }
        }
    }


    var body: some View {
        VStack(spacing: 0) {
            headerView()
            if AppConfig.enableSeekMode {
                filterView()
            }
            if selectedFilter == .forYou {
                todaysPicksHeader()
            }
            
            // Show category browser for "More" tab, otherwise show listing feed
            if selectedFilter == .more {
                NavigationView {
                    BrowseByCategoryView()
                }
            } else {
                contentView()
            }
        }
        // keep this screen interactable even if a parent mistakenly disabled it
        .disabled(false)
        .allowsHitTesting(true)
        .onAppear {
            PaymentService.shared.paymentResult = nil
            PaymentService.shared.paymentSheet  = nil
            Task { await loadAllListings() }
        }
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
        .sheet(isPresented: $showingSellerDashboard) {
            NavigationView {
                SellerDashboardView()
                    .environmentObject(authManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSellerDashboard = false
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
    private func todaysPicksHeader() -> some View {
        HStack {
            Text("Today's picks")
                .responsiveFont(.title2, weight: .bold)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .responsiveFont(.caption)
                    .foregroundColor(Color("ThemeColor"))
                if let userEmail = authManager.session?.user.email,
                   let domain = getDomainFromEmail(userEmail) {
                    Text(domain.capitalized)
                        .responsiveFont(.subheadline)
                        .foregroundColor(Color("ThemeColor"))
                }
            }
        }
        .responsiveHorizontalSpacing(16)
        .responsiveSpacing(8)
        .background(Color(UIColor.systemBackground))
    }
    
    @ViewBuilder
    private func filterView() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ResponsiveHStack(spacing: 8) {
                ForEach(ListingFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        if filter != .more {
                            Task {
                                switch filter {
                                case .forYou:
                                    await loadAllListings()
                                case .all:
                                    await loadAllListings()
                                case .forSale:
                                    await loadOfferListings()
                                case .wanted:
                                    await loadSeekListings()
                                case .more:
                                    break // Category browser view shown in body
                                }
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            if let icon = filter.icon {
                                Image(systemName: icon)
                                    .font(.caption)
                            }
                            Text(filter.rawValue)
                                .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .regular))
                        }
                        .foregroundColor(selectedFilter == filter ? .white : Color("ThemeColor"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
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
                Button(action: {
                    showingSellerDashboard = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .responsiveFontSize(20)
                        Text("Sell now")
                            .responsiveFont(.subheadline, weight: .medium)
                    }
                    .foregroundColor(Color("ThemeColor"))
                    .responsiveHorizontalSpacing(12)
                    .responsiveSpacing(8)
                    .background(Color("ThemeColor").opacity(0.1))
                    .responsiveCornerRadius(20)
                }
                .accessibleButton("View seller dashboard")
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
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            if isLoadingMore {
                HStack { Spacer(); ProgressView().padding(16); Spacer() }
            }

            if !hasMorePages && !listings.isEmpty {
                HStack {
                    Spacer()
                    Text("You've reached the end")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(16)
                    Spacer()
                }
            }
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
    
    // Helper function to extract domain from email
    private func getDomainFromEmail(_ email: String) -> String? {
        let components = email.components(separatedBy: "@")
        return components.count == 2 ? components[1].lowercased() : nil
    }
    
    // Apply domain filtering to listings
    private func applyDomainFilter(_ listings: [ListingWithUser]) async -> [ListingWithUser] {
        guard enableDomainFilter else { return listings }
        
        // Get current user's email domain
        guard let currentUserEmail = authManager.session?.user.email,
              let currentDomain = getDomainFromEmail(currentUserEmail) else {
            print("🔍 Domain Filter: Could not get current user's email domain")
            return listings // Return all listings if we can't determine domain
        }
        
        print("🔍 Domain Filter: Current user domain: \(currentDomain)")
        
        // Filter listings to only show those from users with the same domain
        let filteredListings = listings.filter { listing in
            guard let userEmail = listing.user.email,
                  let userDomain = getDomainFromEmail(userEmail) else {
                print("⚠️ Domain Filter: Excluding listing '\(listing.title)' - user has no email or invalid domain (email: \(listing.user.email ?? "nil"))")
                return false // Exclude listings from users without valid email domains
            }
            
            let shouldInclude = userDomain == currentDomain
            if !shouldInclude {
                print("🚫 Domain Filter: Excluding listing '\(listing.title)' - domain mismatch (user: \(userDomain) vs current: \(currentDomain))")
            } else {
                print("✅ Domain Filter: Including listing '\(listing.title)' - domain match (both: \(currentDomain))")
            }
            
            return shouldInclude
        }
        
        print("🔍 Domain Filter: Filtered \(listings.count) listings to \(filteredListings.count) for domain \(currentDomain)")
        
        return filteredListings
    }

    // If we filter client-side for trust, fetch extra rows so we can still fill a page visually.
    private var overscanMultiplier: Int { 1 }


    private func loadListings() async {
        // Load listings based on current filter
        switch selectedFilter {
        case .forYou:
            await loadAllListings()
        case .all:
            await loadAllListings()
        case .forSale:
            await loadOfferListings()
        case .wanted:
            await loadSeekListings()
        case .more:
            break // Category browser view shown in body
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
            
            // Apply domain filtering
            let filteredResult = await applyDomainFilter(result)
            
            await MainActor.run {
                listings = filteredResult
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
            
            print("🔍 Loaded \(result.count) offer listings")
            
            // Apply domain filtering
            let filteredResult = await applyDomainFilter(result)
            
            await MainActor.run {
                listings = filteredResult
                isLoading = false
            }
        } catch {
            print("❌ Error loading offer listings: \(error)")
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
            
            // Apply domain filtering
            let filteredResult = await applyDomainFilter(result)
            
            await MainActor.run {
                listings = filteredResult
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
        case .forYou:
            await loadAllListings()
        case .all:
            await loadAllListings()
        case .forSale:
            await loadOfferListings()
        case .wanted:
            await loadSeekListings()
        case .more:
            break // Category browser view shown in body
        }
    }
}

// MARK: - Listing Card (unchanged except optional trust loading usage)

struct ListingCard: View {
    let listing: ListingWithUser
    @State private var currentImageIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square image at top
            listingImagesCarousel()

            VStack(alignment: .leading, spacing: 6) {
                // Price first - large and bold
                if AppConfig.enableSeekMode && listing.intent == .seek {
                    if let min = listing.budgetMin, let max = listing.budgetMax {
                        Text("$\(min, specifier: "%.0f")-$\(max, specifier: "%.0f")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color("ThemeColor"))
                    } else if let max = listing.budgetMax {
                        Text("Up to $\(max, specifier: "%.0f")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color("ThemeColor"))
                    }
                } else {
                    Text("$\((listing.price ?? 0), specifier: "%.0f")")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color("ThemeColor"))
                }
                
                // Title - medium weight
                Text(listing.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Author with profile picture and verified badge
                HStack(spacing: 6) {
                    // Profile picture placeholder
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        )
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(listing.user.name ?? "Unknown")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color("ThemeColor"))
                            Text("Verified Student")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func listingImagesCarousel() -> some View {
        let urls: [String] = !listing.photos.isEmpty ? listing.photos : (listing.photo != nil ? [listing.photo!] : [])
        
        GeometryReader { geometry in
            let size = geometry.size.width
            
            if urls.isEmpty {
                // No photo placeholder - square
                Rectangle()
                    .fill(Color(UIColor.systemGray6))
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("No photo")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    )
                    .frame(width: size, height: size)
            } else if urls.count == 1 {
                // Single image - square
                if let url = URL(string: urls[0]) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipped()
                        case .failure(_):
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(width: size, height: size)
                        case .empty:
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(width: size, height: size)
                                .overlay(ProgressView())
                        @unknown default:
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(width: size, height: size)
                        }
                    }
                }
            } else {
                // Multiple images - show first with indicator
                if let url = URL(string: urls[0]) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: size, height: size)
                                .clipped()
                                .overlay(
                                    // Image counter in top-right
                                    VStack {
                                        HStack {
                                            Spacer()
                                            HStack(spacing: 3) {
                                                Image(systemName: "photo.stack")
                                                    .font(.system(size: 9))
                                                Text("\(urls.count)")
                                                    .font(.system(size: 10, weight: .medium))
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(8)
                                            .padding(6)
                                        }
                                        Spacer()
                                    }
                                )
                        case .failure(_):
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(width: size, height: size)
                        case .empty:
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(width: size, height: size)
                                .overlay(ProgressView())
                        @unknown default:
                            Rectangle()
                                .fill(Color(UIColor.systemGray6))
                                .frame(width: size, height: size)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
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
