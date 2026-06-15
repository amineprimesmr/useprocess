import SwiftUI

enum ProcessColors {
    static let primary = Color(red: 0.243, green: 0.510, blue: 0.510)
    static let primaryDark = Color(red: 0.180, green: 0.420, blue: 0.420)
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let border = Color(.separator)
    static let emergency = Color.red
    static let success = Color.green
}

extension Color {
    static let processPrimary = ProcessColors.primary
    static let processPrimaryDark = ProcessColors.primaryDark
}
