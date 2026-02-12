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
        } else {
            Text(contact.initials.isEmpty ? "?" : contact.initials)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(initialsColor))
        }
    }

    private var initialsColor: Color {
        let name = contact.fullName
        let hash = name.utf8.reduce(0) { $0 &+ Int($1) }
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        return colors[abs(hash) % colors.count]
    }
}
