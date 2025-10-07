//
//  SearchModelsTests.swift
//  CampusLinkTests
//
//  Created on October 7, 2025.
//

import XCTest
@testable import CampusLink

final class SearchModelsTests: XCTestCase {
    
    // MARK: - SearchQuery Tests
    
    func testSearchQueryInitialization() {
        let query = SearchQuery()
        
        XCTAssertEqual(query.text, "")
        XCTAssertEqual(query.sortBy, .relevance)
        XCTAssertFalse(query.isActive)
    }
    
    func testSearchQueryIsActive() {
        var query = SearchQuery()
        
        // Empty query is not active
        XCTAssertFalse(query.isActive)
        
        // Query with text is active
        query.text = "iPhone"
        XCTAssertTrue(query.isActive)
        
        // Query with filters but no text is still active
        query.text = ""
        query.filters.category = "Electronics"
        XCTAssertTrue(query.isActive)
    }
    
    // MARK: - SearchFilters Tests
    
    func testSearchFiltersInitialization() {
        let filters = SearchFilters()
        
        XCTAssertNil(filters.category)
        XCTAssertNil(filters.intent)
        XCTAssertNil(filters.priceRange)
        XCTAssertNil(filters.location)
        XCTAssertNil(filters.listingType)
        XCTAssertNil(filters.minTrustScore)
        XCTAssertFalse(filters.hasActiveFilters)
        XCTAssertEqual(filters.activeFilterCount, 0)
    }
    
    func testSearchFiltersHasActiveFilters() {
        var filters = SearchFilters()
        
        // No filters active
        XCTAssertFalse(filters.hasActiveFilters)
        XCTAssertEqual(filters.activeFilterCount, 0)
        
        // One filter active
        filters.category = "Books"
        XCTAssertTrue(filters.hasActiveFilters)
        XCTAssertEqual(filters.activeFilterCount, 1)
        
        // Multiple filters active
        filters.intent = .seek
        filters.priceRange = PriceRange(min: 10, max: 50)
        filters.minTrustScore = 80
        XCTAssertTrue(filters.hasActiveFilters)
        XCTAssertEqual(filters.activeFilterCount, 4)
    }
    
    // MARK: - PriceRange Tests
    
    func testPriceRangeValidation() {
        // Valid range
        let validRange = PriceRange(min: 10, max: 100)
        XCTAssertTrue(validRange.isValid)
        
        // Valid with nil max
        let openEndRange = PriceRange(min: 50, max: nil)
        XCTAssertTrue(openEndRange.isValid)
        
        // Valid with nil min
        let openStartRange = PriceRange(min: nil, max: 100)
        XCTAssertTrue(openStartRange.isValid)
        
        // Invalid - min > max
        let invalidRange = PriceRange(min: 100, max: 50)
        XCTAssertFalse(invalidRange.isValid)
        
        // Invalid - negative min
        let negativeMin = PriceRange(min: -10, max: 50)
        XCTAssertFalse(negativeMin.isValid)
        
        // Valid - both nil
        let emptyRange = PriceRange(min: nil, max: nil)
        XCTAssertTrue(emptyRange.isValid)
    }
    
    // MARK: - SortOption Tests
    
    func testSortOptionRawValues() {
        XCTAssertEqual(SortOption.relevance.rawValue, "relevance")
        XCTAssertEqual(SortOption.priceLow.rawValue, "price_low")
        XCTAssertEqual(SortOption.priceHigh.rawValue, "price_high")
        XCTAssertEqual(SortOption.newest.rawValue, "newest")
        XCTAssertEqual(SortOption.trustScore.rawValue, "trust_score")
    }
    
    func testSortOptionDisplayNames() {
        XCTAssertEqual(SortOption.relevance.displayName, "Relevance")
        XCTAssertEqual(SortOption.priceLow.displayName, "Price: Low to High")
        XCTAssertEqual(SortOption.priceHigh.displayName, "Price: High to Low")
        XCTAssertEqual(SortOption.newest.displayName, "Newest First")
        XCTAssertEqual(SortOption.trustScore.displayName, "Highest Rated")
    }
    
