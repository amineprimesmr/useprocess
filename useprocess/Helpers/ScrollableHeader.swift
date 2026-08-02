import SwiftUI

extension View {
    /// Scroll principal — track le collapse Instagram-style de la tab bar flottante.
    func processMainScrollableChrome<ScrollContent: View>(
        selectedSection: Binding<ProcessMainSection>,
        pageSection: ProcessMainSection,
        dismissesKeyboard: ScrollDismissesKeyboardMode? = nil,
        scrollDisabled: Bool = false,
        adoptsFloatingTabBar: Bool = true,
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
                .modifier(ProcessFloatingTabBarScrollAdoption(enabled: adoptsFloatingTabBar))
            } else {
                ScrollView {
                    content()
                }
                .scrollDisabled(scrollDisabled)
                .processTransparentScrollSurface()
                .modifier(ProcessFloatingTabBarScrollAdoption(enabled: adoptsFloatingTabBar))
            }
        }
        .coordinateSpace(name: "processMainScroll")
        .scrollIndicators(.hidden)
    }
}

private struct ProcessFloatingTabBarScrollAdoption: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.processAdoptForIGTabBar()
        } else {
            content
        }
    }
}
