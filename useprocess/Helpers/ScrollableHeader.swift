import SwiftUI

extension View {
    /// Scroll sous le menu sticky fixe (MainAppView) — inset haut constant.
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
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear
                .frame(height: ProcessMainChromeMetrics.scrollTopInset)
                .allowsHitTesting(false)
        }
    }

    /// Profil : hero edge-to-edge derrière le menu sticky + status bar.
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
