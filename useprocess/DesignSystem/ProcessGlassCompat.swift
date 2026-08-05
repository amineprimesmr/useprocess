import SwiftUI

extension View {
    /// Glass passif (barre de saisie, panneaux) — pas de feedback press.
    @ViewBuilder
    func processGlassEffect(in shape: some InsettableShape, interactive: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(interactive ? ProcessGlass.regular : ProcessGlass.regularSurface, in: shape)
                .overlay {
                    ProcessGlassLightStroke(shape: shape)
                }
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                .overlay {
                    ProcessGlassLightStroke(shape: shape)
                }
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
    ///
    /// Le glass est appliqué en `.background` (comme les cartes Accueil), pas seulement via
    /// `ButtonStyle` : un `.buttonStyle(.processPlain)` voisin ne peut plus le faire disparaître.
    func processGlassButton(in shape: some InsettableShape, interactive: Bool = true) -> some View {
        buttonStyle(ProcessGlassLabelButtonStyle(shape: shape))
            .background {
                shape
                    .fill(.clear)
                    .processGlassEffect(in: shape, interactive: interactive)
            }
    }

    /// Étend la zone cliquable au label entier (pas seulement le texte) pour `.buttonStyle(.plain)`.
    @ViewBuilder
    func processTappableButtonLabel<S: Shape>(
        in shape: S = Rectangle(),
        maxWidth: Bool = false,
        alignment: Alignment = .center
    ) -> some View {
        if maxWidth {
            frame(maxWidth: .infinity, alignment: alignment)
                .contentShape(shape)
        } else {
            contentShape(shape)
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

private struct ProcessGlassLabelButtonStyle<S: InsettableShape>: ButtonStyle {
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

private struct ProcessGlassLightStroke<S: InsettableShape>: View {
    @Environment(\.appTheme) private var theme
    let shape: S

    var body: some View {
        if !theme.isDark {
            shape.strokeBorder(theme.coachSurfaceStroke.opacity(0.72), lineWidth: 0.75)
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