    func testSortOptionIcons() {
        XCTAssertEqual(SortOption.relevance.icon, "star.fill")
        XCTAssertEqual(SortOption.priceLow.icon, "arrow.up.circle")
        XCTAssertEqual(SortOption.priceHigh.icon, "arrow.down.circle")
        XCTAssertEqual(SortOption.newest.icon, "clock.fill")
        XCTAssertEqual(SortOption.trustScore.icon, "shield.checkered")
    }
    
    // MARK: - SearchSuggestion Tests
    
    func testSearchSuggestionInitialization() {
        let suggestion = SearchSuggestion(
            text: "iPhone 13",
            category: "Electronics",
            count: 15,
            type: .trending
        )
        
        XCTAssertEqual(suggestion.text, "iPhone 13")
        XCTAssertEqual(suggestion.category, "Electronics")
        XCTAssertEqual(suggestion.count, 15)
        XCTAssertEqual(suggestion.type, .trending)
        XCTAssertNotNil(suggestion.id)
    }
    
    func testSearchSuggestionTypes() {
        XCTAssertEqual(SearchSuggestion.SuggestionType.recent.rawValue, "recent")
        XCTAssertEqual(SearchSuggestion.SuggestionType.suggestion.rawValue, "suggestion")
        XCTAssertEqual(SearchSuggestion.SuggestionType.trending.rawValue, "trending")
        XCTAssertEqual(SearchSuggestion.SuggestionType.category.rawValue, "category")
    }
    
    // MARK: - SearchResult Tests
    
    func testSearchResultInitialization() {
        let listings: [SearchListing] = []
        let searchRank: [UUID: Float] = [:]
        let suggestions: [SearchSuggestion] = []
        
        let result = SearchResult(
            listings: listings,
            totalCount: 0,
            searchRank: searchRank,
            suggestions: suggestions,
            hasMore: false
        )
        
        XCTAssertEqual(result.listings.count, 0)
        XCTAssertEqual(result.totalCount, 0)
        XCTAssertEqual(result.searchRank.count, 0)
        XCTAssertEqual(result.suggestions.count, 0)
        XCTAssertFalse(result.hasMore)
    }
    
    // MARK: - RecentSearch Tests
    
    func testRecentSearchInitialization() {
        let query = SearchQuery()
        let timestamp = Date()
        
        let recentSearch = RecentSearch(
            query: query,
            timestamp: timestamp,
            resultCount: 25
        )
        
        XCTAssertNotNil(recentSearch.id)
        XCTAssertEqual(recentSearch.resultCount, 25)
        XCTAssertEqual(recentSearch.timestamp, timestamp)
    }
    
    // MARK: - SearchListing Tests
    
    func testSearchListingInitialization() {
        let listing = SearchListing(
            id: UUID(),
            user_id: UUID(),
            title: "Test Product",
            description: "Test Description",
            price: 50.0,
            category: "Electronics",
            condition: "new",
            images: ["image1.jpg", "image2.jpg"],
            intent: "offer",
            status: "active",
            archived: false,
            service_location: "on_campus",
            created_at: Date(),
            relevance_score: 0.95,
            user_name: "John Doe",
            user_email: "john@university.edu",
            user_avatar_url: "avatar.jpg",
            user_trust_score: 85
        )
        
        XCTAssertEqual(listing.title, "Test Product")
        XCTAssertEqual(listing.price, 50.0)
        XCTAssertEqual(listing.images?.count, 2)
        XCTAssertEqual(listing.relevance_score, 0.95)
        XCTAssertEqual(listing.user_trust_score, 85)
    }
    
