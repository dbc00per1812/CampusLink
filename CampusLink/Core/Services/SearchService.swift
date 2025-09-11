import Foundation
import Supabase

// MARK: - Search Service

final class SearchService: ObservableObject {
    static let shared = SearchService()
    private let preferencesManager = SearchPreferencesManager.shared
    private init() {}
    
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
            let params = buildSearchParameters(from: query, limit: limit, offset: offset)
            
            // Call the search_listings PostgreSQL function
            let searchResponse: [SearchListingRow] = try await supabase
                .rpc("search_listings", params: params)
                .execute()
                .value
            
            // Parse the response
            var listings: [SearchListing] = []
            var searchRank: [UUID: Float] = [:]
            
            for row in searchResponse {
                if let listingData = row.listing_data {
                    listings.append(listingData)
                    searchRank[listingData.id] = row.search_rank
                }
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
            // Call the get_search_suggestions PostgreSQL function
            struct SuggestionParams: Encodable {
                let partial_term: String
                let max_suggestions: Int
            }
            let suggestionRows: [SearchSuggestionRow] = try await supabase
                .rpc(
                    "get_search_suggestions",
                    params: SuggestionParams(partial_term: partialText, max_suggestions: maxSuggestions)
                )
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
    
    // MARK: - Helper Methods
    
    /// Build search query parameters for database call
    private func buildSearchParameters(from query: SearchQuery, limit: Int, offset: Int) -> RpcSearchParams {
        let filters = query.filters
        return RpcSearchParams(
            search_term: query.text,
            category_filter: filters.category,
            intent_filter: filters.intent?.rawValue,
            min_price: filters.priceRange?.min,
            max_price: filters.priceRange?.max,
            location_filter: filters.location?.rawValue,
            listing_type_filter: filters.listingType?.rawValue,
            trust_score_min: filters.minTrustScore,
            sort_by: query.sortBy.rawValue,
            limit_count: limit,
            offset_count: offset
        )
    }

    // Encodable RPC parameter payload matching SQL function signature
    private struct RpcSearchParams: Encodable {
        let search_term: String
        let category_filter: String?
        let intent_filter: String?
        let min_price: Double?
        let max_price: Double?
        let location_filter: String?
        let listing_type_filter: String?
        let trust_score_min: Int?
        let sort_by: String
        let limit_count: Int
        let offset_count: Int
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) -> SearchServiceError {
        if error is SearchServiceError {
            return error as! SearchServiceError
        }
        
        #if DEBUG
        print("SearchService Error: \(error)")
        #endif
        
        return .networkError
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
            return "Database error occurred"
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
            return "Please try again in a moment"
        }
    }
}
