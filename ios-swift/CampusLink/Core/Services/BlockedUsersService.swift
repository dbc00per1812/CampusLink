import Foundation
import Supabase

@MainActor
class BlockedUsersService: ObservableObject {
    
    // Cache for blocked user IDs to reduce database queries
    private static var cachedBlockedIds: [String] = []
    private static var cacheTimestamp: Date?
    private static let cacheValiditySeconds: TimeInterval = 60 // Cache for 60 seconds
    
    // MARK: - Block User
    
    /// Block a user (two-way blocking)
    static func blockUser(_ userId: String, currentUserId: String) async throws {
        #if DEBUG
        print("🚫 BlockedUsersService: Blocking user \(userId)")
        #endif
        
        guard userId != currentUserId else {
            throw BlockingError.cannotBlockSelf
        }
        
        let blockInsert = BlockedUserInsert(
            blockerId: currentUserId,
            blockedId: userId
        )
        
        do {
            _ = try await supabase
                .from("blocked_users")
                .insert(blockInsert)
                .execute()
            
            // Invalidate cache
            invalidateCache()
            
            #if DEBUG
            print("✅ BlockedUsersService: Successfully blocked user \(userId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ BlockedUsersService: Failed to block user: \(error)")
            #endif
            throw BlockingError.blockFailed(error)
        }
    }
    
    // MARK: - Unblock User
    
    /// Unblock a user
    static func unblockUser(_ userId: String, currentUserId: String) async throws {
        #if DEBUG
        print("✅ BlockedUsersService: Unblocking user \(userId)")
        #endif
        
        do {
            _ = try await supabase
                .from("blocked_users")
                .delete()
                .eq("blocker_id", value: currentUserId)
                .eq("blocked_id", value: userId)
                .execute()
            
            // Invalidate cache
            invalidateCache()
            
            #if DEBUG
            print("✅ BlockedUsersService: Successfully unblocked user \(userId)")
            #endif
        } catch {
            #if DEBUG
            print("❌ BlockedUsersService: Failed to unblock user: \(error)")
            #endif
            throw BlockingError.unblockFailed(error)
        }
    }
    
    // MARK: - Check if User is Blocked
    
    /// Check if a specific user is blocked (either direction)
    static func isUserBlocked(_ userId: String, currentUserId: String) async throws -> Bool {
        #if DEBUG
        print("🔍 BlockedUsersService: Checking if user \(userId) is blocked")
        #endif
        
        do {
            // Check if there's any blocking relationship between the two users
            let response: [BlockedUser] = try await supabase
                .from("blocked_users")
                .select()
                .or("and(blocker_id.eq.\(currentUserId),blocked_id.eq.\(userId)),and(blocker_id.eq.\(userId),blocked_id.eq.\(currentUserId))")
                .execute()
                .value
            
            let isBlocked = !response.isEmpty
            
            #if DEBUG
            print("🔍 BlockedUsersService: User \(userId) is \(isBlocked ? "BLOCKED" : "NOT BLOCKED")")
            #endif
            
            return isBlocked
        } catch {
            #if DEBUG
            print("❌ BlockedUsersService: Failed to check blocking status: \(error)")
            #endif
            // On error, fail safe and return false (don't block access)
            return false
        }
    }
    
    // MARK: - Get All Blocked User IDs
    
    /// Get all user IDs that are blocked by or blocking the current user
    static func getBlockedUserIds(currentUserId: String) async throws -> [String] {
        // Check cache first
        if let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValiditySeconds {
            #if DEBUG
            print("📦 BlockedUsersService: Using cached blocked IDs (\(cachedBlockedIds.count) users)")
            #endif
            return cachedBlockedIds
        }
        
        #if DEBUG
        print("🔄 BlockedUsersService: Fetching blocked user IDs")
        #endif
        
        do {
            // Get users I blocked
            let blockedByMe: [BlockedUser] = try await supabase
                .from("blocked_users")
                .select()
                .eq("blocker_id", value: currentUserId)
                .execute()
                .value
            
            // Get users who blocked me
            let blockedMe: [BlockedUser] = try await supabase
                .from("blocked_users")
                .select()
                .eq("blocked_id", value: currentUserId)
                .execute()
                .value
            
            // Combine both lists
            var blockedIds = Set<String>()
            blockedByMe.forEach { blockedIds.insert($0.blockedId) }
            blockedMe.forEach { blockedIds.insert($0.blockerId) }
            
            let result = Array(blockedIds)
            
            // Update cache
            cachedBlockedIds = result
            cacheTimestamp = Date()
            
            #if DEBUG
            print("✅ BlockedUsersService: Found \(result.count) blocked users")
            #endif
            
            return result
        } catch {
            #if DEBUG
            print("❌ BlockedUsersService: Failed to fetch blocked user IDs: \(error)")
            #endif
            throw BlockingError.fetchFailed(error)
        }
    }
    
    // MARK: - Cache Management
    
    /// Invalidate the blocked users cache
    static func invalidateCache() {
        cachedBlockedIds = []
        cacheTimestamp = nil
        #if DEBUG
        print("🗑️ BlockedUsersService: Cache invalidated")
        #endif
    }
    
    // MARK: - Error Types
    
    enum BlockingError: LocalizedError {
        case cannotBlockSelf
        case blockFailed(Error)
        case unblockFailed(Error)
        case fetchFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .cannotBlockSelf:
                return "You cannot block yourself"
            case .blockFailed(let error):
                return "Failed to block user: \(error.localizedDescription)"
            case .unblockFailed(let error):
                return "Failed to unblock user: \(error.localizedDescription)"
            case .fetchFailed(let error):
                return "Failed to fetch blocked users: \(error.localizedDescription)"
            }
        }
    }
}



