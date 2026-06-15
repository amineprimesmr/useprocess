import SwiftUI

private struct GlassFallbackStyle: ButtonStyle {
    @Environment(\.appTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 50))
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(theme.cardStroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension View {
    @ViewBuilder
    func glassStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(GlassFallbackStyle())
        }
    }
}
