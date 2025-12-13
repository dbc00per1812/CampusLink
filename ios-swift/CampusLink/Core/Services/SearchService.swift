import Foundation
import Supabase

// MARK: - Search Service

final class SearchService: ObservableObject {
    static let shared = SearchService()
    private let preferencesManager = SearchPreferencesManager.shared
    private init() {}
    
    // MARK: - Campus Filtering Helpers
    
    /// Apply campus filtering to search listings
    private func applyCampusFilter(_ listings: [SearchListing]) async -> [SearchListing] {
        guard AppConfig.enableCampusFilter else {
            print("🔍 Search Campus Filter: DISABLED in AppConfig")
            return listings
        }
        
        print("🔍 Search Campus Filter: ENABLED, filtering \(listings.count) results...")
        
        // Get current user's campus from their profile
        guard let session = try? await supabase.auth.session else {
            print("🔍 Search Campus Filter: Could not get current user's ID")
            return listings // Return all listings if we can't determine user
        }
        
        let currentUserId = session.user.id.uuidString
        
        // Fetch current user's campus
        do {
            struct UserCampus: Codable {
                let id: String
                let campus: String?
            }
            
            let currentUser: UserCampus = try await supabase
                .from("users")
                .select("id, campus")
                .eq("id", value: currentUserId)
                .single()
                .execute()
                .value
            
            guard let currentCampus = currentUser.campus, !currentCampus.isEmpty else {
                print("🔍 Search Campus Filter: Current user has no campus set")
                return listings // Return all listings if user has no campus
            }
            
            print("🔍 Search Campus Filter: Current user campus: \(currentCampus)")
            
            // Filter listings to only show those from users with the same campus
            let filteredListings = listings.filter { listing in
                guard let userCampus = listing.user_campus, !userCampus.isEmpty else {
                    return false // Exclude listings from users without campus
                }
                return userCampus == currentCampus
            }
            
            print("🔍 Search Campus Filter: Filtered \(listings.count) search results to \(filteredListings.count) for campus \(currentCampus)")
            
            return filteredListings
        } catch {
            print("❌ Search Campus Filter: Error fetching user campus: \(error)")
            return listings // Return unfiltered if error
        }
    }
    
    /// Apply blocked users filtering to search listings
    private func applyBlockedUsersFilter(_ listings: [SearchListing]) async -> [SearchListing] {
        // Get current user's ID
        guard let session = try? await supabase.auth.session else {
            #if DEBUG
            print("🔍 Search Blocked Users Filter: No authenticated user, skipping filter")
            #endif
            return listings
        }
        
        let currentUserId = session.user.id.uuidString
        
        do {
            let blockedIds = try await BlockedUsersService.getBlockedUserIds(currentUserId: currentUserId)
            
            guard !blockedIds.isEmpty else {
                #if DEBUG
                print("🔍 Search Blocked Users Filter: No blocked users")
                #endif
                return listings
            }
            
            // Filter out listings from blocked users
            let filteredListings = listings.filter { listing in
                !blockedIds.contains(listing.user_id.uuidString)
            }
            
            #if DEBUG
            print("🔍 Search Blocked Users Filter: Filtered \(listings.count) listings to \(filteredListings.count) (removed \(listings.count - filteredListings.count) from blocked users)")
            #endif
            
            return filteredListings
        } catch {
            #if DEBUG
            print("❌ Search Blocked Users Filter: Error fetching blocked users: \(error)")
            #endif
            return listings // Return unfiltered on error
        }
    }
    
    // MARK: - Search Operations
    
