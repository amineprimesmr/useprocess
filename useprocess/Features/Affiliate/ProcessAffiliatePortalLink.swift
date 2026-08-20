import Foundation

/// Lien portail créateur web avec préremplissage depuis l'app Process.
enum ProcessAffiliatePortalLink {
    private static let portalBase = "https://useprocess.xyz/affiliate"

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

        if let mail = trimmedNonEmpty(email) {
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
