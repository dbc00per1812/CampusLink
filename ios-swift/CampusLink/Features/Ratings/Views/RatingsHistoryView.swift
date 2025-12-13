import SwiftUI

struct RatingsHistoryView: View {
    let userId: String
    @EnvironmentObject private var authManager: AuthManager
    @State private var ratings: [Rating] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showReportConfirm = false
    @State private var ratingToReport: Rating?
    @State private var isReporting = false
    @State private var reportSuccessMessage: String?
    
    var body: some View {
        VStack {
            if !AppConfig.enableRatings {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Ratings are not enabled")
                        .foregroundColor(.secondary)
                }
            } else if isLoading {
                ProgressView("Loading ratings...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let message = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(message)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if ratings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No ratings yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(ratings) { rating in
                            RatingCardView(rating: rating, showRater: true)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if canReport(rating: rating) && !rating.isReported {
                                        Button(role: .destructive) {
                                            ratingToReport = rating
                                            showReportConfirm = true
                                        } label: {
                                            Label("Report", systemImage: "flag")
                                        }
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Ratings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadRatings() }
        .alert("Report this rating?", isPresented: $showReportConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Report", role: .destructive) { Task { await reportSelectedRating() } }
        } message: {
            Text("We'll review this rating for guideline violations.")
        }
        .alert("Reported", isPresented: Binding(
            get: { reportSuccessMessage != nil },
            set: { if !$0 { reportSuccessMessage = nil } }
        )) {
            Button("OK") { reportSuccessMessage = nil }
        } message: {
            Text(reportSuccessMessage ?? "")
        }
    }
    
    private func loadRatings() async {
        guard AppConfig.enableRatings else { return }
        do {
            let results = try await RatingService.shared.getUserRatings(userId: userId, limit: 100)
            await MainActor.run {
                self.ratings = results
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func canReport(rating: Rating) -> Bool {
        // Only the rated user can report a rating they received
        return authManager.currentUserId == userId
    }

    private func reportSelectedRating() async {
        guard let rating = ratingToReport else { return }
        isReporting = true
        do {
            try await RatingService.shared.reportRating(ratingId: rating.id)
            await MainActor.run {
                if let index = ratings.firstIndex(where: { $0.id == rating.id }) {
                    var updated = ratings[index]
                    // We cannot mutate 'let' properties; recreate with reported flag
                    let newRating = Rating(
                        id: updated.id,
                        orderId: updated.orderId,
                        raterId: updated.raterId,
                        ratedId: updated.ratedId,
                        rating: updated.rating,
                        comment: updated.comment,
                        ratingType: updated.ratingType,
                        isAnonymous: updated.isAnonymous,
                        createdAt: updated.createdAt,
                        updatedAt: updated.updatedAt,
                        isReported: true,
                        isHidden: updated.isHidden,
                        moderationStatus: updated.moderationStatus,
                        rater: updated.rater,
                        ratedUser: updated.ratedUser,
                        order: updated.order
                    )
                    ratings[index] = newRating
                }
                reportSuccessMessage = "Thanks. We'll review this rating."
                isReporting = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isReporting = false
            }
        }
    }
}

struct RatingsHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { RatingsHistoryView(userId: "sample-user-id") }
    }
}
