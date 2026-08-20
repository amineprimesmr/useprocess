import FirebaseAuth
import Foundation

enum ReferralRemoteError: LocalizedError {
    case notAuthenticated
    case missingBaseURL
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return AppCopy.tSync("Connecte-toi pour utiliser le parrainage.", en: "Sign in to use referrals.")
        case .missingBaseURL:
            return AppCopy.tSync("Service parrainage indisponible.", en: "Referral service unavailable.")
        case .httpError(let code, _):
            if code == 404 {
                return AppCopy.tSync("Code parrainage introuvable.", en: "Referral code not found.")
            }
            return AppCopy.tSync("Erreur parrainage (\(code)).", en: "Referral error (\(code)).")
        }
    }
}

enum ReferralRemoteService {
    static func syncProgram(referralCode: String, displayName: String?) async throws {
        _ = try await post(
            function: "referralSyncProgram",
            payload: [
                "referralCode": referralCode,
                "displayName": displayName ?? ""
            ]
        )
    }

    static func register(referralCode: String, displayName: String?) async throws {
        _ = try await post(
            function: "referralRegister",
            payload: [
                "referralCode": referralCode,
                "displayName": displayName ?? ""
            ]
        )
    }

    @discardableResult
    static func confirmSubscription() async throws -> Bool {
        let json = try await post(function: "referralConfirmSubscription", payload: [:])
        return json["ok"] as? Bool == true
    }

    static func fetchDashboard() async throws -> ProcessReferralDashboardResponse {
        let json = try await post(function: "referralDashboard", payload: [:])
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(ProcessReferralDashboardResponse.self, from: data)
    }

    private static func post(function: String, payload: [String: Any]) async throws -> [String: Any] {
        let token = try await idToken()
        guard let base = ClaudeConfiguration.functionsBaseURL else {
            throw ReferralRemoteError.missingBaseURL
        }

        let url = base.appendingPathComponent(function)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        await applyAppCheckHeader(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReferralRemoteError.httpError(-1, "invalid_response")
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(http.statusCode) else {
            throw ReferralRemoteError.httpError(http.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private static func idToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ReferralRemoteError.notAuthenticated
        }
        return try await user.getIDToken()
    }

    private static func applyAppCheckHeader(to request: inout URLRequest) async {
        guard let token = try? await FirebaseAppAttestation.token() else { return }
        request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
    }
}
