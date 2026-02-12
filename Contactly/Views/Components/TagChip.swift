import SwiftUI

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.chipBackground)
            .foregroundStyle(AppTheme.accent)
            .clipShape(Capsule())
    }
}

