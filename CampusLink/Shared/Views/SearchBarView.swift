import SwiftUI

// MARK: - Search Bar View

struct SearchBarView: View {
    @Binding var searchText: String
    @State private var isSearching = false
    
    var onSearchChanged: ((String) -> Void)?
    var onSearchSubmitted: ((String) -> Void)?
    var placeholder: String = "Search listings..."
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .responsiveFontSize(16)
                
                TextField(placeholder, text: $searchText, onEditingChanged: { isEditing in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearching = isEditing
                    }
                })
                .textFieldStyle(PlainTextFieldStyle())
                .responsiveFont(.body)
                .onChange(of: searchText) { newValue in
                    onSearchChanged?(newValue)
                }
                .onSubmit {
                    onSearchSubmitted?(searchText)
                }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        onSearchChanged?("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .responsiveFontSize(16)
                    }
                    .accessibleButton("Clear search")
                }
            }
            .responsiveHorizontalSpacing(12)
            .responsiveSpacing(8)
            .background(Color(.systemGray6))
            .responsiveCornerRadius(10)
            
            if isSearching {
                Button("Cancel") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        searchText = ""
                        isSearching = false
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        onSearchChanged?("")
                    }
                }
                .responsiveFont(.body)
                .foregroundColor(.blue)
                .transition(.move(edge: .trailing))
                .accessibleButton("Cancel search")
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearching)
    }
}

// MARK: - Search Bar with Filters

struct SearchBarWithFiltersView: View {
    @Binding var searchQuery: SearchQuery
    @State private var showingFilters = false
    
    var onSearchChanged: ((SearchQuery) -> Void)?
    var onSearchSubmitted: ((SearchQuery) -> Void)?
    
    var body: some View {
        ResponsiveVStack(spacing: 8) {
            HStack {
                SearchBarView(
                    searchText: $searchQuery.text,
                    onSearchChanged: { newText in
                        searchQuery.text = newText
                        onSearchChanged?(searchQuery)
                    },
                    onSearchSubmitted: { _ in
                        onSearchSubmitted?(searchQuery)
                    }
                )
                
                Button(action: {
                    showingFilters = true
                }) {
                    ResponsiveHStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        if searchQuery.filters.hasActiveFilters {
                            Text("\(searchQuery.filters.activeFilterCount)")
                                .responsiveFont(.caption)
                                .foregroundColor(.white)
                                .responsiveHorizontalSpacing(6)
                                .responsiveSpacing(2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }
                .foregroundColor(.primary)
                .responsiveHorizontalSpacing(12)
                .responsiveSpacing(8)
                .background(Color(.systemGray6))
                .responsiveCornerRadius(10)
                .accessibleButton("Open filters")
            }
            
            if searchQuery.filters.hasActiveFilters {
                ActiveFiltersView(filters: $searchQuery.filters) {
                    onSearchChanged?(searchQuery)
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            SearchFiltersSheet(filters: $searchQuery.filters)
                .onDisappear {
                    // Save filters when sheet is dismissed
                    SearchService.shared.saveFilters(searchQuery.filters)
                    onSearchChanged?(searchQuery)
                }
        }
    }
}

// MARK: - Active Filters Display

struct ActiveFiltersView: View {
    @Binding var filters: SearchFilters
    var onFiltersChanged: (() -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let category = filters.category {
                    FilterChip(title: "Category: \(category)", onRemove: {
                        filters.category = nil
                        onFiltersChanged?()
                    })
                }
                
                if let intent = filters.intent {
                    FilterChip(title: "Type: \(intent.rawValue.capitalized)", onRemove: {
                        filters.intent = nil
                        onFiltersChanged?()
                    })
                }
                
                if let priceRange = filters.priceRange {
                    let priceText = formatPriceRange(priceRange)
                    FilterChip(title: "Price: \(priceText)", onRemove: {
                        filters.priceRange = nil
                        onFiltersChanged?()
                    })
                }
                
                if let location = filters.location {
                    FilterChip(title: "Location: \(location.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)", onRemove: {
                        filters.location = nil
                        onFiltersChanged?()
                    })
                }
                
                if let listingType = filters.listingType {
                    FilterChip(title: "Type: \(listingType.rawValue.capitalized)", onRemove: {
                        filters.listingType = nil
                        onFiltersChanged?()
                    })
                }
                
                if let minTrustScore = filters.minTrustScore {
                    FilterChip(title: "Trust: \(minTrustScore)+", onRemove: {
                        filters.minTrustScore = nil
                        onFiltersChanged?()
                    })
                }
                
                if filters.hasActiveFilters {
                    Button("Clear All") {
                        filters = SearchFilters()
                        onFiltersChanged?()
                    }
                    .responsiveFont(.caption)
                    .foregroundColor(.red)
                    .responsiveHorizontalSpacing(8)
                    .responsiveSpacing(4)
                    .background(Color.red.opacity(0.1))
                    .responsiveCornerRadius(6)
                }
            }
            .responsiveHorizontalSpacing(16)
        }
    }
    
    private func formatPriceRange(_ range: PriceRange) -> String {
        switch (range.min, range.max) {
        case let (min?, max?):
            return "$\(Int(min))-$\(Int(max))"
        case let (min?, nil):
            return "$\(Int(min))+"
        case let (nil, max?):
            return "Up to $\(Int(max))"
        default:
            return "Any price"
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .responsiveFont(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .responsiveFont(.caption)
            }
        }
        .responsiveHorizontalSpacing(8)
        .responsiveSpacing(4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .responsiveCornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SearchBarView(searchText: .constant("")) { _ in }
        
        SearchBarWithFiltersView(searchQuery: .constant(SearchQuery())) { _ in }
        
        let filtersWithData = SearchFilters(
            category: "Electronics",
            intent: .offer,
            priceRange: PriceRange(min: 10, max: 100)
        )
        ActiveFiltersView(filters: .constant(filtersWithData))
    }
    .padding()
}
