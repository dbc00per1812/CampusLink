import SwiftUI
import Supabase

// Simple struct just for fetching email
private struct UserEmailFetch: Codable { let email: String? }

struct HomeTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var activeOrderMonitor: ActiveOrderMonitor

    @State private var listings: [ListingWithUser] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMorePages = true
    @State private var currentPage = 0
    @State private var userCampus: String?
    
    // Infinite scroll: store original listings to loop through
    @State private var originalListings: [ListingWithUser] = []
    @State private var isLooping = false
    
    // Diversification for recommendations
    @State private var useDiversification = false
    
    // Unified filter selection
    @State private var selectedFilter: ListingFilter = .forYou
    // Ratings trust filter (Phase 3)
    
    // Search functionality (Phase 1)
    @State private var searchQuery = SearchQuery()
    @State private var isSearchActive = false
    @State private var searchResults: [ListingWithUser] = []
    @State private var searchWorkItem: DispatchWorkItem?
    
    // Category filtering
    @State private var selectedCategory: String?
    @State private var selectedCategoryType: ListingType?
    @State private var showingCategoryBrowser = false
    
    // Seller dashboard
    @State private var showingSellerDashboard = false
    
    // Transaction guide
    @State private var showingTransactionGuide = false
    
    // Active transactions
    @State private var showingMyTransactions = false
    
    // Active order banner
    @State private var firstActiveOrder: Order?
    @State private var showingActiveOrderDetail = false
    
    // Debug states for visual debugging
    
    private let pageSize = 20  // Load 20 listings per page for smooth infinite scroll
    private let enableCampusFilter = true  // Enabled for production - campus-specific filtering
    
    enum ListingFilter: String, CaseIterable {
        case forYou = "For you"
        case all = "All"
        case forSale = "Selling"
        case wanted = "Wanted"
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
            
            // Active order banner (shows when there's an active order)
            if activeOrderMonitor.ordersRequiringAction > 0 {
                activeOrderBanner()
            }
            
            if AppConfig.enableSeekMode {
                filterView()
            }
            if selectedFilter == .forYou {
                todaysPicksHeader()
            }
            
            // Always show content view
            contentView()
        }
        // keep this screen interactable even if a parent mistakenly disabled it
        .disabled(false)
        .allowsHitTesting(true)
        .onAppear {
            PaymentService.shared.paymentResult = nil
            PaymentService.shared.paymentSheet  = nil
            // Enable diversification for initial load (For You tab by default)
            useDiversification = true
            Task {
                await loadUserCampus()
                await loadAllListings()
                
                // Force refresh active order count on appear
                if let userId = authManager.session?.user.id {
                    print("🔄 Forcing active order monitor refresh on appear")
                    await activeOrderMonitor.checkActiveOrders(userId: userId)
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
        .sheet(isPresented: $showingCategoryBrowser) {
            NavigationView {
                BrowseByCategoryView(onCategorySelected: { category, type in
                    // Close the sheet
                    showingCategoryBrowser = false
                    
                    // Set the category filter
                    selectedCategory = category
                    selectedCategoryType = type
                    
                    // Reset pagination and clear listings for category browsing
                    currentPage = 0
                    hasMorePages = true
                    listings = []  // Clear existing listings to prevent duplicates
                    
                    // Load category listings
                    Task {
                        await loadCategoryListings(category: category, type: type)
                    }
                })
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingCategoryBrowser = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingTransactionGuide) {
            TransactionGuideView()
        }
        .sheet(isPresented: $showingMyTransactions) {
            NavigationView {
                MyTransactionsView()
                    .environmentObject(authManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingMyTransactions = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingActiveOrderDetail) {
                NavigationView {
                if let order = firstActiveOrder {
                    OrderDetailView(order: order)
                        .environmentObject(authManager)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingActiveOrderDetail = false
                                }
                            }
                        }
                } else {
                    // Show error/loading state if no order found
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Unable to Load Order")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("The active order could not be loaded. It may have been completed or cancelled.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 40)
                        
                        Button("Close") {
                            showingActiveOrderDetail = false
                        }
                        .buttonStyle(.bordered)
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingActiveOrderDetail = false
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: activeOrderMonitor.ordersRequiringAction) { _, newCount in
            // Load first active order when count changes
            print("📊 Active order count changed to: \(newCount)")
            Task {
                await loadFirstActiveOrder()
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
                Text(userCampus != nil ? campusAbbreviation(userCampus!) : "Campus")
                    .responsiveFont(.subheadline)
                    .foregroundColor(Color("ThemeColor"))
                Image(systemName: "location.fill")
                    .responsiveFont(.caption)
                    .foregroundColor(Color("ThemeColor"))
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
                        // Clear search when switching filters
                        isSearchActive = false
                        searchResults = []
                        searchQuery = SearchQuery()
                        
                        // Reset pagination, looping, and clear listings when changing filters
                        currentPage = 0
                        hasMorePages = true
                        listings = []  // Clear existing listings to prevent duplicates
                        originalListings = []  // Clear for fresh loop cycle
                        isLooping = false
                        
                        // Enable diversification for For You, All, and Selling tabs
                        useDiversification = (filter == .forYou || filter == .all || filter == .forSale)
                        
                        if filter == .more {
                            // Show category browser sheet
                            showingCategoryBrowser = true
                        } else {
                            // Clear category filter when switching to other tabs
                            selectedCategory = nil
                            selectedCategoryType = nil
                            
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
                                    break // Handled above
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
                Image("BrandIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                Spacer()
                Button(action: {
                    showingTransactionGuide = true
                }) {
                    Image(systemName: "questionmark.circle.fill")
                        .responsiveFontSize(16)
                        .foregroundColor(Color("ThemeColor"))
                        .responsiveHorizontalSpacing(10)
                        .responsiveSpacing(8)
                        .background(Color("ThemeColor").opacity(0.1))
                        .responsiveCornerRadius(20)
                }
                .accessibleButton("View transaction guide")
                
                Button(action: {
                    showingSellerDashboard = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "dollarsign.circle.fill")
                            .responsiveFontSize(16)
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
    private func activeOrderBanner() -> some View {
        Button(action: {
            print("🔘 Active order banner tapped - Count: \(activeOrderMonitor.ordersRequiringAction)")
            
            // If multiple orders, go to transactions view instead
            if activeOrderMonitor.ordersRequiringAction > 1 {
                print("🔀 Multiple active orders - navigating to transactions view")
                showingMyTransactions = true
            } else {
                // Single order - load and show detail
            Task {
                await loadFirstActiveOrder()
                    // Always show sheet - it will display error if order not found
                    await MainActor.run {
                showingActiveOrderDetail = true
                    }
                    if firstActiveOrder == nil {
                        print("⚠️ Active order banner: No order loaded, showing error view")
                    } else {
                        print("✅ Active order banner: Order loaded successfully, showing detail")
                    }
                }
            }
        }) {
            HStack(spacing: 12) {
                // Red circle icon
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                Text(activeOrderMonitor.ordersRequiringAction == 1 ? "Active Order" : "Active Orders")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                Text(activeOrderMonitor.ordersRequiringAction == 1 
                     ? "You have 1 order requiring action" 
                     : "Tap to view \(activeOrderMonitor.ordersRequiringAction) orders")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func contentView() -> some View {
        if isLoading {
            loadingView()
        } else if isSearchActive && searchResults.isEmpty {
            searchEmptyStateView()
        } else if selectedCategory != nil && listings.isEmpty {
            categoryEmptyStateView()
        } else if !isSearchActive && selectedCategory == nil && listings.isEmpty {
            emptyStateView()
        } else {
            listView()
        }
    }

    @ViewBuilder
    private func loadingView() -> some View {
        ScrollView {
            ListingGridSkeleton(count: 6)
        }
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
    private func searchEmptyStateView() -> some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No results found")
                .font(.title2)
                .fontWeight(.semibold)
            
            if !searchQuery.text.isEmpty {
                Text("Try a different search term or adjust your filters")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Enter a search term to find listings")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        Spacer()
    }
    
    @ViewBuilder
    private func categoryEmptyStateView() -> some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            if let category = selectedCategory {
                Text("No \(category) listings yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Be the first to post in this category!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("No listings found")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        Spacer()
    }

    // Helper to get display listings with diversification applied
    private func getDisplayListings() -> [ListingWithUser] {
        let baseListings = isSearchActive ? searchResults : listings
        
        #if DEBUG
        print("🔍 Diversification check:")
        print("   useDiversification: \(useDiversification)")
        print("   isSearchActive: \(isSearchActive)")
        print("   currentPage: \(currentPage)")
        print("   baseListings.count: \(baseListings.count)")
        #endif
        
        // SKIP diversification - interest prioritization already applied in loadAllListings()
        // Diversification would reshuffle and undo the interest-based ordering
        #if DEBUG
        print("⏭️  Skipping diversification (using interest-based prioritization instead)")
        #endif
        return baseListings
    }
    
    @ViewBuilder
    private func listView() -> some View {
        let displayListings = getDisplayListings()
        
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(displayListings) { listing in
                    NavigationLink(destination: ListingDetailView(listing: listing)) {
                        ListingCard(listing: listing)
                    }
                    .buttonStyle(.plain)
                    .id(listing.id) // Ensure stable identity
                    .onAppear {
                        if !isSearchActive && listing.id == listings.suffix(3).first?.id {
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
        }
        .refreshable { 
            if isSearchActive {
                await performSearchInternal(searchQuery)
            } else {
                await refreshListings()
            }
        }
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
    
    // Apply campus filtering to listings
    private func applyCampusFilter(_ listings: [ListingWithUser]) async -> [ListingWithUser] {
        guard enableCampusFilter else { return listings }
        
        // Get current user's campus from their profile
        guard let currentUserId = authManager.session?.user.id.uuidString else {
            print("🔍 Campus Filter: Could not get current user's ID")
            return listings // Return all listings if we can't determine user
        }
        
        // Fetch current user's campus
        do {
            let currentUser: User = try await supabase
                .from("users")
                .select("id, campus, created_at")
                .eq("id", value: currentUserId)
                .single()
                .execute()
                .value
            
            guard let currentCampus = currentUser.campus, !currentCampus.isEmpty else {
                print("🔍 Campus Filter: Current user has no campus set")
                return listings // Return all listings if user has no campus
            }
            
            print("🔍 Campus Filter: Current user campus: \(currentCampus)")
            
            // Filter listings to only show those from users with the same campus
            let filteredListings = listings.filter { listing in
                guard let userCampus = listing.user.campus, !userCampus.isEmpty else {
                    print("⚠️ Campus Filter: Excluding listing '\(listing.title)' - user has no campus set")
                    return false // Exclude listings from users without campus
                }
                
                // Case-insensitive, whitespace-tolerant comparison to handle minor variations
                let normalizedUserCampus = userCampus.trimmingCharacters(in: .whitespaces).lowercased()
                let normalizedCurrentCampus = currentCampus.trimmingCharacters(in: .whitespaces).lowercased()
                let shouldInclude = normalizedUserCampus == normalizedCurrentCampus
                
                if !shouldInclude {
                    print("🚫 Campus Filter: Excluding listing '\(listing.title)' - campus mismatch (user: '\(userCampus)' vs current: '\(currentCampus)')")
                } else {
                    print("✅ Campus Filter: Including listing '\(listing.title)' - campus match (both: '\(currentCampus)')")
                }
                
                return shouldInclude
            }
            
            print("🔍 Campus Filter: Filtered \(listings.count) listings to \(filteredListings.count) for campus \(currentCampus)")
            
            return filteredListings
        } catch {
            print("❌ Campus Filter: Error fetching user campus: \(error)")
            return listings // Return unfiltered if error
        }
    }
    
    /// Filter listings to exclude those from blocked users
    private func applyBlockedUsersFilter(_ listings: [ListingWithUser], currentUserId: String) async -> [ListingWithUser] {
        do {
            let blockedIds = try await BlockedUsersService.getBlockedUserIds(currentUserId: currentUserId)
            
            guard !blockedIds.isEmpty else {
                #if DEBUG
                print("🔍 Blocked Users Filter: No blocked users")
                #endif
                return listings
            }
            
            let filteredListings = listings.filter { listing in
                !blockedIds.contains(listing.user.id)
            }
            
            #if DEBUG
            print("🔍 Blocked Users Filter: Filtered \(listings.count) listings to \(filteredListings.count) (removed \(listings.count - filteredListings.count) from blocked users)")
            #endif
            
            return filteredListings
        } catch {
            #if DEBUG
            print("❌ Blocked Users Filter: Error fetching blocked users: \(error)")
            #endif
            return listings // Return unfiltered on error
        }
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
        // Don't load if already loading
        guard !isLoadingMore else { return }
        
        // If we've reached the end and have original listings, loop them
        if !hasMorePages && !originalListings.isEmpty {
            await MainActor.run {
                isLoadingMore = true
            }
            
            // Small delay to simulate loading for smooth UX
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            await MainActor.run {
                // Append a shuffled version of original listings to add variety
                let shuffledOriginals = originalListings.shuffled()
                listings.append(contentsOf: shuffledOriginals)
                isLooping = true
                isLoadingMore = false
            }
            return
        }
        
        // Normal pagination if still have pages
        guard hasMorePages else { return }
        
        await MainActor.run {
            isLoadingMore = true
            currentPage += 1
        }
        
        // Load next page using current filter
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
            break // Category browser uses separate pagination
        }
        
        await MainActor.run {
            isLoadingMore = false
        }
    }

    private func loadAllListings() async {
        do {
            // Get current campus (from authenticated user or guest AppStorage)
            let currentCampus: String?
            
            if let currentUserId = authManager.session?.user.id.uuidString {
                // Authenticated user - fetch campus from database
                let currentUser: User = try await supabase
                    .from("users")
                    .select("id, campus, created_at")
                    .eq("id", value: currentUserId)
                    .single()
                    .execute()
                    .value
                currentCampus = currentUser.campus
            } else {
                // Guest user - get campus from AppStorage
                currentCampus = UserDefaults.standard.string(forKey: "guestSelectedCampus")
                print("🔍 Guest user loading listings for campus: \(currentCampus ?? "nil")")
            }
            
            // Generate cache key
            let cacheKey = DataCacheManager.homeListingsKey(
                page: currentPage,
                filter: "all",
                campus: enableCampusFilter ? currentCampus : nil
            )
            
            // Check cache first (INSTANT LOADING)
            if let cachedListings = DataCacheManager.shared.getListings(forKey: cacheKey) {
                await MainActor.run {
                    if currentPage == 0 {
                        self.listings = cachedListings
                    } else {
                        // Append cached page, avoiding duplicates
                        let existingIds = Set(listings.map { $0.id })
                        let newListings = cachedListings.filter { !existingIds.contains($0.id) }
                        self.listings.append(contentsOf: newListings)
                    }
                    self.isLoading = false
                    
                    // Prefetch images for cached listings
                    prefetchImages(for: cachedListings)
                }
                
                // Still fetch fresh data in background to update cache
                // But don't block the UI
            }
            
            // Calculate pagination offset
            let offset = currentPage * pageSize
            
            guard let campusValue = currentCampus, !campusValue.isEmpty, enableCampusFilter else {
                // No campus or filter disabled - fetch all listings with pagination
                let result: [ListingWithUser] = try await supabase
                    .from("listings")
                    .select("*, user:users(*)")
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                
                print("🔍 Loaded \(result.count) listings (page \(currentPage), no campus filter)")
                
                // Apply blocked users filtering (only for authenticated users)
                var filteredResult = result
                if let currentUserId = authManager.currentUserId {
                    filteredResult = await applyBlockedUsersFilter(filteredResult, currentUserId: currentUserId)
                }
                
                await MainActor.run {
                    if currentPage == 0 {
                        listings = filteredResult
                    } else {
                        listings.append(contentsOf: filteredResult)
                    }
                    hasMorePages = result.count == pageSize
                    isLoading = false
                }
                return
            }
            
            print("🔍 Loading listings for campus: \(campusValue) (page \(currentPage))")
            
            // Fetch listings with campus filter applied at DATABASE level (server-side) + pagination
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users!inner(*)")  // inner join to filter by user properties
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("users.campus", value: campusValue)  // Server-side campus filter
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)  // Pagination
                .execute()
                .value
            
            print("🔍 Loaded \(result.count) listings for campus \(campusValue) (page \(currentPage))")
            
            // Apply blocked users filtering (only for authenticated users)
            var filteredResult = result
            if let currentUserId = authManager.currentUserId {
                filteredResult = await applyBlockedUsersFilter(filteredResult, currentUserId: currentUserId)
            }
            
            // Cache the fresh data
            DataCacheManager.shared.cacheListings(filteredResult, forKey: cacheKey, ttl: 300)
            
            // Apply interest-based prioritization for "For You" tab on first page
            var finalListings = filteredResult
            if selectedFilter == .forYou && currentPage == 0, let userId = authManager.session?.user.id.uuidString {
                finalListings = await UserInterestService.shared.prioritizeListings(filteredResult, userId: userId)
                print("🎯 Applied interest-based prioritization to \(finalListings.count) listings")
            }
            
            await MainActor.run {
                if currentPage == 0 {
                    // First page - replace listings and store as originals for looping
                    listings = finalListings
                    originalListings = finalListings
                    isLooping = false
                } else if !isLooping {
                    // Subsequent pages - append to existing listings, avoiding duplicates
                    let existingIds = Set(listings.map { $0.id })
                    let newListings = finalListings.filter { !existingIds.contains($0.id) }
                    listings.append(contentsOf: newListings)
                    // Also add to originals for looping
                    originalListings.append(contentsOf: newListings)
                }
                // If we got fewer than pageSize results, we've reached the end
                hasMorePages = result.count == pageSize
                isLoading = false
                
                // Prefetch images for newly loaded listings
                prefetchImages(for: finalListings)
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
            // Get current campus (from authenticated user or guest AppStorage)
            let currentCampus: String?
            
            if let currentUserId = authManager.session?.user.id.uuidString {
                // Authenticated user - fetch campus from database
                let currentUser: User = try await supabase
                    .from("users")
                    .select("id, campus, created_at")
                    .eq("id", value: currentUserId)
                    .single()
                    .execute()
                    .value
                currentCampus = currentUser.campus
            } else {
                // Guest user - get campus from AppStorage
                currentCampus = UserDefaults.standard.string(forKey: "guestSelectedCampus")
                print("🔍 Guest user loading offer listings for campus: \(currentCampus ?? "nil")")
            }
            
            // Generate cache key
            let cacheKey = DataCacheManager.homeListingsKey(
                page: currentPage,
                filter: "offer",
                campus: enableCampusFilter ? currentCampus : nil
            )
            
            // Check cache first (INSTANT LOADING)
            if let cachedListings = DataCacheManager.shared.getListings(forKey: cacheKey) {
                await MainActor.run {
                    if currentPage == 0 {
                        self.listings = cachedListings
                    } else {
                        let existingIds = Set(listings.map { $0.id })
                        let newListings = cachedListings.filter { !existingIds.contains($0.id) }
                        self.listings.append(contentsOf: newListings)
                    }
                    self.isLoading = false
                    prefetchImages(for: cachedListings)
                }
            }
            
            // Calculate pagination offset
            let offset = currentPage * pageSize
            
            guard let campusValue = currentCampus, !campusValue.isEmpty, enableCampusFilter else {
                // No campus or filter disabled - fetch all listings with pagination
                let result: [ListingWithUser] = try await supabase
                    .from("listings")
                    .select("*, user:users(*)")
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("intent", value: "offer")
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                
                print("🔍 Loaded \(result.count) offer listings (page \(currentPage), no campus filter)")
                
                // Apply blocked users filtering (only for authenticated users)
                var filteredResult = result
                if let currentUserId = authManager.currentUserId {
                    filteredResult = await applyBlockedUsersFilter(filteredResult, currentUserId: currentUserId)
                }
                
                await MainActor.run {
                    if currentPage == 0 {
                        listings = filteredResult
                    } else {
                        listings.append(contentsOf: filteredResult)
                    }
                    hasMorePages = result.count == pageSize
                    isLoading = false
                }
                return
            }
            
            print("🔍 Loading offer listings for campus: \(campusValue) (page \(currentPage))")
            
            // Fetch listings with campus filter applied at DATABASE level (server-side) + pagination
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users!inner(*)")  // inner join to filter by user properties
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "offer")
                .eq("users.campus", value: campusValue)  // Server-side campus filter
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)  // Pagination
                .execute()
                .value
            
            print("🔍 Loaded \(result.count) offer listings for campus \(campusValue) (page \(currentPage))")
            
            // Apply blocked users filtering (only for authenticated users)
            var filteredResult = result
            if let currentUserId = authManager.currentUserId {
                filteredResult = await applyBlockedUsersFilter(filteredResult, currentUserId: currentUserId)
            }
            
            // Cache the fresh data
            DataCacheManager.shared.cacheListings(filteredResult, forKey: cacheKey, ttl: 300)
            
            await MainActor.run {
                if currentPage == 0 {
                    listings = filteredResult
                    originalListings = filteredResult
                    isLooping = false
                } else if !isLooping {
                    // Append to existing listings, avoiding duplicates
                    let existingIds = Set(listings.map { $0.id })
                    let newListings = filteredResult.filter { !existingIds.contains($0.id) }
                    listings.append(contentsOf: newListings)
                    originalListings.append(contentsOf: newListings)
                }
                hasMorePages = result.count == pageSize
                isLoading = false
                
                // Prefetch images for newly loaded listings
                prefetchImages(for: filteredResult)
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
            // Get current campus (from authenticated user or guest AppStorage)
            let currentCampus: String?
            
            if let currentUserId = authManager.session?.user.id.uuidString {
                // Authenticated user - fetch campus from database
                let currentUser: User = try await supabase
                    .from("users")
                    .select("id, campus, created_at")
                    .eq("id", value: currentUserId)
                    .single()
                    .execute()
                    .value
                currentCampus = currentUser.campus
            } else {
                // Guest user - get campus from AppStorage
                currentCampus = UserDefaults.standard.string(forKey: "guestSelectedCampus")
                print("🔍 Guest user loading seek listings for campus: \(currentCampus ?? "nil")")
            }
            
            // Generate cache key
            let cacheKey = DataCacheManager.homeListingsKey(
                page: currentPage,
                filter: "seek",
                campus: enableCampusFilter ? currentCampus : nil
            )
            
            // Check cache first (INSTANT LOADING)
            if let cachedListings = DataCacheManager.shared.getListings(forKey: cacheKey) {
                await MainActor.run {
                    if currentPage == 0 {
                        self.listings = cachedListings
                    } else {
                        let existingIds = Set(listings.map { $0.id })
                        let newListings = cachedListings.filter { !existingIds.contains($0.id) }
                        self.listings.append(contentsOf: newListings)
                    }
                    self.isLoading = false
                    prefetchImages(for: cachedListings)
                }
            }
            
            // Calculate pagination offset
            let offset = currentPage * pageSize
            
            guard let campusValue = currentCampus, !campusValue.isEmpty, enableCampusFilter else {
                // No campus or filter disabled - fetch all listings with pagination
                let result: [ListingWithUser] = try await supabase
                    .from("listings")
                    .select("*, user:users(*)")
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("intent", value: "seek")
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                
                print("🔍 SEEK FILTER: Found \(result.count) seeking posts (page \(currentPage), no campus filter)")
                
                // Apply blocked users filtering (only for authenticated users)
                var filteredResult = result
                if let currentUserId = authManager.currentUserId {
                    filteredResult = await applyBlockedUsersFilter(filteredResult, currentUserId: currentUserId)
                }
                
                await MainActor.run {
                    if currentPage == 0 {
                        listings = filteredResult
                    } else {
                        listings.append(contentsOf: filteredResult)
                    }
                    hasMorePages = result.count == pageSize
                    isLoading = false
                }
                return
            }
            
            print("🔍 Loading seek listings for campus: \(campusValue) (page \(currentPage))")
            
            // Fetch listings with campus filter applied at DATABASE level (server-side) + pagination
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users!inner(*)")  // inner join to filter by user properties
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("intent", value: "seek")
                .eq("users.campus", value: campusValue)  // Server-side campus filter
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)  // Pagination
                .execute()
                .value
            
            print("🔍 SEEK FILTER: Found \(result.count) seeking posts for campus \(campusValue) (page \(currentPage))")
            
            // Apply blocked users filtering (only for authenticated users)
            var filteredResult = result
            if let currentUserId = authManager.currentUserId {
                filteredResult = await applyBlockedUsersFilter(filteredResult, currentUserId: currentUserId)
            }
            
            // Cache the fresh data
            DataCacheManager.shared.cacheListings(filteredResult, forKey: cacheKey, ttl: 300)
            
            await MainActor.run {
                if currentPage == 0 {
                    listings = filteredResult
                    originalListings = filteredResult
                    isLooping = false
                } else if !isLooping {
                    // Append to existing listings, avoiding duplicates
                    let existingIds = Set(listings.map { $0.id })
                    let newListings = filteredResult.filter { !existingIds.contains($0.id) }
                    listings.append(contentsOf: newListings)
                    originalListings.append(contentsOf: newListings)
                }
                hasMorePages = result.count == pageSize
                isLoading = false
                
                // Prefetch images for newly loaded listings
                prefetchImages(for: filteredResult)
            }
        } catch {
            print("❌ Error loading seek listings: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadCategoryListings(category: String, type: ListingType) async {
        do {
            // Get current campus (from authenticated user or guest AppStorage)
            let currentCampus: String?
            
            if let currentUserId = authManager.session?.user.id.uuidString {
                // Authenticated user - fetch campus from database
                let currentUser: User = try await supabase
                    .from("users")
                    .select("id, campus, created_at")
                    .eq("id", value: currentUserId)
                    .single()
                    .execute()
                    .value
                currentCampus = currentUser.campus
            } else {
                // Guest user - get campus from AppStorage
                currentCampus = UserDefaults.standard.string(forKey: "guestSelectedCampus")
                print("🔍 Guest user loading category listings for campus: \(currentCampus ?? "nil")")
            }
            
            // Generate cache key
            let cacheKey = DataCacheManager.categoryListingsKey(
                category: category,
                type: type.rawValue,
                page: currentPage
            )
            
            // Check cache first (INSTANT LOADING)
            if let cachedListings = DataCacheManager.shared.getListings(forKey: cacheKey) {
                await MainActor.run {
                    if currentPage == 0 {
                        self.listings = cachedListings
                    } else {
                        let existingIds = Set(listings.map { $0.id })
                        let newListings = cachedListings.filter { !existingIds.contains($0.id) }
                        self.listings.append(contentsOf: newListings)
                    }
                    self.isLoading = false
                    prefetchImages(for: cachedListings)
                }
            }
            
            // Calculate pagination offset
            let offset = currentPage * pageSize
            
            guard let campusValue = currentCampus, !campusValue.isEmpty, enableCampusFilter else {
                // No campus or filter disabled - fetch all listings with pagination
                let result: [ListingWithUser] = try await supabase
                    .from("listings")
                    .select("*, user:users(*)")
                    .eq("status", value: "active")
                    .neq("archived", value: true)
                    .eq("is_sold", value: false)
                    .eq("category", value: category)
                    .eq("listing_type", value: type.rawValue)
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + pageSize - 1)
                    .execute()
                    .value
                
                print("🔍 Category Filter: Found \(result.count) \(category) listings (page \(currentPage), no campus filter)")
                
                await MainActor.run {
                    if currentPage == 0 {
                        listings = result
                    } else {
                        listings.append(contentsOf: result)
                    }
                    hasMorePages = result.count == pageSize
                    isLoading = false
                }
                return
            }
            
            print("🔍 Loading category listings for campus: \(campusValue) (page \(currentPage))")
            
            // Fetch listings with campus filter applied at DATABASE level (server-side) + pagination
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users!inner(*)")  // inner join to filter by user properties
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("category", value: category)
                .eq("listing_type", value: type.rawValue)
                .eq("users.campus", value: campusValue)  // Server-side campus filter
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + pageSize - 1)  // Pagination
                .execute()
                .value
            
            print("🔍 Category Filter: Found \(result.count) \(category) listings for campus \(campusValue) (page \(currentPage))")
            
            // Cache the fresh data
            DataCacheManager.shared.cacheListings(result, forKey: cacheKey, ttl: 300)
            
            await MainActor.run {
                if currentPage == 0 {
                    listings = result
                    originalListings = result
                    isLooping = false
                } else if !isLooping {
                    // Append to existing listings, avoiding duplicates
                    let existingIds = Set(listings.map { $0.id })
                    let newListings = result.filter { !existingIds.contains($0.id) }
                    listings.append(contentsOf: newListings)
                    originalListings.append(contentsOf: newListings)
                }
                hasMorePages = result.count == pageSize
                isLoading = false
                
                // Prefetch images for newly loaded listings
                prefetchImages(for: result)
            }
        } catch {
            print("❌ Error loading category listings: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }


    private func refreshListings() async {
        // Reset pagination, looping state, and clear listings on refresh
        await MainActor.run {
            currentPage = 0
            hasMorePages = true
            listings = []  // Clear existing listings to prevent duplicates
            originalListings = []  // Clear originals for fresh loop cycle
            isLooping = false
        }
        
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
    
    private func loadUserCampus() async {
        // Check if user is authenticated
        if let userId = authManager.session?.user.id.uuidString {
            // Authenticated user - load campus from database
            print("🔍 Loading campus for authenticated user: \(userId)")
            
            do {
                let user: User = try await supabase
                    .from("users")
                    .select("id, campus, created_at")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                
                print("✅ Loaded user data - Campus: \(user.campus ?? "nil")")
                
                await MainActor.run {
                    self.userCampus = user.campus
                    print("✅ Set userCampus to: \(self.userCampus ?? "nil")")
                }
            } catch {
                print("❌ Error loading user campus: \(error)")
            }
        } else {
            // Guest user - load campus from AppStorage
            print("🔍 Loading campus for guest user from AppStorage")
            
            // Use @AppStorage directly via UserDefaults
            if let guestCampus = UserDefaults.standard.string(forKey: "guestSelectedCampus"), !guestCampus.isEmpty {
                print("✅ Found guest campus in AppStorage: \(guestCampus)")
                await MainActor.run {
                    self.userCampus = guestCampus
                    print("✅ Set userCampus to guest campus: \(guestCampus)")
                }
            } else {
                print("⚠️ No guest campus found in AppStorage")
                await MainActor.run {
                    self.userCampus = nil
                }
            }
        }
    }
    
    /// Load the first active order for banner navigation
    private func loadFirstActiveOrder() async {
        guard let userId = authManager.session?.user.id else {
            print("❌ No user ID found - cannot load active order")
            return
        }
        
        print("🔍 Loading first active order for user: \(userId)")
        print("🔍 Active order count from monitor: \(activeOrderMonitor.ordersRequiringAction)")
        
        do {
            // Try to fetch buyer orders first
            // 1. Buyer needs to PAY (order_status=placed, payment_status=pending)
            print("🔍 Checking buyer orders needing payment...")
            
            // First try WITHOUT listing join in case listing was archived
            let buyerOrdersNeedPay: [Order] = try await supabase
                .from("orders")
                .select("*")
                .eq("buyer_id", value: userId.uuidString)
                .eq("order_status", value: "placed")
                .eq("payment_status", value: "pending")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            print("🔍 Found \(buyerOrdersNeedPay.count) buyer orders needing payment")
            
            if !buyerOrdersNeedPay.isEmpty {
                print("🔍 Buyer order IDs needing payment: \(buyerOrdersNeedPay.map { $0.id })")
            }
            
            if let firstOrder = buyerOrdersNeedPay.first {
                await MainActor.run {
                    self.firstActiveOrder = firstOrder
                }
                print("✅ Loaded buyer order needing payment: \(firstOrder.id)")
                print("   - Status: \(firstOrder.orderStatus.rawValue)")
                print("   - Payment: \(firstOrder.paymentStatus.rawValue)")
                return
            }
            
            // 2. Buyer needs to CONFIRM RECEIPT (order_status=seller_confirmed, payment in succeeded or requires_capture)
            print("🔍 Checking buyer orders needing confirmation...")
            let buyerOrdersNeedConfirm: [Order] = try await supabase
                .from("orders")
                .select("*")
                .eq("buyer_id", value: userId.uuidString)
                .eq("order_status", value: "seller_confirmed")
                .`in`("payment_status", values: ["requires_capture", "succeeded"])
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            print("🔍 Found \(buyerOrdersNeedConfirm.count) buyer orders needing confirmation")
            
            if !buyerOrdersNeedConfirm.isEmpty {
                print("🔍 Buyer order IDs needing confirmation: \(buyerOrdersNeedConfirm.map { $0.id })")
            }
            
            if let firstOrder = buyerOrdersNeedConfirm.first {
                await MainActor.run {
                    self.firstActiveOrder = firstOrder
                }
                print("✅ Loaded buyer order needing confirmation: \(firstOrder.id)")
                print("   - Status: \(firstOrder.orderStatus.rawValue)")
                print("   - Payment: \(firstOrder.paymentStatus.rawValue)")
                return
            }
            
            // If no buyer orders, try seller orders (orders where user needs to deliver)
            // ONLY when payment is completed (not when payment is pending)
            print("🔍 Checking seller orders needing delivery...")
            let sellerOrders: [Order] = try await supabase
                .from("orders")
                .select("*")
                .eq("seller_id", value: userId.uuidString)
                .`in`("order_status", values: ["placed", "in_progress"])
                .`in`("payment_status", values: ["succeeded", "requires_capture"])
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            print("🔍 Found \(sellerOrders.count) seller orders needing delivery")
            
            if !sellerOrders.isEmpty {
                print("🔍 Seller order IDs needing delivery: \(sellerOrders.map { $0.id })")
            }
            
            if let firstOrder = sellerOrders.first {
                await MainActor.run {
                    self.firstActiveOrder = firstOrder
                }
                print("✅ Loaded seller order needing delivery: \(firstOrder.id)")
                print("   - Status: \(firstOrder.orderStatus.rawValue)")
                print("   - Payment: \(firstOrder.paymentStatus.rawValue)")
            } else {
                await MainActor.run {
                    self.firstActiveOrder = nil
                }
                print("⚠️ No active orders found despite monitor count being \(activeOrderMonitor.ordersRequiringAction)")
            }
        } catch {
            print("❌ Error loading first active order: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            print("❌ Error type: \(type(of: error))")
            
            // Check for specific error types
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ Missing key: \(key.stringValue)")
                    print("❌ Coding path: \(context.codingPath)")
                    print("❌ Debug description: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("❌ Type mismatch: expected \(type)")
                    print("❌ Coding path: \(context.codingPath)")
                    print("❌ Debug description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ Value not found: expected \(type)")
                    print("❌ Coding path: \(context.codingPath)")
                    print("❌ Debug description: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ Data corrupted")
                    print("❌ Coding path: \(context.codingPath)")
                    print("❌ Debug description: \(context.debugDescription)")
                @unknown default:
                    print("❌ Unknown decoding error")
                }
            }
            
            // Try to get raw data if possible
            if let postgrestError = error as? PostgrestError {
                print("❌ Postgrest error: \(postgrestError)")
            }
            
            await MainActor.run {
                self.firstActiveOrder = nil
            }
        }
    }
    
    private func campusAbbreviation(_ campus: String) -> String {
        switch campus {
        case "Indiana University Bloomington":
            return "IU"
        case "Purdue University":
            return "Purdue"
        default:
            return campus
        }
    }
    
    /// Prefetch images for upcoming listings in background
    private func prefetchImages(for listings: [ListingWithUser]) {
        let imageUrls = listings.flatMap { listing -> [String] in
            // Get all photo URLs for this listing
            if !listing.photos.isEmpty {
                return listing.photos
            } else if let photo = listing.photo {
                return [photo]
            }
            return []
        }
        
        // Prefetch in background
        ImageCacheManager.shared.prefetchImages(urls: imageUrls)
    }
}

// MARK: - Listing Card (unchanged except optional trust loading usage)

struct ListingCard: View {
    let listing: ListingWithUser
    @State private var currentImageIndex: Int = 0
    @EnvironmentObject var authManager: AuthManager
    
    private var currentUserId: String? {
        authManager.session?.user.id.uuidString
    }
    private var isOwnListing: Bool {
        guard let currentId = currentUserId else { return false }
        return listing.user.id.lowercased() == currentId.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square image at top
            listingImagesCarousel()

            VStack(alignment: .leading, spacing: 6) {
                // Price first - large and bold (always show seller's posted price)
                if AppConfig.enableSeekMode && listing.intent == .seek {
                    if let min = listing.budgetMin, let max = listing.budgetMax {
                        Text("$\(min, specifier: "%.0f")-$\(max, specifier: "%.0f")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isOwnListing ? .blue : .green)
                    } else if let max = listing.budgetMax {
                        Text("Up to $\(max, specifier: "%.0f")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isOwnListing ? .blue : .green)
                    }
                } else {
                    // Show seller's posted price for everyone (fees shown at checkout)
                    Text("$\((listing.price ?? 0), specifier: "%.2f")")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isOwnListing ? .blue : .green)
                }
                
                // Title - medium weight
                Text(listing.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func listingImagesCarousel() -> some View {
        let urls: [String] = !listing.photos.isEmpty ? listing.photos : (listing.photo != nil ? [listing.photo!] : [])
        
        GeometryReader { geometry in
            let size = geometry.size.width
            
            if urls.isEmpty {
                // No photo placeholder - square with gradient
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("ThemeColor").opacity(0.15),
                                Color("ThemeColor").opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(Color("ThemeColor").opacity(0.6))
                            Text("No photo")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                // WANTED badge (bottom-left)
                                if AppConfig.enableSeekMode && listing.intent == .seek {
                                    Text("WANTED")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .cornerRadius(6)
                                        .padding(6)
                                }
                                Spacer()
                            }
                        }
                    )
                    .frame(width: size, height: size)
            } else if urls.count == 1 {
                // Single image - square (with caching)
                CachedAsyncImage(url: urls[0]) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                        .overlay(
                            VStack {
                                Spacer()
                                HStack {
                                    // WANTED badge (bottom-left)
                                    if AppConfig.enableSeekMode && listing.intent == .seek {
                                        Text("WANTED")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .cornerRadius(6)
                                            .padding(6)
                                    }
                                    Spacer()
                                }
                            }
                        )
                } placeholder: {
                    Rectangle()
                        .fill(Color(UIColor.systemGray6))
                        .frame(width: size, height: size)
                        .overlay(ProgressView())
                }
            } else {
                // Multiple images - show first with indicator (with caching)
                CachedAsyncImage(url: urls[0]) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                        .overlay(
                            VStack {
                                HStack {
                                    // Quantity badge (top-left)
                                    if let qty = listing.quantityAvailable, qty > 1 {
                                        Text("\(qty) left")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.7))
                                            .cornerRadius(8)
                                            .padding(6)
                                    }
                                    Spacer()
                                    // Image counter (top-right)
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
                                // WANTED badge (bottom-left)
                                if AppConfig.enableSeekMode && listing.intent == .seek {
                                    HStack {
                                        Text("WANTED")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange)
                                            .cornerRadius(6)
                                            .padding(6)
                                        Spacer()
                                    }
                                }
                            }
                        )
                } placeholder: {
                    Rectangle()
                        .fill(Color(UIColor.systemGray6))
                        .frame(width: size, height: size)
                        .overlay(ProgressView())
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
        
        // If query is empty, clear search and show normal listings
        if !query.isActive {
            isSearchActive = false
            searchResults = []
            return
        }
        
        // Create new search work item with debouncing
        let currentQuery = query
        let workItem = DispatchWorkItem {
            Task { @MainActor in
                // Only trigger search if query is active (has text or filters)
                if currentQuery.isActive {
                    await performSearchInternal(currentQuery)
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
        
        // Perform search internally instead of showing sheet
        Task {
            await performSearchInternal(query)
        }
    }
    
    private func performSearchInternal(_ query: SearchQuery) async {
        guard AppConfig.enableSearch else { return }
        
        await MainActor.run {
            isLoading = true
            isSearchActive = true
        }
        
        do {
            let results = try await SearchService.shared.searchListings(
                query: query,
                limit: 20,
                offset: 0
            )
            
            // Convert SearchListing to ListingWithUser
            let listingsWithUser = results.listings.map { $0.toListingWithUser() }
            
            await MainActor.run {
                searchResults = listingsWithUser
                isLoading = false
            }
            
            // Save search query for analytics (Phase 3)
            await SearchService.shared.saveRecentSearch(query, resultCount: results.totalCount)
        } catch {
            print("❌ Search error: \(error)")
            await MainActor.run {
                searchResults = []
                isLoading = false
            }
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
