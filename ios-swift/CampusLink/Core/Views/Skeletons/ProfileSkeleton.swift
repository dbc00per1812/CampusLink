import SwiftUI

struct ProfileSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture Skeleton
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 100, height: 100)
                .shimmer(isAnimating: $isAnimating)
            
            // Name Skeleton
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 150, height: 24)
                .cornerRadius(4)
                .shimmer(isAnimating: $isAnimating)
            
            // Bio Skeleton (2 lines)
            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 250, height: 16)
                    .cornerRadius(4)
                    .shimmer(isAnimating: $isAnimating)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 200, height: 16)
                    .cornerRadius(4)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            // University info skeleton
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .shimmer(isAnimating: $isAnimating)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 140, height: 16)
                    .cornerRadius(4)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            // Edit Profile Button Skeleton
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .cornerRadius(8)
                .padding(.horizontal, 40)
                .shimmer(isAnimating: $isAnimating)
        }
        .padding(20)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ProfileListingsSkeleton: View {
    var count: Int = 3
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { _ in
                HStack(spacing: 12) {
                    // Listing image placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .shimmer(isAnimating: $isAnimating)
                    
                    // Listing info
                    VStack(alignment: .leading, spacing: 6) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 18)
                            .cornerRadius(4)
                            .shimmer(isAnimating: $isAnimating)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 16)
                            .cornerRadius(4)
                            .shimmer(isAnimating: $isAnimating)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 90, height: 14)
                            .cornerRadius(4)
                            .shimmer(isAnimating: $isAnimating)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ScrollView {
        VStack {
            ProfileSkeleton()
            Divider()
            ProfileListingsSkeleton()
        }
    }
}

