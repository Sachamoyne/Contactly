import SwiftUI

struct CardContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(AppTheme.spacingMedium)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(AppTheme.cardBackground)
            )
            .fadeInOnAppear()
    }
}
