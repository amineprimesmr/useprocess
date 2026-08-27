import Foundation

/// Lien portail clipper web avec préremplissage depuis l'app Process.
enum ProcessAffiliatePortalLink {
    private static let portalBase = "https://useprocess.xyz/clipping"

    @MainActor
    static func urlForCurrentUser() -> URL {
        let profile = UnifiedProfileService.shared.currentProfile
        let firstName = resolvedFirstName(
            profileFirstName: profile?.firstName,
            authDisplayName: AuthUser.current?.displayName
        )
        let referralCode = ProcessReferralStore.shared.snapshot.referralCode
        let email = AuthUser.current?.email
        return buildURL(firstName: firstName, referralCode: referralCode, email: email)
    }

    /// Preferred entry point: hands the app's session to the portal with a one-time code.
    ///
    /// Clippers signed in with "Hide My Email" have an `@privaterelay.appleid.com` address,
    /// and Apple rejects every login link we send there. Handing off the session skips email
    /// entirely; if the call fails we fall back to the prefilled URL.
    @MainActor
    static func portalURLForCurrentUser() async -> URL {
        let fallback = urlForCurrentUser()
        guard AuthUser.current != nil else { return fallback }

        do {
            let code = try await AffiliateRemoteService.portalHandoff()
            var components = URLComponents(string: portalBase)!
            var queryItems = [URLQueryItem(name: "handoff", value: code)]
            if ProcessAppLanguage.currentCode != .french {
                queryItems.append(URLQueryItem(name: "lang", value: ProcessAppLanguage.currentCode.rawValue))
            }
            components.queryItems = queryItems
            return components.url ?? fallback
        } catch {
            return fallback
        }
    }

    /// Apple's relay only accepts mail from senders registered with Apple — never prefill it.
    static func isAppleRelayEmail(_ email: String?) -> Bool {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return email.hasSuffix("@privaterelay.appleid.com")
    }

    static func buildURL(firstName: String?, referralCode: String?, email: String?) -> URL {
        var components = URLComponents(string: portalBase)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "from", value: "app")
        ]

        if ProcessAppLanguage.currentCode != .french {
            queryItems.append(URLQueryItem(name: "lang", value: ProcessAppLanguage.currentCode.rawValue))
        }

        if let name = trimmedNonEmpty(firstName) {
            queryItems.append(URLQueryItem(name: "name", value: name))
        }

        let code = ProcessAffiliateLink.normalizeCode(referralCode ?? "")
        if !code.isEmpty {
            queryItems.append(URLQueryItem(name: "code", value: code))
        }

        if let mail = trimmedNonEmpty(email), !isAppleRelayEmail(mail) {
            queryItems.append(URLQueryItem(name: "email", value: mail))
        }

        components.queryItems = queryItems
        components.fragment = "apply"

        if let url = components.url {
            return url
        }

        return ProcessLegalURLs.affiliatePortal
    }

    private static func resolvedFirstName(profileFirstName: String?, authDisplayName: String?) -> String? {
        if let profileFirstName, OnboardingViewModel.isRealUserFirstName(profileFirstName) {
            return profileFirstName
        }
        if let authDisplayName, OnboardingViewModel.isRealUserFirstName(authDisplayName) {
            return authDisplayName
        }
        return nil
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
