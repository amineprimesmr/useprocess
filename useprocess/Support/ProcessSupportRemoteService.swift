import FirebaseAuth
import Foundation

enum ProcessSupportRemoteError: LocalizedError {
    case notAuthenticated
    case missingBaseURL
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return AppCopy.tSync(
                "Connecte-toi pour écrire à l'équipe.",
                en: "Sign in to message the team."
            )
        case .missingBaseURL:
            return AppCopy.tSync(
                "Le chat support est momentanément indisponible.",
                en: "Support chat is temporarily unavailable."
            )
        case .httpError(let code, _):
            if code == 429 {
                return AppCopy.tSync(
                    "Attends une seconde avant d'envoyer un autre message.",
                    en: "Wait a second before sending another message."
                )
            }
            if code == 503 {
                return AppCopy.tSync(
                    "On n'a pas pu envoyer le message. Réessaie dans un instant.",
                    en: "We couldn't send the message. Try again in a moment."
                )
            }
            return AppCopy.tSync(
                "Impossible d'envoyer le message (\(code)).",
                en: "Couldn't send the message (\(code))."
            )
        }
    }
}

enum ProcessSupportRemoteService {
    static func send(
        text: String,
        messageId: String,
        nickname: String?,
        email: String?
    ) async throws {
        let token = try await idToken()
        guard let base = ClaudeConfiguration.functionsBaseURL else {
            throw ProcessSupportRemoteError.missingBaseURL
        }

        var payload: [String: Any] = [
            "text": text,
            "messageId": messageId,
            "language": ProcessAppLanguage.shared.code.rawValue,
            "subscription": SubscriptionService.shared.subscriptionStatus.isActive ? "premium" : "free",
            "acquisitionSource": ProcessAcquisitionAttribution.snapshot.primarySource,
        ]
        if let nickname, !nickname.isEmpty {
            payload["nickname"] = nickname
        }
        if let email, email.contains("@") {
            payload["email"] = email
        }
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            payload["appVersion"] = version
        }

        let url = base.appendingPathComponent("supportSendMessage")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        await applyAppCheckHeader(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProcessSupportRemoteError.httpError(-1, "invalid_response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ProcessSupportRemoteError.httpError(http.statusCode, body)
        }
    }

    private static func idToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ProcessSupportRemoteError.notAuthenticated
        }
        return try await user.getIDToken()
    }

    private static func applyAppCheckHeader(to request: inout URLRequest) async {
        guard let token = try? await FirebaseAppAttestation.token() else { return }
        request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
    }
}
