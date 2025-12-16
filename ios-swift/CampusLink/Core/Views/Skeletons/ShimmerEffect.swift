import SwiftUI

// MARK: - Shimmer Effect Modifier
struct ShimmerEffect: ViewModifier {
    @Binding var isAnimating: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: phase
                    )
                }
            )
            .onAppear {
                if isAnimating {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(isAnimating: Binding<Bool>) -> some View {
        modifier(ShimmerEffect(isAnimating: isAnimating))
    }
}

