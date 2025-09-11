import Foundation

// MARK: - Search Preferences Manager

final class SearchPreferencesManager: ObservableObject {
    static let shared = SearchPreferencesManager()
    
    private let userDefaults = UserDefaults.standard
    
    // UserDefaults Keys
    private enum Keys {
        static let savedFilters = "search_saved_filters"
        static let defaultSortOption = "search_default_sort"
        static let recentSearches = "search_recent_searches"
        static let searchHistory = "search_history"
        static let maxRecentSearches = 20
        static let maxSearchHistory = 50
    }
    
    private init() {}
    
    // MARK: - Filter Persistence
    
    /// Save search filters for future sessions
    func saveFilters(_ filters: SearchFilters) {
        guard filters.hasActiveFilters else {
            clearSavedFilters()
            return
        }
        
        do {
            let data = try JSONEncoder().encode(filters)
            userDefaults.set(data, forKey: Keys.savedFilters)
        } catch {
            #if DEBUG
            print("SearchPreferencesManager: Failed to save filters - \(error)")
            #endif
        }
    }
    
    /// Load saved search filters
    func loadSavedFilters() -> SearchFilters? {
        guard let data = userDefaults.data(forKey: Keys.savedFilters) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(SearchFilters.self, from: data)
        } catch {
            #if DEBUG
            print("SearchPreferencesManager: Failed to load filters - \(error)")
            #endif
            clearSavedFilters() // Clear corrupted data
            return nil
        }
    }
    
    /// Clear saved filters
    func clearSavedFilters() {
        userDefaults.removeObject(forKey: Keys.savedFilters)
    }
    
    // MARK: - Sort Option Persistence
    
    /// Save default sort option
    func saveDefaultSortOption(_ sortOption: SortOption) {
        userDefaults.set(sortOption.rawValue, forKey: Keys.defaultSortOption)
    }
    
    /// Load default sort option
    func loadDefaultSortOption() -> SortOption {
        let savedSort = userDefaults.string(forKey: Keys.defaultSortOption)
        return SortOption(rawValue: savedSort ?? "") ?? .relevance
    }
    
    /// Clear default sort option (revert to relevance)
    func clearDefaultSortOption() {
        userDefaults.removeObject(forKey: Keys.defaultSortOption)
    }
    
    // MARK: - Recent Searches
    
    /// Save a search query to recent searches
    func saveRecentSearch(_ query: SearchQuery) {
        // Only save if there's actual search text
        guard !query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        var recentSearches = loadRecentSearches()
        
        // Remove existing search with same text to avoid duplicates
        recentSearches.removeAll { $0.query.text.lowercased() == query.text.lowercased() }
        
        // Add new search at the beginning
        let recentSearch = RecentSearch(
            query: query,
            timestamp: Date(),
            resultCount: 0 // Will be updated after search completes
        )
        recentSearches.insert(recentSearch, at: 0)
        
        // Limit to max recent searches
        if recentSearches.count > Keys.maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(Keys.maxRecentSearches))
        }
        
        saveRecentSearches(recentSearches)
    }
    
    /// Update result count for a recent search
    func updateRecentSearchResultCount(_ searchText: String, resultCount: Int) {
        var recentSearches = loadRecentSearches()
        
        if let index = recentSearches.firstIndex(where: { 
            $0.query.text.lowercased() == searchText.lowercased() 
        }) {
            var updatedSearch = recentSearches[index]
            updatedSearch = RecentSearch(
                query: updatedSearch.query,
                timestamp: updatedSearch.timestamp,
                resultCount: resultCount
            )
            recentSearches[index] = updatedSearch
            saveRecentSearches(recentSearches)
        }
    }
    
    /// Load recent searches
    func loadRecentSearches() -> [RecentSearch] {
        guard let data = userDefaults.data(forKey: Keys.recentSearches) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([RecentSearch].self, from: data)
        } catch {
            #if DEBUG
            print("SearchPreferencesManager: Failed to load recent searches - \(error)")
            #endif
            clearRecentSearches() // Clear corrupted data
            return []
        }
    }
    
    /// Clear all recent searches
    func clearRecentSearches() {
        userDefaults.removeObject(forKey: Keys.recentSearches)
    }
    
    /// Remove a specific recent search
    func removeRecentSearch(withId id: UUID) {
        var recentSearches = loadRecentSearches()
        recentSearches.removeAll { $0.id == id }
        saveRecentSearches(recentSearches)
    }
    
    private func saveRecentSearches(_ searches: [RecentSearch]) {
        do {
            let data = try JSONEncoder().encode(searches)
            userDefaults.set(data, forKey: Keys.recentSearches)
        } catch {
            #if DEBUG
            print("SearchPreferencesManager: Failed to save recent searches - \(error)")
            #endif
        }
    }
    
    // MARK: - Search History Analytics
    
    /// Save detailed search history for analytics (optional)
    func saveSearchHistory(_ query: SearchQuery, resultCount: Int, selectedListing: UUID? = nil) {
        guard AppConfig.enableSearch else { return }
        
        var history = loadSearchHistory()
        
        let historyEntry = SearchHistoryEntry(
            query: query,
            timestamp: Date(),
            resultCount: resultCount,
            selectedListingId: selectedListing
        )
        
        history.append(historyEntry)
        
        // Limit history size
        if history.count > Keys.maxSearchHistory {
            history = Array(history.suffix(Keys.maxSearchHistory))
        }
        
        saveSearchHistory(history)
    }
    
    /// Load search history
    func loadSearchHistory() -> [SearchHistoryEntry] {
        guard let data = userDefaults.data(forKey: Keys.searchHistory) else {
            return []
        }
        
        do {
            return try JSONDecoder().decode([SearchHistoryEntry].self, from: data)
        } catch {
            #if DEBUG
            print("SearchPreferencesManager: Failed to load search history - \(error)")
            #endif
            clearSearchHistory()
            return []
        }
    }
    
    /// Clear search history
    func clearSearchHistory() {
        userDefaults.removeObject(forKey: Keys.searchHistory)
    }
    
    private func saveSearchHistory(_ history: [SearchHistoryEntry]) {
        do {
            let data = try JSONEncoder().encode(history)
            userDefaults.set(data, forKey: Keys.searchHistory)
        } catch {
            #if DEBUG
            print("SearchPreferencesManager: Failed to save search history - \(error)")
            #endif
        }
    }
    
    // MARK: - Popular Search Terms
    
    /// Get popular search terms from history
    func getPopularSearchTerms(limit: Int = 10) -> [String] {
        let history = loadSearchHistory()
        let recentSearches = loadRecentSearches()
        
        // Combine all search terms
        var termCounts: [String: Int] = [:]
        
        // Count from history (weighted more recently)
        for entry in history.suffix(Keys.maxSearchHistory / 2) {
            let term = entry.query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !term.isEmpty {
                termCounts[term, default: 0] += 1
            }
        }
        
        // Count from recent searches (higher weight)
        for search in recentSearches.prefix(10) {
            let term = search.query.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !term.isEmpty {
                termCounts[term, default: 0] += 2 // Higher weight for recent
            }
        }
        
        // Return top terms
        return termCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key.capitalized }
    }
    
    // MARK: - Reset All Preferences
    
    /// Clear all search preferences and data
    func resetAllPreferences() {
        clearSavedFilters()
        clearDefaultSortOption()
        clearRecentSearches()
        clearSearchHistory()
    }
}

// MARK: - Search History Entry

struct SearchHistoryEntry: Codable, Identifiable {
    let id = UUID()
    let query: SearchQuery
    let timestamp: Date
    let resultCount: Int
    let selectedListingId: UUID?
}

// MARK: - UserDefaults Extensions

extension UserDefaults {
    /// Check if search preferences exist
    var hasSearchPreferences: Bool {
        return data(forKey: "search_saved_filters") != nil ||
               string(forKey: "search_default_sort") != nil ||
               data(forKey: "search_recent_searches") != nil
    }
}
