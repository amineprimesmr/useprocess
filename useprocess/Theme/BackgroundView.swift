import SwiftUI

/// Fond uni — sans dégradé ni glow.
struct BackgroundView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        theme.background
            .ignoresSafeArea()
    }
}
