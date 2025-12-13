import SwiftUI

struct TransactionRowSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Title placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 180, height: 18)
                        .cornerRadius(4)
                        .shimmer(isAnimating: $isAnimating)
                    
                    // Price placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 16)
                        .cornerRadius(4)
                        .shimmer(isAnimating: $isAnimating)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Status badge placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 90, height: 24)
                        .cornerRadius(8)
                        .shimmer(isAnimating: $isAnimating)
                    
                    // Date placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 70, height: 12)
                        .cornerRadius(4)
                        .shimmer(isAnimating: $isAnimating)
                }
            }
            
            // Badges row placeholder
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 20)
                    .cornerRadius(6)
                    .shimmer(isAnimating: $isAnimating)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 20)
                    .cornerRadius(6)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            // Action buttons placeholder
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 130, height: 32)
                    .cornerRadius(8)
                    .shimmer(isAnimating: $isAnimating)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 32)
                    .cornerRadius(8)
                    .shimmer(isAnimating: $isAnimating)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            isAnimating = true
        }
    }
}

struct TransactionListSkeleton: View {
    var count: Int = 5
    
    var body: some View {
        List {
            ForEach(0..<count, id: \.self) { _ in
                TransactionRowSkeleton()
            }
        }
        .listStyle(PlainListStyle())
    }
}

#Preview {
    TransactionListSkeleton()
}

