import SwiftUI

// MARK: - Star Rating Display Component

struct StarRatingView: View {
    let rating: Double
    let maxRating: Int = 5
    let size: CGFloat
    
    init(rating: Double, size: CGFloat = 16) {
        self.rating = rating
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: starImageName(for: index))
                    .foregroundColor(.yellow)
                    .font(.system(size: size))
            }
        }
    }
    
    private func starImageName(for index: Int) -> String {
        let difference = rating - Double(index - 1)
        
        if difference >= 1 {
            return "star.fill"
        } else if difference >= 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Interactive Star Rating Selector

struct StarRatingSelector: View {
    @Binding var rating: Int
    let maxRating: Int = 5
    let size: CGFloat
    
    init(rating: Binding<Int>, size: CGFloat = 24) {
        self._rating = rating
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundColor(index <= rating ? .yellow : .gray)
                    .font(.system(size: size))
                    .onTapGesture {
                        rating = index
                    }
            }
        }
    }
}

// MARK: - Trust Badge Component

struct TrustBadgeView: View {
    let trustLevel: TrustLevel
    let showText: Bool
    
    init(trustLevel: TrustLevel, showText: Bool = true) {
        self.trustLevel = trustLevel
        self.showText = showText
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(trustLevel.emoji)
                .font(.caption)
            
            if showText {
                Text(trustLevel.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(trustLevel.color).opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Rating Summary Component

struct RatingSummaryView: View {
    let summary: UserRatingsSummary
    let showBreakdown: Bool
    
    init(summary: UserRatingsSummary, showBreakdown: Bool = false) {
        self.summary = summary
        self.showBreakdown = showBreakdown
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StarRatingView(rating: summary.averageRating, size: 16)
                
                Text(summary.displayRating)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("(\(summary.totalRatings))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                TrustBadgeView(trustLevel: summary.trustLevel)
            }
            
            if showBreakdown && summary.hasRatings {
                ratingsBreakdown
            }
        }
    }
    
    @ViewBuilder
    private var ratingsBreakdown: some View {
        VStack(spacing: 4) {
            ForEach((1...5).reversed(), id: \.self) { stars in
                HStack {
                    Text("\(stars)")
                        .font(.caption2)
                        .frame(width: 20)
                    
                    ProgressView(value: Double(summary.ratingsBreakdown[stars] ?? 0), total: Double(summary.totalRatings))
                        .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                    
                    Text("\(summary.ratingsBreakdown[stars] ?? 0)")
                        .font(.caption2)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Rating Card Component

struct RatingCardView: View {
    let rating: Rating
    let showRater: Bool
    
    init(rating: Rating, showRater: Bool = true) {
        self.rating = rating
        self.showRater = showRater
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showRater && !rating.isAnonymous {
                    Text(rating.rater?.name ?? "Anonymous")
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text("Anonymous User")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    StarRatingView(rating: Double(rating.rating), size: 14)
                    Text(rating.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if let comment = rating.comment, !comment.isEmpty {
                Text(comment)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(nil)
            }
            
            Text(rating.ratingText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            if rating.isReported {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill").font(.caption2)
                    Text("Reported for review")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Rating Compose View (Stub)

struct RatingComposeView: View {
    let order: Order
    let ratingType: RatingType
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var selectedRating: Int = 5
    @State private var comment: String = ""
    @State private var isAnonymous: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if AppConfig.enableRatings {
                    ScrollView {
                        VStack(spacing: 20) {
                            orderInfoSection
                            ratingSection
                            commentSection
                            anonymousSection
                            submitButton
                        }
                        .padding()
                    }
                } else {
                    featureDisabledView
                }
            }
            .navigationTitle(ratingType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var orderInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Order Details")
                .font(.headline)
            
            HStack {
                Text(order.listing?.title ?? "Order")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(order.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("ThemeColor"))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var ratingSection: some View {
        VStack(spacing: 12) {
            Text("How was your experience?")
                .font(.headline)
            
            StarRatingSelector(rating: $selectedRating, size: 32)
            
            Text(ratingText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a comment (optional)")
                .font(.headline)
            
            TextField("Share your experience...", text: $comment, axis: .vertical)
                .lineLimit(3...6)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
    
    private var anonymousSection: some View {
        Toggle("Submit anonymously", isOn: $isAnonymous)
            .font(.subheadline)
    }
    
    private var submitButton: some View {
        Button(action: submitRating) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                Text(isSubmitting ? "Submitting..." : "Submit Rating")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color("ThemeColor"))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(isSubmitting)
    }
    
    private var featureDisabledView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Coming Soon")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("The ratings system is currently under development.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var ratingText: String {
        switch selectedRating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return ""
        }
    }
    
    private func submitRating() {
        guard AppConfig.enableRatings else {
            errorMessage = "Ratings feature is currently disabled"
            return
        }
        
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "You must be logged in to submit a rating"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                // Determine the rated user based on rating type
                let ratedUserId: String
                switch ratingType {
                case .buyerToSeller:
                    ratedUserId = order.sellerId.uuidString
                case .sellerToBuyer:
                    ratedUserId = order.buyerId.uuidString
                }
                
                // Create rating
                let ratingCreate = RatingCreate(
                    orderId: order.id,
                    raterId: currentUserId,
                    ratedId: ratedUserId,
                    rating: selectedRating,
                    comment: comment.isEmpty ? nil : comment,
                    ratingType: ratingType,
                    isAnonymous: isAnonymous
                )
                
                // Submit rating
                let _ = try await RatingService.shared.submitRating(ratingCreate)
                
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Seller Rating Summary (Reusable)

struct SellerRatingSummaryView: View {
    let userId: String
    @State private var summary: UserRatingsSummary?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 8) {
            if let summary = summary {
                StarRatingView(rating: summary.averageRating, size: 14)
                Text(summary.displayRating)
                    .font(.subheadline)
                Text("(\(summary.totalRatings))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                TrustBadgeView(trustLevel: summary.trustLevel, showText: false)
            } else if isLoading {
                ProgressView().scaleEffect(0.7)
            } else {
                // Fallback when ratings are unavailable (e.g., RLS blocks or no data yet)
                HStack(spacing: 6) {
                    StarRatingView(rating: 0, size: 14)
                    Text("New")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .task { await load() }
    }
    
    private func load() async {
        guard AppConfig.enableRatings else { return }
        do {
            let s = try await RatingService.shared.getUserRatingsSummary(userId: userId)
            await MainActor.run { self.summary = s; self.isLoading = false }
        } catch {
            // Debug: Print error to see what's failing
            print("SellerRatingSummaryView load error for user \(userId): \(error)")
            // Swallow errors (e.g., unauthenticated viewer + RLS) and show fallback
            await MainActor.run { self.isLoading = false }
        }
    }
}

// MARK: - Preview Data

struct RatingComponents_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StarRatingView(rating: 4.5)
                .previewDisplayName("Star Rating")
            
            RatingSummaryView(summary: .sampleSummary)
                .previewDisplayName("Rating Summary")
                .padding()
            
            RatingCardView(rating: .sampleRating)
                .previewDisplayName("Rating Card")
                .padding()
        }
    }
}
