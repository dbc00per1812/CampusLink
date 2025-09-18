import Foundation
import Supabase

// MARK: - Rating Service

final class RatingService: ObservableObject {
    static let shared = RatingService()
    private init() {}
    
    // MARK: - Rating Submission
    
    /// Submit a rating for a completed order
    func submitRating(_ ratingCreate: RatingCreate) async throws -> Rating {
        guard AppConfig.enableRatings else {
            throw RatingServiceError.featureDisabled
        }
        
        do {
            // Validate rating submission
            try validateRatingSubmission(ratingCreate)
            
            // Insert rating into database
            let rating: Rating = try await supabase
                .from("ratings")
                .insert(ratingCreate)
                .select()
                .single()
                .execute()
                .value
            
            return rating
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Check if user can rate for a specific order
    func canSubmitRating(orderId: UUID, raterId: String, ratedId: String) async throws -> Bool {
        guard AppConfig.enableRatings else { return false }
        
        do {
            // Check if rating already exists
            let existingRatings: [Rating] = try await supabase
                .from("ratings")
                .select()
                .eq("order_id", value: orderId.uuidString)
                .eq("rater_id", value: raterId)
                .eq("rated_id", value: ratedId)
                .execute()
                .value
            
            // Check if order is completed and user is participant
            let order: Order = try await supabase
                .from("orders")
                .select()
                .eq("id", value: orderId.uuidString)
                .single()
                .execute()
                .value
            
            let isOrderCompleted = order.orderStatus == .completed
            let isParticipant = order.buyerId.uuidString == raterId || order.sellerId.uuidString == raterId
            let isRatingTarget = order.buyerId.uuidString == ratedId || order.sellerId.uuidString == ratedId
            let noExistingRating = existingRatings.isEmpty
            
            return isOrderCompleted && isParticipant && isRatingTarget && noExistingRating
            
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Rating Retrieval
    
    /// Get ratings for a specific user
    func getUserRatings(userId: String, limit: Int = 20, offset: Int = 0) async throws -> [Rating] {
        guard AppConfig.enableRatings else { return [] }
        
        do {
            let ratings: [Rating] = try await supabase
                .from("ratings")
                .select("""
                    *,
                    rater:users!ratings_rater_id_fkey(*),
                    order:orders(*)
                """)
                .eq("rated_id", value: userId)
                .eq("moderation_status", value: "approved")
                .eq("is_hidden", value: false)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value
            
            return ratings
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Get rating summary for a user
    func getUserRatingsSummary(userId: String) async throws -> UserRatingsSummary {
        guard AppConfig.enableRatings else {
            throw RatingServiceError.featureDisabled
        }
        
        do {
            // Get all approved ratings for the user
            let ratings: [Rating] = try await getUserRatings(userId: userId, limit: 1000)
            print("RatingService: Got \(ratings.count) ratings for user \(userId)")

            // Try to read trust_score, but don't fail if blocked by RLS
            var trustScore = 50.0
            do {
                let user: User = try await supabase
                    .from("users")
                    .select("trust_score")
                    .eq("id", value: userId)
                    .single()
                    .execute()
                    .value
                trustScore = Double(user.trustScore ?? 50)
                print("RatingService: Got user trust score: \(user.trustScore ?? 0) for user \(userId)")
            } catch {
                #if DEBUG
                print("RatingService: Could not read users.trust_score due to RLS or missing row; defaulting to 50")
                #endif
            }

            // Calculate summary
            let totalRatings = ratings.count
            let averageRating = totalRatings > 0 ? ratings.map { Double($0.rating) }.reduce(0, +) / Double(totalRatings) : 0.0
            
            // Create ratings breakdown
            var breakdown: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
            for rating in ratings {
                breakdown[rating.rating, default: 0] += 1
            }
            
            // Get recent ratings (last 5)
            let recentRatings = Array(ratings.prefix(5))
            
            print("RatingService: Summary - avg: \(averageRating), total: \(totalRatings), trust: \(trustScore)")
            
            return UserRatingsSummary(
                userId: userId,
                averageRating: averageRating,
                totalRatings: totalRatings,
                trustScore: trustScore,
                ratingsBreakdown: breakdown,
                recentRatings: recentRatings
            )
            
        } catch {
            print("RatingService: Error getting summary for user \(userId): \(error)")
            throw handleError(error)
        }
    }
    
    /// Get ratings for a specific order
    func getOrderRatings(orderId: UUID) async throws -> [Rating] {
        guard AppConfig.enableRatings else { return [] }
        
        do {
            let ratings: [Rating] = try await supabase
                .from("ratings")
                .select("""
                    *,
                    rater:users!ratings_rater_id_fkey(*),
                    rated_user:users!ratings_rated_id_fkey(*)
                """)
                .eq("order_id", value: orderId.uuidString)
                .eq("moderation_status", value: "approved")
                .eq("is_hidden", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return ratings
            
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Rating Management
    
    /// Update an existing rating (within time limit)
    func updateRating(ratingId: UUID, newRating: Int, newComment: String?) async throws -> Rating {
        guard AppConfig.enableRatings else {
            throw RatingServiceError.featureDisabled
        }
        
        do {
            var updates: [String: String] = [
                "rating": String(newRating),
                "updated_at": Date().ISO8601Format()
            ]
            
            if let comment = newComment {
                updates["comment"] = comment
            }
            
            let rating: Rating = try await supabase
                .from("ratings")
                .update(updates)
                .eq("id", value: ratingId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            return rating
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Report a rating for moderation
    func reportRating(ratingId: UUID) async throws {
        guard AppConfig.enableRatings else {
            throw RatingServiceError.featureDisabled
        }
        
        do {
            let _: [Rating] = try await supabase
                .from("ratings")
                .update(["is_reported": true])
                .eq("id", value: ratingId.uuidString)
                .execute()
                .value
            
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Validation
    
    private func validateRatingSubmission(_ ratingCreate: RatingCreate) throws {
        // Validate rating range
        guard ratingCreate.rating >= 1 && ratingCreate.rating <= 5 else {
            throw RatingServiceError.invalidRating
        }
        
        // Validate comment length if provided
        if let comment = ratingCreate.comment, comment.count > 1000 {
            throw RatingServiceError.commentTooLong
        }
        
        // Prevent self-rating
        guard ratingCreate.raterId != ratingCreate.ratedId else {
            throw RatingServiceError.cannotRateSelf
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) -> RatingServiceError {
        if error is RatingServiceError {
            return error as! RatingServiceError
        }
        
        #if DEBUG
        print("RatingService Error: \(error)")
        #endif
        
        return .networkError
    }
}

// MARK: - Errors

enum RatingServiceError: Error, LocalizedError {
    case featureDisabled
    case invalidRating
    case commentTooLong
    case cannotRateSelf
    case alreadyRated
    case orderNotCompleted
    case unauthorizedAccess
    case networkError
    case ratingNotFound
    
    var errorDescription: String? {
        switch self {
        case .featureDisabled:
            return "Ratings feature is currently disabled"
        case .invalidRating:
            return "Rating must be between 1 and 5 stars"
        case .commentTooLong:
            return "Comment is too long (maximum 1000 characters)"
        case .cannotRateSelf:
            return "You cannot rate yourself"
        case .alreadyRated:
            return "You have already rated this user for this order"
        case .orderNotCompleted:
            return "You can only rate after the order is completed"
        case .unauthorizedAccess:
            return "You are not authorized to perform this action"
        case .networkError:
            return "Network connection error"
        case .ratingNotFound:
            return "Rating not found"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .featureDisabled:
            return "Please check back later when ratings are enabled"
        case .invalidRating:
            return "Please select a rating between 1 and 5 stars"
        case .commentTooLong:
            return "Please shorten your comment to 1000 characters or less"
        case .cannotRateSelf:
            return "Ratings are for other users only"
        case .alreadyRated:
            return "You can edit your existing rating if needed"
        case .orderNotCompleted:
            return "Wait for the order to be completed before rating"
        case .unauthorizedAccess:
            return "Only order participants can submit ratings"
        case .networkError:
            return "Please check your internet connection and try again"
        case .ratingNotFound:
            return "The rating you're looking for might have been removed"
        }
    }
}
