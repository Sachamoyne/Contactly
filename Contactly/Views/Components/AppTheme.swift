import SwiftUI
import UIKit

enum AppTheme {
    static let spacingSmall: CGFloat = 12
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24

    static let cornerRadius: CGFloat = 22
    static let heroCornerRadius: CGFloat = 24

    static let accent = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.31, green: 0.48, blue: 0.98, alpha: 1.0)
            }
            return UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 1.0)
        }
    )

    static let tintBackground = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.20, green: 0.30, blue: 0.55, alpha: 0.28)
            }
            return UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 0.08)
        }
    )

    static let chipBackground = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.19, green: 0.31, blue: 0.62, alpha: 0.35)
            }
            return UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 0.12)
        }
    )
}

