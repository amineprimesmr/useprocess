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
                    content()
                }
                .scrollDisabled(scrollDisabled)
                .scrollDismissesKeyboard(dismissesKeyboard)
            } else {
                ScrollView {
                    content()
                }
                .scrollDisabled(scrollDisabled)
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Profil : hero edge-to-edge sous la status bar native.
    func processProfileScrollableChrome<ScrollContent: View>(
        selectedSection: Binding<ProcessMainSection>,
        @ViewBuilder content: @escaping () -> ScrollContent
    ) -> some View {
        processMainScrollableChrome(
            selectedSection: selectedSection,
            pageSection: .profile
        ) {
            content()
        }
        .scrollContentBackground(.hidden)
        .scrollClipDisabled()
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }
}
