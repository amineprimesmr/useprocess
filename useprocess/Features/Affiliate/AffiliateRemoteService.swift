import FirebaseAuth
import Foundation

enum AffiliateRemoteError: LocalizedError {
    case notAuthenticated
    case missingBaseURL
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return AppCopy.tSync("Connecte-toi pour utiliser le programme créateur.", en: "Sign in to use the creator program.")
        case .missingBaseURL:
            return AppCopy.tSync("Service créateur indisponible.", en: "Creator service unavailable.")
        case .httpError(let code, _):
            if code == 404 {
                return AppCopy.tSync("Code créateur introuvable.", en: "Creator code not found.")
            }
            return AppCopy.tSync("Erreur créateur (\(code)).", en: "Creator error (\(code)).")
        }
    }
}

enum AffiliateRemoteService {
    static func resolveCode(_ rawCode: String) async throws -> ProcessAffiliateResolveResult? {
        let normalized = ProcessAffiliateLink.normalizeCode(rawCode)
        guard !normalized.isEmpty else { return nil }

        let json = try await post(
            function: "affiliateResolveCode",
            payload: ["code": normalized],
            requiresAuth: false
        )

        guard json["ok"] as? Bool == true,
              let typeRaw = json["type"] as? String,
              let type = ProcessAffiliateCodeKind(rawValue: typeRaw),
              let code = json["code"] as? String else {
            return nil
        }

        return ProcessAffiliateResolveResult(
            ok: true,
            type: type,
            code: code,
            displayName: json["displayName"] as? String,
            affiliateId: json["affiliateId"] as? String,
            referrerUserId: json["referrerUserId"] as? String
        )
    }

    static func registerAffiliate(code: String, displayName: String?) async throws {
        _ = try await post(
            function: "affiliateRegister",
            payload: [
                "affiliateCode": code,
                "displayName": displayName ?? ""
            ]
        )
    }

    static func apply(displayName: String, code: String?, email: String?, paypalEmail: String?) async throws {
        var payload: [String: Any] = ["displayName": displayName]
        if let code, !code.isEmpty { payload["code"] = code }
        if let email, !email.isEmpty { payload["email"] = email }
        if let paypalEmail, !paypalEmail.isEmpty { payload["paypalEmail"] = paypalEmail }
        _ = try await post(function: "affiliateApply", payload: payload)
    }

    static func syncProfile(paypalEmail: String?, payoutMethod: String = "paypal") async throws {
        _ = try await post(
            function: "affiliateSyncProfile",
            payload: [
                "paypalEmail": paypalEmail ?? "",
                "payoutMethod": payoutMethod
            ]
        )
    }

    static func dashboard() async throws -> ProcessAffiliateDashboardResponse {
        let json = try await post(function: "affiliateDashboard", payload: [:])
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(ProcessAffiliateDashboardResponse.self, from: data)
    }

    private static func post(
        function: String,
        payload: [String: Any],
        requiresAuth: Bool = true
    ) async throws -> [String: Any] {
        guard let base = ClaudeConfiguration.functionsBaseURL else {
            throw AffiliateRemoteError.missingBaseURL
        }

        var request = URLRequest(url: base.appendingPathComponent(function))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresAuth {
            let token = try await idToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            await applyAppCheckHeader(to: &request)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AffiliateRemoteError.httpError(-1, "invalid_response")
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(http.statusCode) else {
            throw AffiliateRemoteError.httpError(http.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private static func idToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AffiliateRemoteError.notAuthenticated
        }
        return try await user.getIDToken()
    }

    private static func applyAppCheckHeader(to request: inout URLRequest) async {
        guard let token = try? await FirebaseAppAttestation.token() else { return }
        request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
    }
}
