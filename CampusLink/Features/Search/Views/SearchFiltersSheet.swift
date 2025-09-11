import SwiftUI

// MARK: - Search Filters Sheet (minimal compile-safe implementation)

struct SearchFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: SearchFilters

    // Simple local state for inputs
    @State private var selectedCategory: String? = nil
    @State private var minPriceText: String = ""
    @State private var maxPriceText: String = ""
    @State private var selectedIntent: ListingIntent? = nil
    @State private var selectedLocation: ServiceLocation? = nil
    @State private var selectedListingType: ListingType? = nil
    @State private var trustScore: Int = 0
    
    // Available categories (combined from both product and service)
    private let allCategories = [
        "Electronics", "Books", "Furniture", "Clothing", "Sports", "Tickets",
        "Tutoring", "Moving", "Cleaning", "Other"
    ].sorted()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Any Category").tag(String?.none)
                        ForEach(allCategories, id: \.self) { category in
                            Text(category).tag(String?.some(category))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section(header: Text("Type")) {
                    Picker("Intent", selection: $selectedIntent) {
                        Text("Any").tag(ListingIntent?.none)
                        Text(ListingIntent.offer.displayName).tag(ListingIntent?.some(.offer))
                        Text(ListingIntent.seek.displayName).tag(ListingIntent?.some(.seek))
                    }
                    Picker("Listing", selection: $selectedListingType) {
                        Text("Any").tag(ListingType?.none)
                        Text("Product").tag(ListingType?.some(.product))
                        Text("Service").tag(ListingType?.some(.service))
                    }
                    Picker("Location", selection: $selectedLocation) {
                        Text("Any").tag(ServiceLocation?.none)
                        Text("On Campus").tag(ServiceLocation?.some(.onCampus))
                        Text("Off Campus").tag(ServiceLocation?.some(.offCampus))
                        Text("Remote").tag(ServiceLocation?.some(.remote))
                    }
                }

                Section(header: Text("Price Range")) {
                    HStack {
                        TextField("Min", text: $minPriceText)
                            .keyboardType(.numberPad)
                        Text("-")
                        TextField("Max", text: $maxPriceText)
                            .keyboardType(.numberPad)
                    }
                }

                Section(header: Text("Minimum Trust Score")) {
                    Slider(value: Binding(get: { Double(trustScore) }, set: { trustScore = Int($0) }), in: 0...100, step: 5)
                    Text("\(trustScore)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") { clearAll() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyToBinding()
                        dismiss()
                    }
                }
            }
            .onAppear { loadFromBinding() }
        }
    }

    private func loadFromBinding() {
        selectedCategory = filters.category
        if let pr = filters.priceRange { minPriceText = pr.min.map { String(Int($0)) } ?? ""; maxPriceText = pr.max.map { String(Int($0)) } ?? "" }
        selectedIntent = filters.intent
        selectedLocation = filters.location
        selectedListingType = filters.listingType
        trustScore = filters.minTrustScore ?? 0
    }

    private func applyToBinding() {
        filters.category = selectedCategory
        let minVal = Double(minPriceText)
        let maxVal = Double(maxPriceText)
        if minVal != nil || maxVal != nil {
            filters.priceRange = PriceRange(min: minVal, max: maxVal)
        } else {
            filters.priceRange = nil
        }
        filters.intent = selectedIntent
        filters.location = selectedLocation
        filters.listingType = selectedListingType
        filters.minTrustScore = trustScore > 0 ? trustScore : nil
    }

    private func clearAll() {
        selectedCategory = nil
        minPriceText = ""
        maxPriceText = ""
        selectedIntent = nil
        selectedLocation = nil
        selectedListingType = nil
        trustScore = 0
        filters = SearchFilters()
    }
}


