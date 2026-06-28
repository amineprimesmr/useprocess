import SwiftUI

extension View {
    /// Scroll principal sans chrome custom: la navigation globale est assurée par la tab bar native.
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
                    scrollTrackedContent(content())
                }
                .scrollDisabled(scrollDisabled)
                .scrollDismissesKeyboard(dismissesKeyboard)
                .processTransparentScrollSurface()
            } else {
                ScrollView {
                    scrollTrackedContent(content())
                }
                .scrollDisabled(scrollDisabled)
                .processTransparentScrollSurface()
            }
        }
        .coordinateSpace(name: "processMainScroll")
        .scrollIndicators(.hidden)
    }

    private func scrollTrackedContent<ScrollContent: View>(_ content: ScrollContent) -> some View {
        content.processReportsTabBarScrollOffset()
    }
}