    /// Perform text search on listings
    func searchListings(query: SearchQuery, limit: Int = 20, offset: Int = 0) async throws -> SearchResult {
        guard AppConfig.enableSearch else {
            throw SearchServiceError.featureDisabled
        }
        
        do {
            // Validate filters
            guard validateFilters(query.filters) else {
                throw SearchServiceError.invalidFilters
            }
            
            // Build parameters for the PostgreSQL function
            let filters = query.filters
            
            // Create parameter struct
            struct SearchParams: Encodable {
                let query_text: String?
                let category_filter: String?
                let min_price: Double?
                let max_price: Double?
                let intent_filter: String?
                let service_location_filter: String?
                let trust_min: Int?
                let trust_max: Int?
                let sort_by: String
                let limit_count: Int
                let offset_count: Int
            }
            
            let trimmedQuery = query.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let params = SearchParams(
                query_text: trimmedQuery.isEmpty ? nil : trimmedQuery,
                category_filter: filters.category,
                min_price: filters.priceRange?.min,
                max_price: filters.priceRange?.max,
                intent_filter: filters.intent?.rawValue,
                service_location_filter: filters.location?.rawValue,
                trust_min: filters.minTrustScore,
                trust_max: nil,
                sort_by: query.sortBy.rawValue,
                limit_count: limit,
                offset_count: offset
            )
            
            // Call the search function (hybrid or keyword-only based on feature flag)
            let rpcName = AppConfig.enableHybridSearch ? "hybrid_search_listings" : "search_listings"
            let searchResponse: [SearchListing] = try await supabase
                .rpc(rpcName, params: params)
                .execute()
                .value
            
            #if DEBUG
            print("📱 SearchService: Received \(searchResponse.count) results from database")
            if let first = searchResponse.first {
                print("📱 SearchService: First result title: \(first.title)")
                print("📱 SearchService: First result ID: \(first.id)")
                print("📱 SearchService: First result photo: \(first.photo ?? "nil")")
                print("📱 SearchService: First result photos: \(first.photos?.count ?? 0) photos")
                print("📱 SearchService: First result images: \(first.images?.count ?? 0) images")
            }
            #endif
            
            #if DEBUG
            print("📱 SearchService: Before campus filter: \(searchResponse.count) results")
            #endif
            
            // Apply campus filtering to search results
            var filteredListings = await applyCampusFilter(searchResponse)
            
            #if DEBUG
            print("📱 SearchService: After campus filter: \(filteredListings.count) results")
            #endif
            
            // Apply blocked users filtering
            filteredListings = await applyBlockedUsersFilter(filteredListings)
            
            #if DEBUG
            print("📱 SearchService: After blocked users filter: \(filteredListings.count) results")
            #endif
            
            // Parse the response
            let listings = filteredListings
            var searchRank: [UUID: Float] = [:]
            
            for listing in listings {
                searchRank[listing.id] = listing.relevance_score
            }
            
            // Calculate if there are more results
            let hasMore = listings.count == limit
            
            // Get search suggestions if query has text
            let suggestions = query.text.isEmpty ? [] : try await getSearchSuggestions(partialText: query.text)
            
            let result = SearchResult(
                listings: listings,
                totalCount: listings.count, // Note: actual totalCount would require separate query
                searchRank: searchRank,
                suggestions: suggestions,
                hasMore: hasMore
            )
            
            // Save search to recent searches and update result count
            if !query.text.isEmpty {
                preferencesManager.saveRecentSearch(query)
                preferencesManager.updateRecentSearchResultCount(query.text, resultCount: listings.count)
            }
            
            // Save search history for analytics
            preferencesManager.saveSearchHistory(query, resultCount: listings.count)
            
            return result
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Get search suggestions based on partial text
    func getSearchSuggestions(partialText: String, maxSuggestions: Int = 10) async throws -> [SearchSuggestion] {
        guard AppConfig.enableSearch else {
            throw SearchServiceError.featureDisabled
        }
        
        guard !partialText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        do {
            // Create parameter struct
            struct SuggestionParams: Encodable {
                let query_text: String
                let limit_count: Int
            }
            
            let params = SuggestionParams(
                query_text: partialText,
                limit_count: maxSuggestions
            )
            
            // Call the get_search_suggestions PostgreSQL function
            let suggestionRows: [SearchSuggestionRow] = try await supabase
                .rpc("get_search_suggestions", params: params)
                .execute()
                .value
            
            // Convert to SearchSuggestion objects
            return suggestionRows.map { row in
                SearchSuggestion(
                    text: row.suggestion,
                    category: row.category,
                    count: Int(row.count),
                    type: .suggestion
                )
            }
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Get popular search terms and trending categories
    func getTrendingSearches(limit: Int = 10) async throws -> [SearchSuggestion] {
        guard AppConfig.enableSearch else {
            throw SearchServiceError.featureDisabled
        }
        
        do {
            // For Phase 1, get popular categories from recent listings
            struct CategoryRow: Decodable { let category: String? }
            let rows: [CategoryRow] = try await supabase
                .from("listings")
                .select("category")
                .eq("status", value: "active")
                .eq("archived", value: false)
                .neq("category", value: "null")
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            
            // Count category occurrences
            var categoryCount: [String: Int] = [:]
            for row in rows {
                if let category = row.category, !category.isEmpty {
                    categoryCount[category, default: 0] += 1
                }
            }
            
            // Convert to SearchSuggestion objects, sorted by popularity
            return categoryCount
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { (category, count) in
                    SearchSuggestion(
                        text: category,
                        category: category,
                        count: count,
                        type: .trending
                    )
                }
            
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Search History
    
    /// Save a search query to recent searches
    func saveRecentSearch(_ query: SearchQuery, resultCount: Int) async {
        guard AppConfig.enableSearch else { return }
        
        preferencesManager.saveRecentSearch(query)
        preferencesManager.updateRecentSearchResultCount(query.text, resultCount: resultCount)
    }
    
    /// Get recent search history
    func getRecentSearches(limit: Int = 10) async -> [RecentSearch] {
        guard AppConfig.enableSearch else { return [] }
        
        let recentSearches = preferencesManager.loadRecentSearches()
        return Array(recentSearches.prefix(limit))
    }
    
    /// Clear search history
    func clearSearchHistory() async {
        guard AppConfig.enableSearch else { return }
        
        preferencesManager.clearRecentSearches()
    }
    
    // MARK: - Search Preferences
    
    /// Load saved search filters
    func loadSavedFilters() -> SearchFilters? {
        guard AppConfig.enableSearch else { return nil }
        return preferencesManager.loadSavedFilters()
    }
    
    /// Save search filters for future sessions
    func saveFilters(_ filters: SearchFilters) {
        guard AppConfig.enableSearch else { return }
        preferencesManager.saveFilters(filters)
    }
    
    /// Load default sort option
    func loadDefaultSortOption() -> SortOption {
        guard AppConfig.enableSearch else { return .relevance }
        return preferencesManager.loadDefaultSortOption()
    }
    
    /// Save default sort option
    func saveDefaultSortOption(_ sortOption: SortOption) {
        guard AppConfig.enableSearch else { return }
        preferencesManager.saveDefaultSortOption(sortOption)
    }
    
    /// Get popular search terms
    func getPopularSearchTerms(limit: Int = 10) -> [String] {
        guard AppConfig.enableSearch else { return [] }
        return preferencesManager.getPopularSearchTerms(limit: limit)
    }
    
    // MARK: - Filter Validation
    
    /// Validate search filters for consistency
    func validateFilters(_ filters: SearchFilters) -> Bool {
        // Validate price range
        if let priceRange = filters.priceRange, !priceRange.isValid {
            return false
        }
        
        // Validate trust score range
        if let minTrustScore = filters.minTrustScore {
            guard minTrustScore >= 0 && minTrustScore <= 100 else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) -> SearchServiceError {
        if error is SearchServiceError {
            return error as! SearchServiceError
        }
        
        #if DEBUG
        print("SearchService Error: \(error)")
        print("Error type: \(type(of: error))")
        print("Error description: \(error.localizedDescription)")
        #endif
        
        // Check for common Supabase/PostgreSQL errors
        let errorMessage = error.localizedDescription.lowercased()
        
        if errorMessage.contains("function") && errorMessage.contains("does not exist") {
            return .databaseError
        }
        
        if errorMessage.contains("network") || errorMessage.contains("connection") {
            return .networkError
        }
        
        // In production, avoid alarming users; treat unknown errors as network issues
        #if DEBUG
        return .databaseError
        #else
        return .networkError
        #endif
    }
}

// MARK: - Search Service Errors

enum SearchServiceError: Error, LocalizedError {
    case featureDisabled
    case invalidQuery
    case invalidFilters
    case searchTimeout
    case networkError
    case databaseError
    
    var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "Search feature is currently disabled"
        case .invalidQuery:
            return "Invalid search query"
        case .invalidFilters:
            return "Invalid search filters"
        case .searchTimeout:
            return "Search request timed out"
        case .networkError:
            return "Network connection error"
        case .databaseError:
            return "Search functions not found. Please run the database setup script."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .featureDisabled:
            return "Please check back later when search is enabled"
        case .invalidQuery:
            return "Please enter a valid search term"
        case .invalidFilters:
            return "Please check your filter settings and try again"
        case .searchTimeout:
            return "Please try a simpler search or check your connection"
        case .networkError:
            return "Please check your internet connection and try again"
        case .databaseError:
            return "Run create_search_functions.sql in Supabase SQL editor"
        }
    }
}
