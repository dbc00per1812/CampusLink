import SwiftUI
import Supabase

/// Public profile view for viewing another user's profile
/// Shows their ratings, bio, active listings, and other public information
struct PublicProfileView: View {
    let user: User
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var userListings: [ListingWithUser] = []
    @State private var isLoading = false
    @State private var postsCount = 0
    @State private var ratingsSummary: UserRatingsSummary?
    @State private var isLoadingRatings = false
    @State private var showReportUser = false
    @State private var showBlockUser = false
    @Environment(\.dismiss) private var dismiss
    
    private var isOwnProfile: Bool {
        guard let currentUserId = authManager.currentUserId else { return false }
        return user.id.lowercased() == currentUserId.lowercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile info section
                profileInfoSection
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                
                // Posts grid section
                postsGridSection
                
                Spacer()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOwnProfile {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showReportUser = true
                        } label: {
                            Label("Report User", systemImage: "exclamationmark.triangle")
                        }
                        
                        Button(role: .destructive) {
                            showBlockUser = true
                        } label: {
                            Label("Block User", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadUserListings()
                if AppConfig.enableRatings {
                    await loadRatings(userId: user.id)
                }
            }
        }
        .sheet(isPresented: $showReportUser) {
            ReportUserView(userId: user.id, userName: user.name)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showBlockUser) {
            BlockUserView(userId: user.id, userName: user.name ?? "Unknown User", onBlockComplete: {
                dismiss()
            })
            .environmentObject(authManager)
        }
    }
}

// MARK: - View Components

extension PublicProfileView {
    
    private var profileInfoSection: some View {
        VStack(spacing: 16) {
            // Profile Picture
            profilePictureView
            
            // Name and Bio
            VStack(spacing: 8) {
                Text(user.name ?? "Unknown User")
                    .responsiveFont(.title2, weight: .semibold)
                
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .responsiveFont(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Campus info
                if let campus = user.campus {
                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap")
                            .foregroundColor(.secondary)
                            .responsiveFont(.caption)
                        Text(campus)
                            .responsiveFont(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Verified student badge
                if user.isVerifiedStudent {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color("ThemeColor"))
                            .responsiveFont(.caption)
                        Text("Verified Student")
                            .responsiveFont(.subheadline)
                            .foregroundColor(Color("ThemeColor"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color("ThemeColor").opacity(0.1))
                    .responsiveCornerRadius(12)
                }
                
                // Member since
                Text("Member since \(formatMemberSince(user.createdAt))")
                    .responsiveFont(.caption)
                    .foregroundColor(.secondary)
                
                // Ratings Summary
                if AppConfig.enableRatings {
                    if let summary = ratingsSummary {
                        RatingSummaryView(summary: summary)
                            .padding(.top, 8)
                    } else if isLoadingRatings {
                        ProgressView()
                            .padding(.top, 8)
                    } else {
                        Text("No ratings yet")
                            .responsiveFont(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            
            // Stats
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("\(postsCount)")
                        .responsiveFont(.title3, weight: .bold)
                        .foregroundColor(.primary)
                    Text("Listings")
                        .responsiveFont(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let trustScore = user.trustScore {
                    VStack(spacing: 4) {
                        Text("\(trustScore)")
                            .responsiveFont(.title3, weight: .bold)
                            .foregroundColor(.primary)
                        Text("Trust Score")
                            .responsiveFont(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if AppConfig.enableRatings, let summary = ratingsSummary, summary.totalRatings > 0 {
                    VStack(spacing: 4) {
                        Text("\(summary.totalRatings)")
                            .responsiveFont(.title3, weight: .bold)
                            .foregroundColor(.primary)
                        Text("Ratings")
                            .responsiveFont(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 8)
            
            // View all ratings button
            if AppConfig.enableRatings, let summary = ratingsSummary, summary.totalRatings > 0 {
                NavigationLink(destination: RatingsHistoryView(userId: user.id)) {
                    Text("View All Ratings")
                        .responsiveFont(.subheadline, weight: .medium)
                        .foregroundColor(Color("ThemeColor"))
                        .frame(maxWidth: .infinity)
                        .responsiveSpacing(8)
                        .background(Color("ThemeColor").opacity(0.1))
                        .responsiveCornerRadius(8)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
        .responsiveSpacing(16)
    }
    
    private var profilePictureView: some View {
        UserAvatarView(user: user, size: 100)
    }
    
    private var postsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Listings")
                    .responsiveFont(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal, 16)
            
            if userListings.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No active listings")
                        .responsiveFont(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(userListings) { listing in
                        NavigationLink(destination: ListingDetailView(listing: listing)) {
                            ProfileListingCard(listing: listing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Data Loading

extension PublicProfileView {
    
    private func loadUserListings() async {
        await MainActor.run { isLoading = true }
        
        do {
            let response: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("user_id", value: user.id)
                .eq("status", value: "active")
                .neq("archived", value: true)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            await MainActor.run {
                self.userListings = response
                self.postsCount = response.count
                self.isLoading = false
            }
        } catch {
            print("Failed to load user listings: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private func loadRatings(userId: String) async {
        await MainActor.run { isLoadingRatings = true }
        do {
            let summary = try await RatingService.shared.getUserRatingsSummary(userId: userId)
            await MainActor.run { 
                self.ratingsSummary = summary
                self.isLoadingRatings = false
            }
        } catch {
            print("Failed to load ratings: \(error)")
            await MainActor.run { self.isLoadingRatings = false }
        }
    }
    
    private func formatMemberSince(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - ListingCard Component

struct ProfileListingCard: View {
    let listing: ListingWithUser
    @State private var currentImageIndex: Int = 0
    @EnvironmentObject var authManager: AuthManager
    
    private var currentUserId: String? {
        authManager.session?.user.id.uuidString
    }
    private var isOwnListing: Bool {
        guard let currentId = currentUserId else { return false }
        return listing.user.id.lowercased() == currentId.lowercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square image at top
            listingImagesCarousel()

            VStack(alignment: .leading, spacing: 6) {
                // Price first - large and bold
                if AppConfig.enableSeekMode && listing.intent == .seek {
                    if let min = listing.budgetMin, let max = listing.budgetMax {
                        Text("$\(min, specifier: "%.0f")-$\(max, specifier: "%.0f")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isOwnListing ? .blue : .green)
                    } else if let max = listing.budgetMax {
                        Text("Up to $\(max, specifier: "%.0f")")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(isOwnListing ? .blue : .green)
                    }
                } else {
                    // Show seller's posted price for everyone (fees shown at checkout)
                    Text("$\((listing.price ?? 0), specifier: "%.2f")")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isOwnListing ? .blue : .green)
                }
                
                // Title
                Text(listing.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func listingImagesCarousel() -> some View {
        GeometryReader { geometry in
            let imageSize = geometry.size.width
            let photos = listing.photos
            
            if !photos.isEmpty {
                ZStack(alignment: .bottom) {
                    TabView(selection: $currentImageIndex) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photoUrl in
                            AsyncImage(url: URL(string: photoUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: imageSize, height: imageSize)
                                        .clipped()
                                case .failure(_), .empty:
                                    Rectangle()
                                        .fill(Color(UIColor.systemGray5))
                                        .frame(width: imageSize, height: imageSize)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.secondary)
                                                .font(.largeTitle)
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: imageSize)
                    
                    if photos.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<photos.count, id: \.self) { index in
                                Circle()
                                    .fill(currentImageIndex == index ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: imageSize, height: imageSize)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                            .font(.largeTitle)
                    )
            }
        }
        .aspectRatio(1.0, contentMode: .fit)
    }
}

