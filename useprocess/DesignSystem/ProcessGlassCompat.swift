import SwiftUI

extension View {
    /// Glass passif (barre de saisie, panneaux) — pas de feedback press.
    @ViewBuilder
    func processGlassEffect(in shape: some InsettableShape, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(interactive ? ProcessGlass.regular : ProcessGlass.regularSurface, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func processGlassCircle(interactive: Bool = true) -> some View {
        processGlassEffect(in: Circle(), interactive: interactive)
    }

    @ViewBuilder
    func processInvertedGlassEffect(in shape: some InsettableShape) -> some View {
        modifier(ProcessInvertedGlassModifier(shape: shape))
    }

    /// Bouton circulaire — iOS 26 : style système `.glass` (press natif). Pré-26 : glassEffect manuel.
    @ViewBuilder
    func processNativeGlassCircleButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            buttonStyle(.plain)
                .processGlassEffect(in: Circle())
                .buttonStyle(ProcessGlassPressStyle())
        }
    }

    /// Bouton liquid glass — capsules / formes custom (pre-26 + surfaces non-button).
    @ViewBuilder
    func processGlassButton(in shape: some InsettableShape, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.plain)
                .processGlassEffect(in: shape, interactive: interactive)
        } else {
            buttonStyle(.plain)
                .processGlassEffect(in: shape, interactive: interactive)
                .buttonStyle(ProcessGlassPressStyle())
        }
    }

    /// Ombre des cartes glass Accueil — en clair le dégradé rend une drop shadow trop marquée.
    @ViewBuilder
    func processHomeGlassCardShadow(isDark: Bool) -> some View {
        if isDark {
            shadow(color: .black.opacity(0.24), radius: 12, y: 5)
        } else {
            self
        }
    }

    /// Icône circulaire seule.
    @ViewBuilder
    func processGlassIconButtonStyle() -> some View {
        processNativeGlassCircleButtonStyle()
    }

    /// Icône circulaire dans une barre glass (envoyer, micro…).
    @ViewBuilder
    func processGlassNestedIconButtonStyle() -> some View {
        processNativeGlassCircleButtonStyle()
    }

    /// Ligne tappable dans un popover.
    @ViewBuilder
    func processGlassMenuRowStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.plain)
                .processGlassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous), interactive: true)
        } else {
            buttonStyle(ProcessGlassPressStyle())
        }
    }
}

private struct ProcessInvertedGlassModifier<S: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let shape: S

    private var fill: Color {
        colorScheme == .dark ? .white : .black
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.plain)
                .glassEffect(ProcessGlass.filterSelected(fill), in: shape)
        } else {
            content
                .buttonStyle(.plain)
                .background(shape.fill(fill))
                .buttonStyle(ProcessGlassPressStyle())
        }
    }
}
