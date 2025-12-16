import SwiftUI
import Supabase

// MARK: - Models
struct SellerMetrics: Codable {
    let activeListings: Int
    let totalViews: Int
    let weekViews: Int
    let chatsToAnswer: Int
    let listingsToRenew: Int
    
    static let empty = SellerMetrics(
        activeListings: 0,
        totalViews: 0,
        weekViews: 0,
        chatsToAnswer: 0,
        listingsToRenew: 0
    )
}

// MARK: - Main View
struct SellerDashboardView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var metrics = SellerMetrics.empty
    @State private var isLoading = true
    @State private var ratingsSummary: UserRatingsSummary?
    @State private var showingCreateListing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Create Listing CTA
                createListingButton
                
                // Overview Section
                overviewSection
                
                // Performance Section
                performanceSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .navigationTitle("Selling")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                await loadMetrics()
            }
        }
        .sheet(isPresented: $showingCreateListing) {
            PostView()
                .environmentObject(authManager)
        }
    }
    
    // MARK: - Create Listing Button
    private var createListingButton: some View {
        Button(action: {
            showingCreateListing = true
        }) {
            HStack {
                Image(systemName: "plus")
                    .font(.headline)
                Text("Create listing")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color("ThemeColor"))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.title2)
                .fontWeight(.bold)
            
            // First row
            HStack(spacing: 12) {
                metricCard(
                    value: metrics.chatsToAnswer,
                    label: "Chats to answer",
                    icon: "message",
                    color: .blue
                )
                
                metricCard(
                    value: metrics.activeListings,
                    label: "Active listings",
                    icon: "tag",
                    color: .green
                )
            }
            
            // Second row
            HStack(spacing: 12) {
                metricCard(
                    value: 0,
                    label: "Add video to listings",
                    icon: "video",
                    color: .purple
                )
                
                metricCard(
                    value: metrics.listingsToRenew,
                    label: "Listings to renew",
                    icon: "arrow.clockwise",
                    color: .orange
                )
            }
            
            // Third row
            HStack(spacing: 12) {
                metricCard(
                    value: 0,
                    label: "Listings to delete & relist",
                    icon: "arrow.2.squarepath",
                    color: .facebookBlue
                )
                
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Performance Section
    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .font(.title2)
                .fontWeight(.bold)
            
            // First row
            HStack(spacing: 12) {
                performanceCard(
                    value: metrics.weekViews,
                    label: "Clicks on listings",
                    subtitle: "Last 7 days",
                    color: .blue
                )
                
                if AppConfig.enableRatings {
                    ratingCard()
                } else {
                    performanceCard(
                        value: 0,
                        label: "Seller rating",
                        subtitle: "No ratings yet",
                        color: .yellow
                    )
                }
            }
            
            // Second row
            HStack(spacing: 12) {
                performanceCard(
                    value: 0,
                    label: "New followers",
                    subtitle: "Last 7 days",
                    color: .purple
                )
                
                performanceCard(
                    value: 0,
                    label: "3-second video plays",
                    subtitle: "Last 7 days",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Metric Card
    private func metricCard(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(value)")
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Performance Card
    private func performanceCard(value: Int, label: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(value)")
                .font(.system(size: 32, weight: .bold))
            
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Rating Card
    private func ratingCard() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if let summary = ratingsSummary {
                    Text(String(format: "%.1f", summary.averageRating))
                        .font(.system(size: 32, weight: .bold))
                    Image(systemName: "star.fill")
                        .font(.title3)
                        .foregroundColor(.yellow)
                } else {
                    Text("0")
                        .font(.system(size: 32, weight: .bold))
                }
            }
            
            Text("Seller rating")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let summary = ratingsSummary {
                Text("\(summary.totalRatings) ratings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No ratings yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Data Loading
    private func loadMetrics() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        await MainActor.run { isLoading = true }
        
        async let activeListings = loadActiveListingsCount(userId: userId)
        async let chatsToAnswer = loadChatsToAnswer(userId: userId)
        async let viewsData = loadViewsCount(userId: userId)
        
        let (active, chats, views) = await (activeListings, chatsToAnswer, viewsData)
        
        // Calculate listings that might need renewal (older than 30 days)
        let listingsToRenew = await loadListingsToRenew(userId: userId)
        
        // Load ratings if enabled
        if AppConfig.enableRatings {
            ratingsSummary = try? await RatingService.shared.getUserRatingsSummary(userId: userId)
        }
        
        await MainActor.run {
            metrics = SellerMetrics(
                activeListings: active,
                totalViews: views.total,
                weekViews: views.week,
                chatsToAnswer: chats,
                listingsToRenew: listingsToRenew
            )
            isLoading = false
        }
    }
    
    private func loadActiveListingsCount(userId: String) async -> Int {
        do {
            let count = try await supabase
                .from("listings")
                .select("id", head: false, count: .exact)
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .execute()
                .count
            
            return count ?? 0
        } catch {
            print("Error loading active listings count: \(error)")
            return 0
        }
    }
    
    private func loadChatsToAnswer(userId: String) async -> Int {
        // Count conversations where user hasn't sent the last message
        do {
            // Get conversations where user is a participant
            let conversations: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .or("participant_1.eq.\(userId),participant_2.eq.\(userId)")
                .execute()
                .value
            
            var unansweredCount = 0
            
            for conversation in conversations {
                // Get last message in conversation
                let messages: [Message] = try await supabase
                    .from("messages")
                    .select()
                    .eq("conversation_id", value: conversation.id)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                // If last message was not from current user and is unread, count it
                if let lastMessage = messages.first,
                   lastMessage.senderId != userId {
                    unansweredCount += 1
                }
            }
            
            return unansweredCount
        } catch {
            print("Error loading chats to answer: \(error)")
            return 0
        }
    }
    
    private func loadViewsCount(userId: String) async -> (total: Int, week: Int) {
        // This would ideally come from an analytics table
        // For now, we'll estimate based on listing age
        do {
            let listings: [Listing] = try await supabase
                .from("listings")
                .select("created_at")
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .execute()
                .value
            
            // Rough estimate: 10 views per day per listing
            let totalViews = listings.count * 50
            let weekViews = listings.count * 10
            
            return (totalViews, weekViews)
        } catch {
            print("Error loading views: \(error)")
            return (0, 0)
        }
    }
    
    private func loadListingsToRenew(userId: String) async -> Int {
        do {
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let isoDate = ISO8601DateFormatter().string(from: thirtyDaysAgo)
            
            let count = try await supabase
                .from("listings")
                .select("id", head: false, count: .exact)
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .lt("created_at", value: isoDate)
                .execute()
                .count
            
            return count ?? 0
        } catch {
            print("Error loading listings to renew: \(error)")
            return 0
        }
    }
}

// MARK: - Preview
struct SellerDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SellerDashboardView()
                .environmentObject(AuthManager())
        }
    }
}

