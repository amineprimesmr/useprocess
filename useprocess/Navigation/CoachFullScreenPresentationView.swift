import SwiftUI
import UIKit

/// Présentation plein écran du coach — sans tab bar, fermeture via la croix.
struct CoachFullScreenPresentationView: View {
    @Binding var selectedSection: ProcessMainSection
    let viewModel: CoachChatViewModel
    var onDismiss: () -> Void
    var onOpenProfile: () -> Void
    var onOpenWelcomePlan: () -> Void

    var body: some View {
        CoachChatView(
            selectedSection: $selectedSection,
            viewModel: viewModel,
            onDismiss: onDismiss,
            onOpenProfile: onOpenProfile,
            onOpenWelcomePlan: onOpenWelcomePlan
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .processScreenBackground()
        .onAppear {
            ProcessPerformanceTrace.endCoachOpen()
        }
    }
}
