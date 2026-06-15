import Foundation
import FirebaseAuth

enum CoachRemoteTask: String, Codable, Sendable {
    case chat
    case dailyBrief
    case readinessAnalysis
    case bodyScanVision
    case bodyScanReport
    case programSummary
    case tool
}

enum CoachRemoteError: LocalizedError {
    case notAuthenticated
    case missingBaseURL
    case httpError(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Connecte-toi pour utiliser le coach cloud."
        case .missingBaseURL: return "URL Cloud Functions introuvable."
        case .httpError(let code, let body): return "Coach cloud HTTP \(code): \(body.prefix(180))"
        case .invalidResponse: return "Réponse coach cloud invalide."
        }
    }
}

/// Proxy Firebase Functions — clé Anthropic côté serveur uniquement.
enum CoachRemoteService {

    static func complete(
        task: CoachRemoteTask,
        system: String,
        userText: String,
        history: [CoachMessage] = [],
        model: ClaudeModel,
        imageBase64: String? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        let token = try await idToken()
        guard let base = ClaudeConfiguration.functionsBaseURL else {
            throw CoachRemoteError.missingBaseURL
        }

        let url = base.appendingPathComponent("coachComplete")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        var payload: [String: Any] = [
            "task": task.rawValue,
            "model": model.apiModelId,
            "system": system,
            "userText": userText,
            "history": history.filter { $0.role != .system }.map {
                ["role": $0.role == .user ? "user" : "assistant", "text": $0.text]
            }
        ]
        if let maxTokens { payload["maxTokens"] = maxTokens }
        if let imageBase64 { payload["imageBase64"] = imageBase64 }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CoachRemoteError.invalidResponse }

        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CoachRemoteError.httpError(http.statusCode, body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw CoachRemoteError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func streamChat(
        system: String,
        userText: String,
        history: [CoachMessage],
        model: ClaudeModel,
        maxTokens: Int = 1200
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let token = try await idToken()
                    guard let base = ClaudeConfiguration.functionsBaseURL else {
                        throw CoachRemoteError.missingBaseURL
                    }

                    let url = base.appendingPathComponent("coachStream")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 180
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let payload: [String: Any] = [
                        "task": CoachRemoteTask.chat.rawValue,
                        "model": model.apiModelId,
                        "system": system,
                        "userText": userText,
                        "history": history.filter { $0.role != .system }.map {
                            ["role": $0.role == .user ? "user" : "assistant", "text": $0.text]
                        },
                        "maxTokens": maxTokens
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                        throw CoachRemoteError.invalidResponse
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonLine = String(line.dropFirst(6))
                        guard let data = jsonLine.data(using: .utf8),
                              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = event["type"] as? String else { continue }

                        if type == "delta", let text = event["text"] as? String, !text.isEmpty {
                            continuation.yield(text)
                        } else if type == "error", let err = event["error"] as? String {
                            throw CoachRemoteError.httpError(500, err)
                        } else if type == "done" {
                            break
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func idToken() async throws -> String {
        guard AppConfiguration.firebaseConfigured,
              let user = Auth.auth().currentUser else {
            throw CoachRemoteError.notAuthenticated
        }
        return try await user.getIDToken()
    }
}
