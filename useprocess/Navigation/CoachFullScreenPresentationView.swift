import SwiftUI
import UIKit

/// Présentation plein écran du coach — sans tab bar, fermeture via la croix.
struct CoachFullScreenPresentationView: View {
    @Binding var selectedSection: ProcessMainSection
    var onDismiss: () -> Void
    var onOpenProfile: () -> Void
    var onOpenWelcomePlan: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var showsCloseButton = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CoachChatView(
                selectedSection: $selectedSection,
                onOpenProfile: onOpenProfile,
                onOpenWelcomePlan: onOpenWelcomePlan
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            closeButton
                .padding(.top, ProcessMainChromeMetrics.topSafeInset + 2)
                .padding(.trailing, 18)
                .opacity(showsCloseButton ? 1 : 0)
                .offset(y: showsCloseButton ? 0 : -6)
                .animation(.spring(response: 0.4, dampingFraction: 0.86).delay(0.07), value: showsCloseButton)
        }
        .processScreenBackground()
        .ignoresSafeArea(edges: .top)
        .onAppear {
            showsCloseButton = true
        }
    }

    private var closeButton: some View {
        ProcessGlassIconButton(systemName: "xmark", size: 34, iconSize: 13) {
            HapticManager.shared.impact(.light)
            dismissCoachKeyboard()
            onDismiss()
        }
        .accessibilityLabel("Fermer le coach")
    }

    private func dismissCoachKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
