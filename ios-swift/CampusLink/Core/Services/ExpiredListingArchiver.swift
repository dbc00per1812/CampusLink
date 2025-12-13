import Foundation
import SwiftUI

/// Service to automatically archive expired listings (tickets and seek posts)
@MainActor
class ExpiredListingArchiver: ObservableObject {
    static let shared = ExpiredListingArchiver()
    
    private var archiveTimer: Timer?
    
    // Check for expired listings every 30 minutes
    private let checkInterval: TimeInterval = 1800 // 30 minutes
    
    private init() {}
    
    // MARK: - Archiving Control
    
    /// Start automatic archiving of expired listings
    func startAutoArchiving() {
        stopAutoArchiving()
        
        // Immediate check on start
        Task { @MainActor in
            await archiveExpiredListings()
        }
        
        // Schedule periodic checks - ensure it runs on main run loop
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.archiveTimer = Timer.scheduledTimer(withTimeInterval: self.checkInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    await self?.archiveExpiredListings()
                }
            }
            // Add timer to common run loop modes so it fires even during scrolling
            if let timer = self.archiveTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
            print("📦 ExpiredListingArchiver: Started auto-archiving (checks every 30 minutes)")
        }
    }
    
    /// Stop automatic archiving
    func stopAutoArchiving() {
        archiveTimer?.invalidate()
        archiveTimer = nil
        print("📦 ExpiredListingArchiver: Stopped auto-archiving")
    }
    
    // MARK: - Archive Expired Listings
    
    /// Archive all expired listings
    func archiveExpiredListings() async {
        do {
            let now = Date()
            let isoFormatter = ISO8601DateFormatter()
            let nowString = isoFormatter.string(from: now)
            
            print("📦 ExpiredListingArchiver: Checking for expired listings (current time: \(nowString))")
            
            // Find all listings with expires_at in the past that are not already archived
            // Note: .lt() automatically filters out NULL values, so we only get listings with dates
            let expiredListings: [Listing] = try await supabase
                .from("listings")
                .select("id, title, category, expires_at")
                .not("expires_at", operator: .is, value: "null")  // Explicitly exclude NULL
                .lt("expires_at", value: nowString)
                .eq("archived", value: false)
                .eq("is_sold", value: false)
                .execute()
                .value
            
            guard !expiredListings.isEmpty else {
                print("📦 ExpiredListingArchiver: No expired listings found")
                return
            }
            
            print("📦 ExpiredListingArchiver: Found \(expiredListings.count) expired listing(s)")
            
            // Archive each expired listing
            for listing in expiredListings {
                do {
                    let expiresAt = listing.expiresAt != nil ? isoFormatter.string(from: listing.expiresAt!) : "nil"
                    print("📦 Archiving: '\(listing.title)' (Category: \(listing.category), Expires: \(expiresAt))")
                    
                    try await supabase
                        .from("listings")
                        .update(["archived": true])
                        .eq("id", value: listing.id.uuidString)
                        .execute()
                    
                    print("✅ Archived expired listing: \(listing.title) (ID: \(listing.id))")
                } catch {
                    print("❌ Failed to archive listing \(listing.id): \(error)")
                }
            }
            
            print("✅ ExpiredListingArchiver: Archived \(expiredListings.count) expired listing(s)")
            
        } catch {
            print("❌ ExpiredListingArchiver: Error checking for expired listings: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }
    
    /// Manually trigger archiving (for testing or manual cleanup)
    func manualArchive() async {
        print("📦 ExpiredListingArchiver: Manual archive triggered")
        await archiveExpiredListings()
    }
}

