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

private struct GlassCircleFallbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

private struct GlassCapsuleFallbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func glassStyle() -> some View {
        if #available(iOS 26.0, *) {
            processGlassButton(in: Capsule())
        } else {
            buttonStyle(GlassFallbackStyle())
        }
    }

    @ViewBuilder
    func glassCircleStyle() -> some View {
        if #available(iOS 26.0, *) {
            processGlassButton(in: Circle())
        } else {
            buttonStyle(GlassCircleFallbackStyle())
        }
    }

    @ViewBuilder
    func glassCapsuleStyle() -> some View {
        if #available(iOS 26.0, *) {
            processGlassButton(in: Capsule())
        } else {
            buttonStyle(GlassCapsuleFallbackStyle())
        }
    }

    @ViewBuilder
    func glassProminentCapsuleStyle(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .tint(tint)
        } else {
            buttonStyle(.plain)
                .background(Capsule().fill(tint))
        }
    }
}
