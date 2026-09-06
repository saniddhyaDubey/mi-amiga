import SwiftUI

/// The app's accent color, defined in code rather than an asset catalog —
/// `actool` needs a simulator runtime installed just to compile a color set,
/// and this avoids that dependency entirely.
extension Color {
    static let miAmiga = Color(
        light: Color(red: 0.90, green: 0.31, blue: 0.40),
        dark: Color(red: 1.00, green: 0.40, blue: 0.45)
    )
}

extension Color {
    /// Picks between two colors based on the current interface style.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
