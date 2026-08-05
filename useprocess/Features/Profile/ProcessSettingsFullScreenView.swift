import AuthenticationServices
import SwiftUI

/// Réglages — présentation plein écran (depuis l'accueil).
struct ProcessSettingsFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared

    @State private var pendingAccountConfirmation: AccountConfirmation?

    var body: some View {
        NavigationStack {
            EditProfileView(
                showsDismissHeader: true,
                onLogout: { pendingAccountConfirmation = .logout }
            )
            .navigationDestination(for: ProfileEditDestination.self) { destination in
                profileFieldEditor(for: destination)
                    .reportsProfileSubrouteActive(true)
            }
            .navigationDestination(for: ProfileSettingsCategory.self) { category in
                profileSettingsDetail(for: category)
                    .reportsProfileSubrouteActive(true)
                    .environment(\.profileAccountDeletionHandler) {
                        Task { @MainActor in
                            session.beginAccountDeletion()
                            dismiss()
                            try? await Task.sleep(for: .milliseconds(280))
                            await session.performAccountDeletionFromUI()
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
            AppCopy.t("Se déconnecter ?", en: "Log Out?"),
            isPresented: Binding(
                get: { pendingAccountConfirmation == .logout },
                set: { if !$0 { pendingAccountConfirmation = nil } }
            )
        ) {
            Button(AppCopy.t("Se déconnecter", en: "Log Out"), role: .destructive) {
                pendingAccountConfirmation = nil
                AuthenticationManager.shared.signOut()
                dismiss()
            }
            Button(AppCopy.cancel, role: .cancel) {
                pendingAccountConfirmation = nil
            }
        } message: {
            Text(AppCopy.t("Tu pourras te reconnecter à tout moment.", en: "You can log back in at any time."))
        }
    }
}

/// Onglet Réglages — premier scan + hub paramètres.
struct ProcessProfileSettingsTabView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true

    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared

    @State private var pendingAccountConfirmation: AccountConfirmation?

    var body: some View {
        NavigationStack {
            ProcessProfileHomeView(
                selectedSection: $selectedSection,
                isTabActive: isTabActive,
                onLogout: { pendingAccountConfirmation = .logout }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbarBackground(.hidden, for: .navigationBar)
            .processClearUIKitHostingBackground()
            .navigationDestination(for: ProfileEditDestination.self) { destination in
                profileFieldEditor(for: destination)
                    .reportsProfileSubrouteActive(true)
            }
            .navigationDestination(for: ProfileSettingsCategory.self) { category in
                profileSettingsDetail(for: category)
                    .reportsProfileSubrouteActive(true)
                    .environment(\.profileAccountDeletionHandler) {
                        Task { @MainActor in
                            await session.performAccountDeletionFromUI()
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .processClearUIKitHostingBackground()
        .alert(
            AppCopy.t("Se déconnecter ?", en: "Log Out?"),
            isPresented: Binding(
                get: { pendingAccountConfirmation == .logout },
                set: { if !$0 { pendingAccountConfirmation = nil } }
            )
        ) {
            Button(AppCopy.t("Se déconnecter", en: "Log Out"), role: .destructive) {
                pendingAccountConfirmation = nil
                AuthenticationManager.shared.signOut()
            }
            Button(AppCopy.cancel, role: .cancel) {
                pendingAccountConfirmation = nil
            }
        } message: {
            Text(AppCopy.t("Tu pourras te reconnecter à tout moment.", en: "You can log back in at any time."))
        }
    }
}
