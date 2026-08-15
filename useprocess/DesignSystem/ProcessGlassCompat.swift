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
    /// `.buttonSizing(.fitted)` : le chrome épouse le frame du label (sans le padding `.glass` par défaut).
    @ViewBuilder
    func processNativeGlassCircleButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .buttonSizing(.fitted)
        } else {
            buttonStyle(.plain)
                .processGlassEffect(in: Circle())
                .buttonStyle(ProcessGlassPressStyle())
        }
    }

    /// Surface tappable type carte Accueil.
    /// Clip le contenu d’abord, puis pose le glass interactif — jamais l’inverse :
    /// un `clipShape` après le glass coupe le press natif iOS 26.
    func processInteractiveGlassSurface(
        in shape: some InsettableShape,
        interactive: Bool = true
    ) -> some View {
        clipShape(shape)
            .contentShape(shape)
            .processGlassEffect(in: shape, interactive: interactive)
    }

    /// Bouton liquid glass.
    /// iOS 26 : `.buttonStyle(.glass)` — press natif qui **grossit** le bouton.
    /// Avant : glassEffect + scale manuel.
    func processGlassButton(in shape: some InsettableShape, interactive: Bool = true) -> some View {
        modifier(ProcessGlassButtonModifier(shape: shape, interactive: interactive))
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
        processGlassButton(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProcessGlassButtonModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    var interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), interactive {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(Self.borderShape(for: shape))
                .buttonSizing(.fitted)
        } else {
            content.buttonStyle(ProcessGlassLabelButtonStyle(shape: shape, interactive: interactive))
        }
    }

    @available(iOS 26.0, *)
    private static func borderShape(for shape: S) -> ButtonBorderShape {
        if shape is Circle {
            return .circle
        }
        if shape is Capsule {
            return .capsule
        }
        if let rounded = shape as? RoundedRectangle {
            let radius = min(rounded.cornerSize.width, rounded.cornerSize.height)
            return .roundedRectangle(radius: radius)
        }
        return .automatic
    }
}

private struct ProcessGlassLabelButtonStyle<S: InsettableShape>: ButtonStyle {
    let shape: S
    var interactive: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(shape)
            .processGlassEffect(in: shape, interactive: interactive)
            .modifier(
                ProcessNativeOrManualPressScale(
                    isPressed: configuration.isPressed,
                    usesNativeInteractiveGlass: interactive
                )
            )
    }
}

/// iOS 26 + glass `.interactive()` : le système gère déjà le press.
/// Sinon : scale manuel (pre-26, ou glass passif).
private struct ProcessNativeOrManualPressScale: ViewModifier {
    let isPressed: Bool
    let usesNativeInteractiveGlass: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), usesNativeInteractiveGlass {
            content
        } else {
            content.processButtonPressScale(isPressed: isPressed)
        }
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
