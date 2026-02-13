import SwiftUI

struct AvatarView: View {
    let contact: Contact
    let size: CGFloat

    var body: some View {
        if let avatarPath = contact.avatarPath,
           let uiImage = UIImage(contentsOfFile: avatarPath)
        {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        } else {
            Text(contact.initials.isEmpty ? "?" : contact.initials)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [
                                AppTheme.tintBackground,
                                AppTheme.chipBackground.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 2)
        }
    }
}
