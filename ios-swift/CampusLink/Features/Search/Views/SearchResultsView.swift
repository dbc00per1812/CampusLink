import SwiftUI

// MARK: - Search Results View

struct SearchResultsView: View {
    @StateObject private var searchService = SearchService.shared
    @State private var searchResults = SearchResult(listings: [], totalCount: 0, searchRank: [:], suggestions: [], hasMore: false)
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage = 0
    
    let searchQuery: SearchQuery
    
    private let itemsPerPage = 20
    
    var body: some View {
        Group {
            if isLoading && searchResults.listings.isEmpty {
                SearchLoadingView()
            } else if searchResults.listings.isEmpty && !isLoading {
                SearchEmptyStateView(searchQuery: searchQuery) {
                    Task {
                        await performSearch(resetResults: true)
                    }
                }
            } else {
                searchResultsList
            }
        }
        .task {
            await performSearch(resetResults: true)
        }
        .refreshable {
            await performSearch(resetResults: true)
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Search summary
                searchSummaryView
                
                // Results grid
                ForEach(searchResults.listings, id: \.id) { listing in
                    NavigationLink(destination: ListingDetailView(listing: listing.toListingWithUser())) {
                        SearchResultCard(
                            listing: listing.toListingWithUser(),
                            searchRank: searchResults.searchRank[listing.id] ?? 0
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // Load more when near the end
                        if listing.id == searchResults.listings.last?.id && searchResults.hasMore {
                            Task {
                                await loadMoreResults()
                            }
                        }
                    }
                }
                
                // Loading indicator for pagination
                if isLoading && !searchResults.listings.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .responsiveSpacing(16)
                }
                
                // End of results message
                if !searchResults.hasMore && !searchResults.listings.isEmpty {
                    Text("No more results")
                        .responsiveFont(.body)
                        .foregroundColor(.secondary)
                        .responsiveSpacing(16)
                }
            }
            .responsiveHorizontalSpacing(16)
        }
    }
    
    private var searchSummaryView: some View {
        HStack {
            Text("\(searchResults.totalCount) results")
                .responsiveFont(.headline)
                .foregroundColor(.primary)
            
            if !searchQuery.text.isEmpty {
                Text("for \"\(searchQuery.text)\"")
                    .responsiveFont(.headline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .responsiveSpacing(8)
    }
    
    private func performSearch(resetResults: Bool) async {
        guard AppConfig.enableSearch else { return }
        
        isLoading = true
        errorMessage = nil
        
        if resetResults {
            currentPage = 0
        }
        
        do {
            let results = try await searchService.searchListings(
                query: searchQuery,
                limit: itemsPerPage,
                offset: currentPage * itemsPerPage
            )
            
            if resetResults {
                searchResults = results
            } else {
                // Append new results for pagination
                searchResults = SearchResult(
                    listings: searchResults.listings + results.listings,
                    totalCount: results.totalCount,
                    searchRank: searchResults.searchRank.merging(results.searchRank) { _, new in new },
                    suggestions: results.suggestions,
                    hasMore: results.hasMore
                )
            }
            
        } catch {
            // Swallow non-critical search errors in production to avoid random popups
            #if DEBUG
            errorMessage = error.localizedDescription
            #else
            errorMessage = nil
            #endif
        }
        
        isLoading = false
    }
    
    private func loadMoreResults() async {
        guard !isLoading && searchResults.hasMore else { return }
        
        currentPage += 1
        await performSearch(resetResults: false)
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let listing: ListingWithUser
    let searchRank: Float
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Listing title with relevance indicator
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .responsiveFont(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if searchRank > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .responsiveFont(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", searchRank))
                                .responsiveFont(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Price
                Text("$\(Int(listing.price ?? 0))")
                    .responsiveFont(.headline, weight: .semibold)
                    .foregroundColor(.green)
            }
            
            // Description
            if !listing.description.isEmpty {
                Text(listing.description)
                    .responsiveFont(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // Category and user info
            HStack {
                if !listing.category.isEmpty {
                    Text(listing.category)
                        .responsiveFont(.caption)
                        .responsiveHorizontalSpacing(8)
                        .responsiveSpacing(4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .responsiveCornerRadius(6)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    if let userName = listing.user.name {
                        Text(userName.formattedName)
                            .responsiveFont(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                }
            }
        }
        .responsiveSpacing(12)
        .responsiveHorizontalSpacing(12)
        .background(Color(.systemBackground))
        .responsiveCornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Search Loading View

struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Searching...")
                .responsiveFont(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Search Empty State View

struct SearchEmptyStateView: View {
    let searchQuery: SearchQuery
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .responsiveFontSize(48)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("No results found")
                    .responsiveFont(.title2, weight: .semibold)
                    .fontWeight(.semibold)
                
                if !searchQuery.text.isEmpty {
                    Text("Try a different search term or adjust your filters")
                        .responsiveFont(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Enter a search term to find listings")
                        .responsiveFont(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if !searchQuery.text.isEmpty {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Search suggestions
            if !searchQuery.text.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Try searching for:")
                        .responsiveFont(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Electronics")
                        Text("• Textbooks")
                        Text("• Tutoring")
                        Text("• Furniture")
                    }
                    .responsiveFont(.body)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .responsiveSpacing(12)
                .responsiveHorizontalSpacing(12)
                .background(Color(.systemGray6))
                .responsiveCornerRadius(10)
            }
        }
        .responsiveSpacing(16)
        .responsiveHorizontalSpacing(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SearchResultsView(searchQuery: SearchQuery(text: "laptop"))
    }
}
