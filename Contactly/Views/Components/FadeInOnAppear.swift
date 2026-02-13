import SwiftUI

struct FadeInOnAppear: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0.9)
            .onAppear {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func fadeInOnAppear() -> some View {
        modifier(FadeInOnAppear())
    }
}

