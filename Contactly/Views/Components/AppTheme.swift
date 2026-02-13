import SwiftUI
import UIKit

enum AppTheme {
    static let spacingXSmall: CGFloat = 8
    static let spacingSmall: CGFloat = 12
    static let spacingMedium: CGFloat = 16
    static let spacingLarge: CGFloat = 24

    static let cornerRadius: CGFloat = 20
    static let inputCornerRadius: CGFloat = 14
    static let heroCornerRadius: CGFloat = 20

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
                return UIColor(red: 0.20, green: 0.30, blue: 0.55, alpha: 0.24)
            }
            return UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 0.06)
        }
    )

    static let chipBackground = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.19, green: 0.31, blue: 0.62, alpha: 0.30)
            }
            return UIColor(red: 0.12, green: 0.23, blue: 0.54, alpha: 0.10)
        }
    )

    static let cardBackground = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor.white.withAlphaComponent(0.045)
            }
            return UIColor.black.withAlphaComponent(0.03)
        }
    )
}
