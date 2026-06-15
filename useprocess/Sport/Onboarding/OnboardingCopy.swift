import Foundation

/// Textes onboarding — toujours les libellés produit (sport).
enum OnboardingCopy {
    static func titleLines(from lines: [String]) -> [String] {
        lines.map { AppBranding.replacingProcess(in: $0) }
    }

    static func text(_ value: String, blank _: String = "") -> String {
        AppBranding.replacingProcess(in: value)
    }

    static func choiceLabel(index: Int, sport: String) -> String {
        sport
    }

    static func binaryLabels(sportFirst: String, sportSecond: String) -> (String, String) {
        (sportFirst, sportSecond)
    }

    static func placeholder(_ value: String) -> String {
        value
    }
}
