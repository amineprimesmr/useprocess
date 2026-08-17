import AuthenticationServices
import SwiftUI

/// Réglages — présentation plein écran (depuis l'accueil).
struct ProcessSettingsFullScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared

    var body: some View {
        NavigationStack {
            EditProfileView(showsDismissHeader: true)
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
    }
}

/// Onglet Profil — progrès, scans, insight temps.
struct ProcessProfileSettingsTabView: View {
    @Binding var selectedSection: ProcessMainSection
    var isTabActive: Bool = true
    var isOnboardingPreview: Bool = false

    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Bindable private var session = AppSession.shared
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ProcessProfileHomeView(
                selectedSection: $selectedSection,
                isTabActive: isTabActive,
                isOnboardingPreview: isOnboardingPreview,
                onOpenSettings: {
                    showsSettings = true
                }
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
        .fullScreenCover(isPresented: $showsSettings) {
            ProcessSettingsFullScreenView()
                .environmentObject(profileService)
                .environmentObject(healthManager)
        }
    }
}
