import SwiftUI

extension View {
    /// Scroll principal — track le collapse Instagram-style de la tab bar flottante.
    func processMainScrollableChrome<ScrollContent: View>(
        selectedSection: Binding<ProcessMainSection>,
        pageSection: ProcessMainSection,
        dismissesKeyboard: ScrollDismissesKeyboardMode? = nil,
        scrollDisabled: Bool = false,
        @ViewBuilder content: @escaping () -> ScrollContent
    ) -> some View {
        Group {
            if let dismissesKeyboard {
                ScrollView {
                    content()
                }
                .scrollDisabled(scrollDisabled)
                .scrollDismissesKeyboard(dismissesKeyboard)
                .processTransparentScrollSurface()
                .processAdoptForIGTabBar()
            } else {
                ScrollView {
                    content()
                }
                .scrollDisabled(scrollDisabled)
                .processTransparentScrollSurface()
                .processAdoptForIGTabBar()
            }
        }
        .coordinateSpace(name: "processMainScroll")
        .scrollIndicators(.hidden)
    }
}
