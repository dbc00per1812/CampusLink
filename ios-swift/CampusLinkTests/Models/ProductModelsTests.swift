//
//  ProductModelsTests.swift
//  CampusLinkTests
//
//  Created on October 7, 2025.
//

import XCTest
@testable import CampusLink

final class ProductModelsTests: XCTestCase {
    
    // MARK: - ListingType Tests
    
    func testListingTypeRawValues() {
        XCTAssertEqual(ListingType.product.rawValue, "product")
        XCTAssertEqual(ListingType.service.rawValue, "service")
    }
    
    func testListingTypeDisplayNames() {
        XCTAssertEqual(ListingType.product.displayName, "Product")
        XCTAssertEqual(ListingType.service.displayName, "Service")
    }
    
    func testListingTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let original = ListingType.product
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(ListingType.self, from: data)
        
        XCTAssertEqual(original, decoded)
    }
    
    // MARK: - ListingIntent Tests
    
    func testListingIntentRawValues() {
        XCTAssertEqual(ListingIntent.offer.rawValue, "offer")
        XCTAssertEqual(ListingIntent.seek.rawValue, "seek")
    }
    
    func testListingIntentDisplayNames() {
        XCTAssertEqual(ListingIntent.offer.displayName, "Sell")
        XCTAssertEqual(ListingIntent.seek.displayName, "Buy")
    }
    
    // MARK: - ServiceLocation Tests
    
    func testServiceLocationRawValues() {
        XCTAssertEqual(ServiceLocation.onCampus.rawValue, "on_campus")
        XCTAssertEqual(ServiceLocation.offCampus.rawValue, "off_campus")
        XCTAssertEqual(ServiceLocation.remote.rawValue, "remote")
    }
    
    func testServiceLocationDisplayNames() {
        XCTAssertEqual(ServiceLocation.onCampus.displayName, "On Campus")
        XCTAssertEqual(ServiceLocation.offCampus.displayName, "Off Campus")
        XCTAssertEqual(ServiceLocation.remote.displayName, "Remote")
    }
    
    // MARK: - Listing Tests
    
    func testListingInitialization() {
        let listing = Listing(
            id: UUID(),
            userId: "test-user",
            title: "Test Product",
            description: "Test Description",
            price: 50.0,
            category: "Electronics",
            photo: nil,
            photos: ["photo1", "photo2"],
            isSold: false,
            listingType: .product,
            serviceDuration: nil,
            serviceLocation: nil,
            serviceAvailability: nil,
            archived: false,
            createdAt: Date(),
            intent: .offer,
            budgetMin: nil,
            budgetMax: nil,
            expiresAt: nil
        )
        
        XCTAssertEqual(listing.title, "Test Product")
        XCTAssertEqual(listing.price, 50.0)
        XCTAssertEqual(listing.photos.count, 2)
        XCTAssertFalse(listing.isSold)
    }
    
    func testListingCodable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let original = Listing.sampleListing
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Listing.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.title, decoded.title)
        XCTAssertEqual(original.userId, decoded.userId)
        XCTAssertEqual(original.listingType, decoded.listingType)
    }
    
    func testListingWithSeekFields() {
        let seekListing = Listing(
            id: UUID(),
            userId: "seeker-id",
            title: "Looking for textbook",
            description: "Need calculus textbook",
            price: nil,
            category: "Books",
            photo: nil,
            photos: [],
            isSold: false,
            listingType: .product,
            serviceDuration: nil,
            serviceLocation: nil,
            serviceAvailability: nil,
            archived: false,
            createdAt: Date(),
            intent: .seek,
            budgetMin: 20.0,
            budgetMax: 50.0,
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
        )
        
        XCTAssertEqual(seekListing.intent, .seek)
        XCTAssertNil(seekListing.price)
        XCTAssertEqual(seekListing.budgetMin, 20.0)
        XCTAssertEqual(seekListing.budgetMax, 50.0)
        XCTAssertNotNil(seekListing.expiresAt)
    }
    
    // MARK: - User Tests
    
    func testUserInitialization() {
        let user = User(
            id: "user-123",
            name: "John Doe",
            bio: "Student at University",
            profilePic: "profile.jpg",
            email: "john@university.edu",
            createdAt: Date(),
            campusEmailVerified: true,
            trustScore: 90,
            stripeConnectId: "acct_123",
            stripePayoutsEnabled: true,
            stripeDetailsSubmitted: true
        )
        
        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.name, "John Doe")
        XCTAssertEqual(user.trustScore, 90)
        XCTAssertTrue(user.campusEmailVerified ?? false)
    }
    
    func testUserCodable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let original = User.sampleUser
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(User.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.email, decoded.email)
    }
    
    // MARK: - Offer Tests
    
    func testOfferPriceComputation() {
        let offer = Offer(
            id: UUID(),
            seekListingId: UUID(),
            offerListingId: UUID(),
            seekerId: "seeker-123",
            sellerId: "seller-456",
            message: "I can provide this",
            status: "pending",
            priceCents: 2500, // $25.00
            orderId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertEqual(offer.price, 25.0)
        XCTAssertEqual(offer.formattedPrice, "$25.00")
    }
    
    func testOfferWithNilPrice() {
        let offer = Offer(
            id: UUID(),
            seekListingId: UUID(),
            offerListingId: nil,
            seekerId: "seeker-123",
            sellerId: "seller-456",
            message: "Custom offer",
            status: "pending",
            priceCents: nil,
            orderId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        XCTAssertNil(offer.price)
        XCTAssertNil(offer.formattedPrice)
    }
    
    func testOfferCodable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let original = Offer(
            id: UUID(),
            seekListingId: UUID(),
            offerListingId: UUID(),
            seekerId: "seeker-123",
            sellerId: "seller-456",
            message: "Test offer",
            status: "pending",
            priceCents: 1000,
            orderId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Offer.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.seekerId, decoded.seekerId)
        XCTAssertEqual(original.priceCents, decoded.priceCents)
        XCTAssertEqual(original.status, decoded.status)
    }
    
    // MARK: - ListingCreate Tests
    
    func testListingCreateInitialization() {
        let listingCreate = ListingCreate(
            userId: "user-123",
            title: "New Product",
            description: "Brand new item",
            price: 100.0,
            category: "Electronics",
            photo: nil,
            photos: ["photo1.jpg"],
            listingType: .product,
            serviceDuration: nil,
            serviceLocation: nil,
            serviceAvailability: nil,
            archived: false,
            intent: .offer,
            budgetMin: nil,
            budgetMax: nil,
            expiresAt: nil
        )
        
        XCTAssertEqual(listingCreate.userId, "user-123")
        XCTAssertEqual(listingCreate.title, "New Product")
        XCTAssertEqual(listingCreate.price, 100.0)
        XCTAssertEqual(listingCreate.photos.count, 1)
    }
}