    func testSearchListingToListingWithUser() {
        let userId = UUID()
        let listingId = UUID()
        let createdDate = Date()
        
        let searchListing = SearchListing(
            id: listingId,
            user_id: userId,
            title: "MacBook Pro",
            description: "2021 M1 MacBook Pro",
            price: 1200.0,
            category: "Electronics",
            condition: "used",
            images: ["macbook1.jpg", "macbook2.jpg"],
            intent: "offer",
            status: "active",
            archived: false,
            service_location: nil,
            created_at: createdDate,
            relevance_score: 0.89,
            user_name: "Jane Smith",
            user_email: "jane@university.edu",
            user_avatar_url: "jane.jpg",
            user_trust_score: 92
        )
        
        let listingWithUser = searchListing.toListingWithUser()
        
        // Test listing properties
        XCTAssertEqual(listingWithUser.id, listingId)
        XCTAssertEqual(listingWithUser.title, "MacBook Pro")
        XCTAssertEqual(listingWithUser.description, "2021 M1 MacBook Pro")
        XCTAssertEqual(listingWithUser.price, 1200.0)
        XCTAssertEqual(listingWithUser.category, "Electronics")
        XCTAssertEqual(listingWithUser.photo, "macbook1.jpg")
        XCTAssertEqual(listingWithUser.photos, ["macbook1.jpg", "macbook2.jpg"])
        XCTAssertEqual(listingWithUser.intent, .offer)
        XCTAssertFalse(listingWithUser.isSold)
        XCTAssertFalse(listingWithUser.archived ?? false)
        XCTAssertEqual(listingWithUser.createdAt, createdDate)
        
        // Test user properties
        XCTAssertEqual(listingWithUser.user.id, userId.uuidString)
        XCTAssertEqual(listingWithUser.user.name, "Jane Smith")
        XCTAssertEqual(listingWithUser.user.email, "jane@university.edu")
        XCTAssertEqual(listingWithUser.user.profilePic, "jane.jpg")
        XCTAssertEqual(listingWithUser.user.trustScore, 92)
        XCTAssertTrue(listingWithUser.user.campusEmailVerified ?? false)
    }
    
    func testSearchListingToListingWithUserDefaults() {
        // Test with minimal data
        let searchListing = SearchListing(
            id: UUID(),
            user_id: UUID(),
            title: "Simple Item",
            description: nil,
            price: nil,
            category: nil,
            condition: nil,
            images: nil,
            intent: "invalid", // Test invalid intent
            status: "active",
            archived: true,
            service_location: "remote",
            created_at: Date(),
            relevance_score: 0.5,
            user_name: nil,
            user_email: nil,
            user_avatar_url: nil,
            user_trust_score: nil
        )
        
        let listingWithUser = searchListing.toListingWithUser()
        
        // Test default values
        XCTAssertEqual(listingWithUser.description, "")
        XCTAssertEqual(listingWithUser.price, 0)
        XCTAssertEqual(listingWithUser.category, "")
        XCTAssertNil(listingWithUser.photo)
        XCTAssertTrue(listingWithUser.photos.isEmpty)
        XCTAssertEqual(listingWithUser.intent, .offer) // Default for invalid intent
        XCTAssertEqual(listingWithUser.listingType, .product) // Default type
        XCTAssertEqual(listingWithUser.serviceLocation, .remote)
        XCTAssertTrue(listingWithUser.archived ?? false)
        
        // Test user defaults
        XCTAssertNil(listingWithUser.user.name)
        XCTAssertNil(listingWithUser.user.email)
        XCTAssertNil(listingWithUser.user.profilePic)
        XCTAssertNil(listingWithUser.user.trustScore)
    }
    
    // MARK: - Codable Tests
    
    func testSearchQueryCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        var original = SearchQuery()
        original.text = "textbook"
        original.filters.category = "Books"
        original.filters.priceRange = PriceRange(min: 20, max: 100)
        original.sortBy = .priceLow
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SearchQuery.self, from: data)
        
        XCTAssertEqual(original.text, decoded.text)
        XCTAssertEqual(original.filters.category, decoded.filters.category)
        XCTAssertEqual(original.filters.priceRange?.min, decoded.filters.priceRange?.min)
        XCTAssertEqual(original.filters.priceRange?.max, decoded.filters.priceRange?.max)
        XCTAssertEqual(original.sortBy, decoded.sortBy)
    }
}
