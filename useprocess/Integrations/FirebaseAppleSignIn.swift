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

    private override init() {
        super.init()
    }

    func startSignInWithAppleFlow(completion: @escaping (Result<Void, Error>) -> Void) {
        guard AppConfiguration.firebaseConfigured else {
            completion(.failure(AppleSignInError.firebaseNotConfigured))
            return
        }

        self.completion = completion
        let nonce = randomNonceString()
        currentNonce = nonce

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
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
            completion?(.failure(AppleSignInError.invalidCredential))
            completion = nil
            return
        }

        guard let nonce = currentNonce else {
            completion?(.failure(AppleSignInError.missingNonce))
            completion = nil
            return
        }

        guard let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            completion?(.failure(AppleSignInError.missingToken))
            completion = nil
            return
        }

        Task { @MainActor in
            do {
                let firebaseCredential = OAuthProvider.appleCredential(
                    withIDToken: token,
                    rawNonce: nonce,
                    fullName: credential.fullName
                )
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

                completion?(.success(()))
            } catch {
                completion?(.failure(error))
            }
            completion = nil
            currentNonce = nil
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(.failure(error))
        completion = nil
        currentNonce = nil
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            preconditionFailure("Aucune UIWindowScene disponible pour Sign in with Apple")
        }

        if let window = scene.windows.first(where: \.isKeyWindow) {
            return window
        }

        return UIWindow(windowScene: scene)
    }
}

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingNonce
    case missingToken
    case firebaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Identifiants Apple invalides"
        case .missingNonce: return "Nonce de sécurité manquant"
        case .missingToken: return "Jeton Apple manquant"
        case .firebaseNotConfigured: return "Firebase non configuré"
        }
    }
}
