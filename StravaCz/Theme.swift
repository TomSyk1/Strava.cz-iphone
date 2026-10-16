import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

/// Fialová paleta podle původní Android verze (Material 3 baseline).
enum Theme {
    static let primary = Color(light: 0x6650A4, dark: 0xD0BCFF)
    static let onPrimary = Color(light: 0xFFFFFF, dark: 0x381E72)
    static let primaryContainer = Color(light: 0xEADDFF, dark: 0x4F378B)
    static let onPrimaryContainer = Color(light: 0x21005D, dark: 0xEADDFF)
    static let background = Color(light: 0xFEF7FF, dark: 0x141218)
    static let card = Color(light: 0xE6E0E9, dark: 0x36343B)
    static let field = Color(light: 0xF3EDF7, dark: 0x211F26)
    static let onSurfaceVariant = Color(light: 0x49454F, dark: 0xCAC4D0)
    static let outline = Color(light: 0x79747E, dark: 0x938F99)
    static let error = Color(light: 0xB3261E, dark: 0xF2B8B5)
    static let errorContainer = Color(light: 0xF9DEDC, dark: 0x8C1D18)
    static let onErrorContainer = Color(light: 0x410E0B, dark: 0xF9DEDC)
}
