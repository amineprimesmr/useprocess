import FirebaseAuth
import Foundation

@MainActor
enum OnboardingWelcomeAuth {
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

        await createProfileIfNeeded(profileService: profileService)
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private static func createProfileIfNeeded(profileService: UnifiedProfileService) async {
        guard let user = AuthUser.current else { return }

        await profileService.loadProfile()
        if profileService.currentProfile != nil { return }

        let firstName = user.displayName?
            .split(separator: " ")
            .first
            .map(String.init) ?? ""

        let profile = UnifiedUserProfile(
            userId: user.uid,
            firstName: firstName,
            email: user.email
        )
        try? await profileService.saveProfile(profile)
    }
}
