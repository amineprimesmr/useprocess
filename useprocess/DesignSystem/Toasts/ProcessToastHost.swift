import SwiftUI

extension View {
    /// Hôte global des toasts empilés — au-dessus du contenu, au-dessus de la tab bar.
    func processStackedToasts(bottomInset: CGFloat = ProcessIGTabMetrics.tabBarOverlayClearance + 6) -> some View {
        modifier(ProcessStackedToastsHostModifier(bottomInset: bottomInset))
    }
}

private struct ProcessStackedToastsHostModifier: ViewModifier {
    var bottomInset: CGFloat
    @Bindable private var toastCenter = ProcessToastCenter.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                ProcessStackedToasts(toasts: $toastCenter.toasts)
                    .padding(.bottom, bottomInset)
            }
    }
}
