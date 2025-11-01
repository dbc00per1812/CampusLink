import SwiftUI
import Supabase

struct Category: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let type: ListingType
}

struct BrowseByCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Callback for when a category is selected
    let onCategorySelected: ((String, ListingType) -> Void)?
    
    init(onCategorySelected: ((String, ListingType) -> Void)? = nil) {
        self.onCategorySelected = onCategorySelected
    }
    
    // Product categories
    private let productCategories = [
        Category(name: "Electronics", icon: "laptopcomputer", type: .product),
        Category(name: "Books", icon: "book.fill", type: .product),
        Category(name: "Furniture", icon: "bed.double.fill", type: .product),
        Category(name: "Clothing", icon: "tshirt.fill", type: .product),
        Category(name: "Sports", icon: "sportscourt.fill", type: .product),
        Category(name: "Tickets", icon: "ticket.fill", type: .product),
        Category(name: "Other", icon: "square.grid.2x2.fill", type: .product)
    ]
    
    // Service categories
    private let serviceCategories = [
        Category(name: "Tutoring", icon: "graduationcap.fill", type: .service),
        Category(name: "Moving", icon: "shippingbox.fill", type: .service),
        Category(name: "Cleaning", icon: "sparkles", type: .service),
        Category(name: "Other Services", icon: "wrench.and.screwdriver.fill", type: .service)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Products Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Products")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(productCategories) { category in
                            Button(action: {
                                onCategorySelected?(category.name, category.type)
                            }) {
                                CategoryCard(category: category)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Services Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Services")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(serviceCategories) { category in
                            Button(action: {
                                onCategorySelected?(category.name, category.type)
                            }) {
                                CategoryCard(category: category)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Browse by Category")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CategoryCard: View {
    let category: Category
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color("ThemeColor").opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: category.icon)
                    .font(.system(size: 28))
                    .foregroundColor(Color("ThemeColor"))
            }
            
            Text(category.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// Category Listings View - shows all listings for a specific category
struct CategoryListingsView: View {
    let category: String
    let type: ListingType
    @EnvironmentObject private var authManager: AuthManager
    @State private var listings: [ListingWithUser] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading \(category)...")
                    Spacer()
                }
            } else if listings.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No \(category) listings yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Be the first to post in this category!")
                        .font(.body)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(listings) { listing in
                            NavigationLink(destination: ListingDetailView(listing: listing)) {
                                ListingCard(listing: listing)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await loadCategoryListings()
            }
        }
    }
    
    private func loadCategoryListings() async {
        do {
            let result: [ListingWithUser] = try await supabase
                .from("listings")
                .select("*, user:users(*)")
                .eq("status", value: "active")
                .neq("archived", value: true)
                .eq("is_sold", value: false)
                .eq("category", value: category)
                .eq("listing_type", value: type.rawValue)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            // Apply campus filtering
            let filteredResult = await applyCampusFilter(result)
            
            await MainActor.run {
                listings = filteredResult
                isLoading = false
            }
        } catch {
            print("❌ Error loading category listings: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // Apply campus filtering to listings
    private func applyCampusFilter(_ listings: [ListingWithUser]) async -> [ListingWithUser] {
        guard AppConfig.enableCampusFilter else { return listings }
        
        // Get current user's campus from their profile
        guard let currentUserId = authManager.session?.user.id.uuidString else {
            print("🔍 Campus Filter: Could not get current user's ID")
            return listings // Return all listings if we can't determine user
        }
        
        // Fetch current user's campus
        do {
            let currentUser: User = try await supabase
                .from("users")
                .select("id, campus")
                .eq("id", value: currentUserId)
                .single()
                .execute()
                .value
            
            guard let currentCampus = currentUser.campus, !currentCampus.isEmpty else {
                print("🔍 Campus Filter: Current user has no campus set")
                return listings // Return all listings if user has no campus
            }
            
            print("🔍 Campus Filter: Current user campus: \(currentCampus)")
            
            // Filter listings to only show those from users with the same campus
            let filteredListings = listings.filter { listing in
                guard let userCampus = listing.user.campus, !userCampus.isEmpty else {
                    print("⚠️ Campus Filter: Excluding listing '\(listing.title)' - user has no campus set")
                    return false // Exclude listings from users without campus
                }
                
                return userCampus == currentCampus
            }
            
            print("🔍 Campus Filter: Filtered \(listings.count) listings to \(filteredListings.count) for campus \(currentCampus)")
            
            return filteredListings
        } catch {
            print("❌ Campus Filter: Error fetching user campus: \(error)")
            return listings // Return unfiltered if error
        }
    }
}
