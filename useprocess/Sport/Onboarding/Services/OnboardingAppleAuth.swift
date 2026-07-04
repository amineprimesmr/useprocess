import FirebaseAuth
import Foundation

@MainActor
enum OnboardingAppleAuth {
    static func authenticateAndMigrate(
        authManager: AuthenticationManager,
        profileService: UnifiedProfileService,
        viewModel: OnboardingViewModel
    ) async throws {
        viewModel.commitPendingStepAnswers()
        viewModel.saveProgress()

        if AuthUser.current == nil {
            try await signInWithApple(
                authManager: authManager,
                profileService: profileService
            )
        } else if profileService.currentProfile == nil {
            await profileService.loadProfile()
        }

        guard let user = AuthUser.current else {
            throw AppleSignInError.invalidCredential
        }

        let coordinator = OnboardingCoordinator(
            viewModel: viewModel,
            profileService: profileService
        )
        try await coordinator.syncProfileWithViewModel()

        guard profileService.currentProfile?.userId == user.uid else {
            throw OnboardingError.notAuthenticated
        }

        await migratePendingIdentityIfNeeded(
            userId: user.uid,
            fallbackFirstName: viewModel.firstName,
            profileService: profileService
        )
    }

    static func signInWithApple(
        authManager: AuthenticationManager,
        profileService: UnifiedProfileService
    ) async throws {
        if !authManager.isInOnboarding {
            authManager.startOnboarding()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            AppleSignInManager.shared.startSignInWithAppleFlow { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        var attempts = 0
        while AuthUser.current == nil && attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        guard AuthUser.current != nil else {
            throw AppleSignInError.invalidCredential
        }

        try await createProfileIfNeeded(profileService: profileService)
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private static func createProfileIfNeeded(profileService: UnifiedProfileService) async throws {
        guard let user = AuthUser.current else { return }

        var attempts = 0
        while profileService.isLoading && attempts < 30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }
        await profileService.loadProfile()
        if profileService.currentProfile?.userId == user.uid { return }

        let firstName = user.displayName?
            .split(separator: " ")
            .first
            .map(String.init) ?? ""

        let profile = UnifiedUserProfile(
            userId: user.uid,
            firstName: firstName,
            email: user.email
        )
        try await profileService.saveProfile(profile)
    }

    private static func migratePendingIdentityIfNeeded(
        userId: String,
        fallbackFirstName: String,
        profileService: UnifiedProfileService
    ) async {
        let storedFirstName = UserDefaults.standard.string(forKey: "pending_firstname_to_save")
        let candidate = storedFirstName ?? fallbackFirstName
        let firstName = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard OnboardingViewModel.isRealUserFirstName(firstName) else { return }

        let storedBase = UserDefaults.standard.string(forKey: "pending_username_to_save")
        let generatedBase = firstName.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let base = storedBase ?? generatedBase

        do {
            let username = try await ProcessUsernameRegistry.shared.suggestAvailableUsername(
                base: base.isEmpty ? "user" : base,
                userId: userId
            )
            try await profileService.updateUsername(username, displayName: firstName)
            UserDefaults.standard.removeObject(forKey: "pending_firstname_to_save")
            UserDefaults.standard.removeObject(forKey: "pending_username_to_save")
        } catch {
            // Le profil et les réponses sont déjà migrés. Le username pourra être
            // réessayé sans bloquer l'utilisateur ni perdre son brouillon.
        }
    }
}
