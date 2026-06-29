import FirebaseAuth
import Foundation

/// Suppression de compte via Cloud Function (Admin SDK) — fiable pour Apple Sign In + Firestore.
enum AccountDeletionRemoteService {

    static func deleteViaCloudFunction() async throws {
        guard firebaseAuthReady else { return }

        guard let user = Auth.auth().currentUser else {
            throw AccountDeletionError.notSignedIn
        }

        guard let baseURL = ClaudeConfiguration.functionsBaseURL else {
            throw AccountDeletionError.remoteDeletionFailed("URL Cloud Functions introuvable.")
        }

        let token = try await user.getIDToken(forcingRefresh: true)
        let url = baseURL.appending(path: "deleteUserAccount")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let appCheckToken = try? await FirebaseAppAttestation.token(forcingRefresh: true) {
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        }
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AccountDeletionError.remoteDeletionFailed("Réponse serveur invalide.")
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            #if DEBUG
            print("[AccountDeletion] Cloud function HTTP \(http.statusCode): \(body)")
            #endif
            throw AccountDeletionError.remoteDeletionFailed(userMessage(for: http.statusCode, body: body))
        }

        #if DEBUG
        print("[AccountDeletion] Cloud function OK — déconnexion locale")
        #endif
        try? Auth.auth().signOut()
    }

    /// Suppression Auth côté client (après réauth Apple) — fallback si la Cloud Function échoue.
    static func deleteViaClientSDK() async throws {
        guard firebaseAuthReady else { return }
        guard let user = Auth.auth().currentUser else {
            throw AccountDeletionError.notSignedIn
        }

        let uid = user.uid
        try? await FirebaseProfileRepository.shared.deleteAllRemoteUserData(userId: uid)

        do {
            try await user.delete()
        } catch let error as NSError
            where error.domain == AuthErrorDomain
                && AuthErrorCode(rawValue: error.code) == .requiresRecentLogin {
            throw AccountDeletionError.remoteDeletionFailed(
                "Session Apple expirée — confirme à nouveau avec Face ID."
            )
        }

        try? Auth.auth().signOut()

        guard Auth.auth().currentUser == nil else {
            throw AccountDeletionError.remoteDeletionFailed("Firebase n'a pas supprimé le compte.")
        }
    }

    private static var firebaseAuthReady: Bool {
        FirebaseBootstrap.isConfigured
    }

    private static func userMessage(for status: Int, body: String) -> String {
        if status == 401 {
            return "Session expirée — réessaie."
        }
        if status == 404 {
            return "Service de suppression indisponible."
        }
        if status >= 500 {
            return "Suppression serveur impossible. Réessaie dans un instant."
        }
        if body.contains("error"), let parsed = try? JSONDecoder().decode([String: String].self, from: Data(body.utf8)),
           let message = parsed["error"], !message.isEmpty {
            return message
        }
        return "Erreur serveur (\(status))."
    }
}
