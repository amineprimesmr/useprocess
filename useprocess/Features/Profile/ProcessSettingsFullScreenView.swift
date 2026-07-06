import AuthenticationServices
import SwiftUI

/// Paramètres — présentation plein écran (zoom depuis l'accueil).
struct ProcessSettingsFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared

    @State private var pendingAccountConfirmation: AccountConfirmation?

    var body: some View {
        NavigationStack {
            EditProfileView(
                onLogout: { pendingAccountConfirmation = .logout }
            )
            .navigationDestination(for: ProfileEditDestination.self) { destination in
                profileFieldEditor(for: destination)
            }
            .navigationDestination(for: ProfileSettingsCategory.self) { category in
                profileSettingsDetail(for: category)
                    .environment(\.profileAccountDeletionHandler) {
                        Task { @MainActor in
                            dismiss()
                            try? await Task.sleep(for: .milliseconds(450))
                            await performAccountDeletion()
                        }
                    }
            }
        }
        .processTranslucentOverlayBackground()
        .processAppPresentationBackground()
        .environmentObject(profileService)
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(healthManager)
        .alert(
            "Se déconnecter ?",
            isPresented: Binding(
                get: { pendingAccountConfirmation == .logout },
                set: { if !$0 { pendingAccountConfirmation = nil } }
            )
        ) {
            Button("Se déconnecter", role: .destructive) {
                pendingAccountConfirmation = nil
                AuthenticationManager.shared.signOut()
                dismiss()
            }
            Button("Annuler", role: .cancel) {
                pendingAccountConfirmation = nil
            }
        } message: {
            Text("Tu pourras te reconnecter à tout moment.")
        }
    }

    private func performAccountDeletion() async {
        session.accountDeletionErrorMessage = nil

        do {
            try await session.deleteAccount()
        } catch let error as AccountDeletionError {
            if case .cancelled = error { return }
            session.accountDeletionErrorMessage = error.localizedDescription
        } catch {
            session.accountDeletionErrorMessage = error.localizedDescription
        }
    }
}
