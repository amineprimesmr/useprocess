import Foundation
import FirebaseAuth

/// Enregistre le refresh token Apple côté serveur (Sign in with Apple REST).
enum AppleSignInTokenRegistrar {

    static func registerAuthorizationCodeIfPresent(
        _ authorizationCode: String?,
        appleUserId: String?
    ) {
        guard let authorizationCode,
              !authorizationCode.isEmpty,
              AppConfiguration.firebaseConfigured,
              Auth.auth().currentUser != nil else { return }

        Task {
            await register(authorizationCode: authorizationCode, appleUserId: appleUserId)
        }
    }

    static func register(authorizationCode: String, appleUserId: String?) async {
        guard AppConfiguration.firebaseConfigured else { return }
        guard let user = Auth.auth().currentUser else { return }
        guard let baseURL = ClaudeConfiguration.functionsBaseURL else { return }

        do {
            let token = try await user.getIDToken(forcingRefresh: false)
            let url = baseURL.appendingPathComponent("appleSignInRegisterToken")

            var payload: [String: Any] = ["authorizationCode": authorizationCode]
            if let appleUserId, !appleUserId.isEmpty {
                payload["appleUserId"] = appleUserId
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            request.timeoutInterval = 30

            if let appCheck = try? await FirebaseAppAttestation.token() {
                request.setValue(appCheck, forHTTPHeaderField: "X-Firebase-AppCheck")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                #if DEBUG
                let body = String(data: data, encoding: .utf8) ?? ""
                print("[AppleSignInTokenRegistrar] register failed: \(body)")
                #endif
                return
            }
            #if DEBUG
            print("[AppleSignInTokenRegistrar] refresh token registered")
            #endif
        } catch {
            #if DEBUG
            print("[AppleSignInTokenRegistrar] register error: \(error.localizedDescription)")
            #endif
        }
    }
}
