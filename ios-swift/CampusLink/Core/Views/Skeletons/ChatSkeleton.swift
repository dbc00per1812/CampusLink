import SwiftUI

struct MessageBubbleSkeleton: View {
    let isCurrentUser: Bool
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message bubble placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: CGFloat.random(in: 150...250), height: 60)
                    .cornerRadius(16)
                    .shimmer(isAnimating: $isAnimating)
                
                // Timestamp placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 12)
                    .cornerRadius(4)
                    .shimmer(isAnimating: $isAnimating)
            }
            
            if !isCurrentUser { Spacer() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ChatSkeleton: View {
    var messageCount: Int = 8
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(0..<messageCount, id: \.self) { index in
                    MessageBubbleSkeleton(isCurrentUser: index % 3 == 0)
                }
            }
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    ChatSkeleton()
}

