import AuthenticationServices
import SwiftUI

/// Marqueur de navigation — hub Paramètres poussé depuis l’onglet Profil.
struct ProfileSettingsHubMarker: Hashable {}

/// Destinations Paramètres — une seule registration par `NavigationStack` (évite les boucles push).
extension View {
    @ViewBuilder
    func profileSettingsStackDestinations(
        accountDeletion: @escaping () -> Void
    ) -> some View {
        navigationDestination(for: ProfileSettingsHubMarker.self) { _ in
            ProcessSettingsHubView()
                .environment(\.profileAccountDeletionHandler, accountDeletion)
        }
        .navigationDestination(for: ProfileSettingsCategory.self) { category in
            profileSettingsDetail(for: category)
                .reportsProfileSubrouteActive(true)
                .environment(\.profileAccountDeletionHandler, accountDeletion)
        }
        .navigationDestination(for: ProfileEditDestination.self) { destination in
            profileFieldEditor(for: destination)
                .reportsProfileSubrouteActive(true)
        }
    }
}

/// Hub réglages — navigation push dans l’onglet Profil (tab bar visible).
struct ProcessSettingsHubView: View {
    @Bindable private var session = AppSession.shared

    var body: some View {
        EditProfileView(showsDismissHeader: true)
            .reportsProfileSubrouteActive(true)
            .environment(\.profileAccountDeletionHandler) {
                session.enqueueAccountDeletionFromUI()
            }
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
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProcessProfileHomeView(
                selectedSection: $selectedSection,
                isTabActive: isTabActive,
                isOnboardingPreview: isOnboardingPreview,
                onOpenSettings: {
                    navigationPath.append(ProfileSettingsHubMarker())
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbarBackground(.hidden, for: .navigationBar)
            .processClearUIKitHostingBackground()
            .profileSettingsStackDestinations {
                session.enqueueAccountDeletionFromUI()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .processClearUIKitHostingBackground()
    }
}
