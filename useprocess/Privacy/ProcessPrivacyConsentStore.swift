import Foundation

enum ProcessPrivacyConsentError: LocalizedError {
    case thirdPartyAINotAccepted
    case faceScanCaptureNotAccepted
    case faceScanAINotAccepted

    var errorDescription: String? {
        switch self {
        case .thirdPartyAINotAccepted:
            return "Autorise le coach IA dans les paramètres de confidentialité pour continuer."
        case .faceScanCaptureNotAccepted:
            return "Autorise le scan visage avant de continuer."
        case .faceScanAINotAccepted:
            return "Autorise l'analyse IA du scan visage pour continuer."
        }
    }
}

/// Consentements privacy App Store — IA tierce (Anthropic) et données faciales (TrueDepth).
@MainActor
@Observable
final class ProcessPrivacyConsentStore {
    static let shared = ProcessPrivacyConsentStore()

    private(set) var hasAcceptedThirdPartyAI = false
    private(set) var thirdPartyAIAcceptedAt: Date?

    private(set) var hasAcceptedFaceScanCapture = false
    private(set) var hasAcceptedFaceScanAI = false
    private(set) var faceScanCaptureAcceptedAt: Date?

    var isPresentingThirdPartyAIConsent = false
    var pendingThirdPartyAIAction: (() -> Void)?

    private var userId: String?

    private init() {
        reloadForUser(userId: UserScopedStorage.currentUserId())
    }

    var canUseThirdPartyAI: Bool { hasAcceptedThirdPartyAI }

    var canCaptureFaceScan: Bool { hasAcceptedFaceScanCapture }

    var canSendFacePhotoToAI: Bool {
        hasAcceptedThirdPartyAI && hasAcceptedFaceScanCapture && hasAcceptedFaceScanAI
    }

    func reloadForUser(userId: String?) {
        self.userId = userId
        let scoped = userId ?? "anonymous"
        hasAcceptedThirdPartyAI = UserDefaults.standard.bool(
            forKey: UserScopedStorage.key("privacy.ai_third_party", userId: scoped)
        )
        thirdPartyAIAcceptedAt = UserDefaults.standard.object(
            forKey: UserScopedStorage.key("privacy.ai_third_party.date", userId: scoped)
        ) as? Date

        hasAcceptedFaceScanCapture = UserDefaults.standard.bool(
            forKey: UserScopedStorage.key("privacy.face_capture", userId: scoped)
        )
        hasAcceptedFaceScanAI = UserDefaults.standard.bool(
            forKey: UserScopedStorage.key("privacy.face_ai", userId: scoped)
        )
        faceScanCaptureAcceptedAt = UserDefaults.standard.object(
            forKey: UserScopedStorage.key("privacy.face_capture.date", userId: scoped)
        ) as? Date
    }

    func acceptThirdPartyAI() {
        hasAcceptedThirdPartyAI = true
        thirdPartyAIAcceptedAt = Date()
        persistBool(true, key: "privacy.ai_third_party")
        persistDate(thirdPartyAIAcceptedAt, key: "privacy.ai_third_party.date")
        isPresentingThirdPartyAIConsent = false
        let action = pendingThirdPartyAIAction
        pendingThirdPartyAIAction = nil
        action?()
    }

    func declineThirdPartyAI() {
        isPresentingThirdPartyAIConsent = false
        pendingThirdPartyAIAction = nil
    }

    func acceptFaceScanCapture(enableAIAnalysis: Bool) {
        hasAcceptedFaceScanCapture = true
        faceScanCaptureAcceptedAt = Date()
        persistBool(true, key: "privacy.face_capture")
        persistDate(faceScanCaptureAcceptedAt, key: "privacy.face_capture.date")

        if enableAIAnalysis {
            hasAcceptedFaceScanAI = true
            persistBool(true, key: "privacy.face_ai")
            if !hasAcceptedThirdPartyAI {
                hasAcceptedThirdPartyAI = true
                thirdPartyAIAcceptedAt = Date()
                persistBool(true, key: "privacy.ai_third_party")
                persistDate(thirdPartyAIAcceptedAt, key: "privacy.ai_third_party.date")
            }
        } else {
            hasAcceptedFaceScanAI = false
            persistBool(false, key: "privacy.face_ai")
        }
    }

    func revokeThirdPartyAI() {
        hasAcceptedThirdPartyAI = false
        thirdPartyAIAcceptedAt = nil
        persistBool(false, key: "privacy.ai_third_party")
        UserDefaults.standard.removeObject(forKey: storageKey("privacy.ai_third_party.date"))
        revokeFaceScanAIOnly()
    }

    func revokeFaceScanConsents() {
        hasAcceptedFaceScanCapture = false
        hasAcceptedFaceScanAI = false
        faceScanCaptureAcceptedAt = nil
        persistBool(false, key: "privacy.face_capture")
        persistBool(false, key: "privacy.face_ai")
        UserDefaults.standard.removeObject(forKey: storageKey("privacy.face_capture.date"))
        Task { await FaceScanDataLifecycle.purgeAllForCurrentUser() }
    }

    private func revokeFaceScanAIOnly() {
        hasAcceptedFaceScanAI = false
        persistBool(false, key: "privacy.face_ai")
    }

    func clearForUser(userId: String?) {
        let keys = [
            "privacy.ai_third_party",
            "privacy.ai_third_party.date",
            "privacy.face_capture",
            "privacy.face_capture.date",
            "privacy.face_ai"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key(key, userId: userId))
            UserDefaults.standard.removeObject(forKey: UserScopedStorage.key(key, userId: "anonymous"))
        }
        reloadForUser(userId: userId)
    }

    @discardableResult
    func presentThirdPartyAIConsentIfNeeded(then action: (() -> Void)? = nil) -> Bool {
        guard !canUseThirdPartyAI else { return false }
        pendingThirdPartyAIAction = action
        isPresentingThirdPartyAIConsent = true
        return true
    }

    func requireThirdPartyAI() throws {
        guard canUseThirdPartyAI else {
            throw ProcessPrivacyConsentError.thirdPartyAINotAccepted
        }
    }

    func requireFacePhotoToAI() throws {
        try requireThirdPartyAI()
        guard canCaptureFaceScan else {
            throw ProcessPrivacyConsentError.faceScanCaptureNotAccepted
        }
        guard canSendFacePhotoToAI else {
            throw ProcessPrivacyConsentError.faceScanAINotAccepted
        }
    }

    private func persistBool(_ value: Bool, key: String) {
        UserDefaults.standard.set(value, forKey: storageKey(key))
    }

    private func persistDate(_ value: Date?, key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: storageKey(key))
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey(key))
        }
    }

    private func storageKey(_ key: String) -> String {
        UserScopedStorage.key(key, userId: userId ?? "anonymous")
    }
}
