import SwiftUI
import UIKit

extension Color {
    // MARK: - Brand colours (same in both modes)
    static let ironiqOrange = Color(hex: "E8680A")
    static let ironiqGreen  = Color(hex: "2D7D4A")
    static let ironiqRed    = Color(hex: "E53E3E")

    // MARK: - Adaptive dark background
    // Dark mode: near-black #1A1A1A
    // Light mode: near-white #F2F2F2
    static let ironiqDark = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1)  // #1A1A1A
            : UIColor(red: 0.949, green: 0.949, blue: 0.949, alpha: 1)  // #F2F2F2
    })

    // MARK: - Surface colour (cards, rows)
    static let ironiqSurface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 0.12, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    })

    // MARK: - Hex initialiser
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
