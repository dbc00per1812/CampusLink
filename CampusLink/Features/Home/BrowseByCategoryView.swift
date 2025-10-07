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
                            NavigationLink(destination: CategoryListingsView(category: category.name, type: category.type)) {
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
                            NavigationLink(destination: CategoryListingsView(category: category.name, type: category.type)) {
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
            
            await MainActor.run {
                listings = result
                isLoading = false
            }
        } catch {
            print("❌ Error loading category listings: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
