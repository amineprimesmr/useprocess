//
//  ProcessMossTheme.swift
//  useprocess
//
//  Adaptation du design system Moss pour l'onboarding Process.
//  Source: https://github.com/imranhsni/mossonboardingchat
//

import SwiftUI

/// Sous-ensemble de `Theme` Moss — couleurs, typo et espacements pour le chat conversationnel.
enum Theme {
    static let margin: CGFloat = 18

    static var ink: Color { OnboardingTheme.primaryText }
    static var ink2: Color { OnboardingTheme.bodyText }
    static var inkFine: Color { OnboardingTheme.mutedText }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Fonts {
        static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight)
        }

        static func serif(_ size: CGFloat) -> Font {
            let weight: Font.Weight = switch size {
            case 40...: .thin
            case 24..<40: .light
            default: .regular
            }
            return .system(size: size, weight: weight)
        }
    }
}

extension Color {
    /// Hex Moss (UInt32) — surcharge de `init(hex: String)`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
