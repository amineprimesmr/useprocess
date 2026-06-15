//
//  Color+Extensions.swift
//  Process
//
//  Created by Assistant on 22/09/2025.
//

import SwiftUI

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func interpolated(to target: Color, amount: Double) -> Color {
        let amount = max(0, min(1, amount))

        let startComponents = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let targetComponents = UIColor(target).cgColor.components ?? [0, 0, 0, 1]

        let r = startComponents[0] + (targetComponents[0] - startComponents[0]) * amount
        let g = startComponents[1] + (targetComponents[1] - startComponents[1]) * amount
        let b = startComponents[2] + (targetComponents[2] - startComponents[2]) * amount
        let a = startComponents[3] + (targetComponents[3] - startComponents[3]) * amount

        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
