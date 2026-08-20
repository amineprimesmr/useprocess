import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import UIKit

@MainActor
final class AppleSignInManager: NSObject, ObservableObject {
    static let shared = AppleSignInManager()

    private var currentNonce: String?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var deletionCompletion: ((Result<String?, Error>) -> Void)?
    private var intent: AppleSignInIntent = .signIn
    private var isPerformingRequest = false

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCredentialRevoked),
            name: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil
        )
    }

    @objc private func handleCredentialRevoked() {
        Task { @MainActor in
            guard !AppSession.shared.isAccountWipeInProgress else { return }
            guard AppSession.shared.hasCompletedOnboarding else { return }
            let uid = UserScopedStorage.currentUserId()
                ?? UnifiedProfileService.shared.currentProfile?.userId
                ?? "local-user"
            AppSession.shared.resetAfterAccountDeletion(primaryUID: uid)
        }
    }

    private func finishDeletion(with result: Result<String?, Error>) {
        isPerformingRequest = false
        deletionCompletion?(result)
        deletionCompletion = nil
        currentNonce = nil
        intent = .signIn
    }

    enum AppleSignInIntent {
        case signIn
        case reauthenticate
        case reauthenticateForAccountDeletion
    }

    func startSignInWithAppleFlow(completion: @escaping (Result<Void, Error>) -> Void) {
        startAuthorization(intent: .signIn, completion: completion)
    }

    func startReauthenticationFlow(completion: @escaping (Result<Void, Error>) -> Void) {
        startAuthorization(intent: .reauthenticate, completion: completion)
    }

    /// Réauth Apple avant suppression — retourne l'authorization code pour révocation serveur.
    func startReauthenticationForAccountDeletion() async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            startAuthorizationForDeletion { result in
                continuation.resume(with: result)
            }
        }
    }

    private func startAuthorizationForDeletion(
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        guard !AppSession.shared.isAccountWipeInProgress else {
            completion(.failure(AppleSignInError.requestInProgress))
            return
        }

        guard AppConfiguration.firebaseConfigured else {
            completion(.failure(AppleSignInError.firebaseNotConfigured))
            return
        }

        guard !isPerformingRequest else {
            completion(.failure(AppleSignInError.requestInProgress))
            return
        }

        isPerformingRequest = true
        deletionCompletion = completion
        intent = .reauthenticateForAccountDeletion
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        DispatchQueue.main.async {
            controller.performRequests()
        }
    }

    private func startAuthorization(
        intent: AppleSignInIntent,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !AppSession.shared.isAccountWipeInProgress else {
            completion(.failure(AppleSignInError.requestInProgress))
            return
        }

        guard AppConfiguration.firebaseConfigured else {
            completion(.failure(AppleSignInError.firebaseNotConfigured))
            return
        }

        guard !isPerformingRequest else {
            completion(.failure(AppleSignInError.requestInProgress))
            return
        }

        isPerformingRequest = true
        self.completion = completion
        self.intent = intent
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        if intent == .signIn {
            request.requestedScopes = [.fullName, .email]
        }
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        DispatchQueue.main.async {
            controller.performRequests()
        }
    }

    private func finish(with result: Result<Void, Error>) {
        isPerformingRequest = false
        completion?(result)
        completion = nil
        currentNonce = nil
        intent = .signIn
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            if intent == .reauthenticateForAccountDeletion {
                finishDeletion(with: .failure(AppleSignInError.invalidCredential))
            } else {
                finish(with: .failure(AppleSignInError.invalidCredential))
            }
            return
        }

        guard let nonce = currentNonce else {
            if intent == .reauthenticateForAccountDeletion {
                finishDeletion(with: .failure(AppleSignInError.missingNonce))
            } else {
                finish(with: .failure(AppleSignInError.missingNonce))
            }
            return
        }

        let activeIntent = intent

        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            if activeIntent == .reauthenticateForAccountDeletion {
                finishDeletion(with: .failure(AppleSignInError.missingToken))
            } else {
                finish(with: .failure(AppleSignInError.missingToken))
            }
            return
        }

        let authorizationCode = credential.authorizationCode.flatMap {
            String(data: $0, encoding: .utf8)
        }
        let appleUserId = credential.user

        Task { @MainActor in
            do {
                let firebaseCredential = OAuthProvider.appleCredential(
                    withIDToken: token,
                    rawNonce: nonce,
                    fullName: credential.fullName
                )

                switch activeIntent {
                case .signIn:
                    let result = try await Auth.auth().signIn(with: firebaseCredential)
                    if let fullName = credential.fullName {
                        let formatter = PersonNameComponentsFormatter()
                        let displayName = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !displayName.isEmpty, result.user.displayName == nil {
                            let changeRequest = result.user.createProfileChangeRequest()
                            changeRequest.displayName = displayName
                            try? await changeRequest.commitChanges()
                        }
                    }
                    AppleSignInTokenRegistrar.registerAuthorizationCodeIfPresent(
                        authorizationCode,
                        appleUserId: appleUserId
                    )
                case .reauthenticate:
                    guard let user = Auth.auth().currentUser else {
                        throw AppleSignInError.invalidCredential
                    }
                    try await user.reauthenticate(with: firebaseCredential)
                    AppleSignInTokenRegistrar.registerAuthorizationCodeIfPresent(
                        authorizationCode,
                        appleUserId: appleUserId
                    )
                case .reauthenticateForAccountDeletion:
                    guard let user = Auth.auth().currentUser else {
                        throw AppleSignInError.invalidCredential
                    }
                    try await user.reauthenticate(with: firebaseCredential)
                    finishDeletion(with: .success(authorizationCode))
                    return
                }

                finish(with: .success(()))
            } catch {
                if activeIntent == .reauthenticateForAccountDeletion {
                    finishDeletion(with: .failure(error))
                } else {
                    finish(with: .failure(error))
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let mapped = Self.userFacingError(from: error)
        if intent == .reauthenticateForAccountDeletion {
            finishDeletion(with: .failure(mapped))
            return
        }
        finish(with: .failure(mapped))
    }

    private static func userFacingError(from error: Error) -> Error {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return AppleSignInError.cancelled
        }
        return error
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            preconditionFailure("Aucune UIWindowScene disponible pour Sign in with Apple")
        }

        let orderedWindows = scene.windows.sorted { $0.windowLevel.rawValue > $1.windowLevel.rawValue }
        if let key = orderedWindows.first(where: \.isKeyWindow) {
            return key
        }
        if let top = orderedWindows.first {
            return top
        }

        return UIWindow(windowScene: scene)
    }
}

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingNonce
    case missingToken
    case firebaseNotConfigured
    case requestInProgress
    case cancelled
    case accountDeletionInProgress
    case signInIncomplete

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return AppCopy.tSync("Identifiants Apple invalides", en: "Invalid Apple credentials")
        case .missingNonce:
            return AppCopy.tSync("Nonce de sécurité manquant", en: "Missing security nonce")
        case .missingToken:
            return AppCopy.tSync("Jeton Apple manquant", en: "Missing Apple token")
        case .firebaseNotConfigured:
            return AppCopy.tSync("Firebase non configuré", en: "Firebase not configured")
        case .requestInProgress:
            return AppCopy.tSync(
                "Une authentification Apple est déjà en cours",
                en: "An Apple sign-in is already in progress"
            )
        case .cancelled:
            return AppCopy.tSync("Connexion annulée", en: "Sign-in cancelled")
        case .accountDeletionInProgress:
            return AppCopy.tSync(
                "Patiente — suppression de compte en cours",
                en: "Please wait — account deletion in progress"
            )
        case .signInIncomplete:
            return AppCopy.tSync(
                "Connexion Apple non terminée. Réessaie.",
                en: "Apple sign-in didn't finish. Try again."
            )
        }
    }
}
