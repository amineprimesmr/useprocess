import SwiftUI

extension View {
    @ViewBuilder
    func processGlassEffect(in shape: some InsettableShape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(ProcessGlass.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    /// Liquid glass inversé : fond blanc en dark, fond noir en clair.
    @ViewBuilder
    func processInvertedGlassEffect(in shape: some InsettableShape) -> some View {
        modifier(ProcessInvertedGlassModifier(shape: shape))
    }

    @ViewBuilder
    func processGlassCircle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(ProcessGlass.regular, in: .circle)
        } else {
            background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
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
        content.background {
            if #available(iOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(ProcessGlass.filterSelected(fill), in: shape)
            } else {
                shape.fill(fill)
            }
        }
    }
}
