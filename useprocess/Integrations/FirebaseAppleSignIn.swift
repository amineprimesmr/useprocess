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
    private var intent: AppleSignInIntent = .signIn
    private var isPerformingRequest = false

    private override init() {
        super.init()
    }

    enum AppleSignInIntent {
        case signIn
        case reauthenticate
    }

    func startSignInWithAppleFlow(completion: @escaping (Result<Void, Error>) -> Void) {
        startAuthorization(intent: .signIn, completion: completion)
    }

    func startReauthenticationFlow(completion: @escaping (Result<Void, Error>) -> Void) {
        startAuthorization(intent: .reauthenticate, completion: completion)
    }

    private func startAuthorization(
        intent: AppleSignInIntent,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
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
            finish(with: .failure(AppleSignInError.invalidCredential))
            return
        }

        guard let nonce = currentNonce else {
            finish(with: .failure(AppleSignInError.missingNonce))
            return
        }

        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            finish(with: .failure(AppleSignInError.missingToken))
            return
        }

        let activeIntent = intent

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
                case .reauthenticate:
                    guard let user = Auth.auth().currentUser else {
                        throw AppleSignInError.invalidCredential
                    }
                    try await user.reauthenticate(with: firebaseCredential)
                }

                finish(with: .success(()))
            } catch {
                finish(with: .failure(error))
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(with: .failure(error))
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

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Identifiants Apple invalides"
        case .missingNonce: return "Nonce de sécurité manquant"
        case .missingToken: return "Jeton Apple manquant"
        case .firebaseNotConfigured: return "Firebase non configuré"
        case .requestInProgress: return "Une authentification Apple est déjà en cours"
        }
    }
}
