import SwiftUI

struct ListingCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Square image placeholder at top
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .shimmer(isAnimating: $isAnimating)
            
            // Price and title placeholders
            VStack(alignment: .leading, spacing: 6) {
                // Price placeholder - large
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 20)
                    .cornerRadius(4)
                    .shimmer(isAnimating: $isAnimating)
                
                // Title placeholder - medium
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 16)
                    .cornerRadius(4)
                    .shimmer(isAnimating: $isAnimating)
                
                // Second line of title
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 16)
                    .cornerRadius(4)
                    .shimmer(isAnimating: $isAnimating)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Grid of Skeletons for Home Feed
struct ListingGridSkeleton: View {
    var count: Int = 6
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                ListingCardSkeleton()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

#Preview {
    ScrollView {
        ListingGridSkeleton()
    }
}

