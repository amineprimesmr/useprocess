import SwiftUI

enum ProcessCoachZoomTransition {
    static let sourceID = "PROCESS_COACH"
}

/// Style bouton source — glass + matchedTransitionSource + haptique (pattern FluidZoom).
struct ProcessFluidZoomButtonStyle<S: InsettableShape>: ButtonStyle {
    let id: String
    let namespace: Namespace.ID
    let shape: S
    var usesGlass: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        ProcessFluidZoomButtonStyleBody(
            id: id,
            namespace: namespace,
            shape: shape,
            usesGlass: usesGlass,
            configuration: configuration
        )
    }
}

private struct ProcessFluidZoomButtonStyleBody<S: InsettableShape>: View {
    let id: String
    let namespace: Namespace.ID
    let shape: S
    let usesGlass: Bool
    let configuration: ButtonStyleConfiguration

    var body: some View {
        Group {
            if usesGlass {
                configuration.label
                    .modifier(ProcessFluidZoomGlassModifier(shape: shape))
            } else {
                configuration.label
            }
        }
        .matchedTransitionSource(id: id, in: namespace)
    }
}

private struct ProcessFluidZoomGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regularSurface, in: shape)
        } else {
            content.processGlassEffect(in: shape, interactive: false)
        }
    }
}

extension View {
    @ViewBuilder
    func processCoachZoomTransition(namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: ProcessCoachZoomTransition.sourceID, in: namespace))
        } else {
            self
        }
    }
}
