import FirebaseAuth
import Foundation

/// Suppression de compte via Cloud Function (Admin SDK) — fiable pour Apple Sign In + Firestore.
enum AccountDeletionRemoteService {

    private static let cloudRequestTimeout: TimeInterval = 175
    private static let tokenTimeout: TimeInterval = 25
    private static let firestoreCleanupTimeout: TimeInterval = 45

    static func deleteViaCloudFunction() async throws {
        try ensureFirebaseReady()

        guard let user = Auth.auth().currentUser else {
            throw AccountDeletionError.notSignedIn
        }

        guard let baseURL = ClaudeConfiguration.functionsBaseURL else {
            throw AccountDeletionError.remoteDeletionFailed("URL Cloud Functions introuvable.")
        }

        let token = try await withTimeout(seconds: tokenTimeout) {
            try await user.getIDToken(forcingRefresh: true)
        }

        let url = baseURL.appendingPathComponent("deleteUserAccount")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = cloudRequestTimeout
        await applyAppCheckHeader(to: &request)

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
        try await signOutLocally()
    }

    /// Suppression Auth côté client (après réauth Apple) — fallback si la Cloud Function échoue.
    static func deleteViaClientSDK() async throws {
        try ensureFirebaseReady()

        guard let user = Auth.auth().currentUser else {
            // Déjà déconnecté — considéré comme succès côté Auth.
            return
        }

        let uid = user.uid

        try await withTimeout(seconds: firestoreCleanupTimeout) {
            try await FirebaseProfileRepository.shared.deleteAllRemoteUserData(userId: uid)
        }

        do {
            try await withTimeout(seconds: tokenTimeout) {
                try await user.delete()
            }
        } catch let error as NSError
            where error.domain == AuthErrorDomain
                && AuthErrorCode(rawValue: error.code) == .requiresRecentLogin {
            throw AccountDeletionError.remoteDeletionFailed(
                "Session Apple expirée — confirme à nouveau avec Face ID."
            )
        }

        try await signOutLocally()

        guard Auth.auth().currentUser == nil else {
            throw AccountDeletionError.remoteDeletionFailed("Firebase n'a pas supprimé le compte.")
        }
    }

    private static func ensureFirebaseReady() throws {
        guard FirebaseBootstrap.isConfigured else {
            throw AccountDeletionError.remoteDeletionFailed("Firebase non configuré.")
        }
    }

    private static func signOutLocally() async throws {
        try Auth.auth().signOut()
    }

    private static func applyAppCheckHeader(to request: inout URLRequest) async {
        let token = await withOptionalTimeout(seconds: 8) {
            try? await FirebaseAppAttestation.token()
        }
        guard let token else { return }
        request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
    }

    private static func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AccountDeletionError.remoteDeletionFailed(
                    "Délai dépassé — vérifie ta connexion et réessaie."
                )
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    private static func withOptionalTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async -> T?
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
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
