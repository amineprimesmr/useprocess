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
