import Foundation
import FirebaseAuth

enum CoachRemoteTask: String, Codable, Sendable {
    case chat
    case dailyBrief
    case readinessAnalysis
    case bodyScanVision
    case faceScanVision
    case bodyScanReport
    case programSummary
    case tool
}

enum CoachRemoteError: LocalizedError {
    case notAuthenticated
    case missingBaseURL
    case httpError(Int, String)
    case invalidResponse
    case incompleteStream
    case overloaded

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Connecte-toi pour utiliser le coach cloud."
        case .missingBaseURL:
            return "URL Cloud Functions introuvable."
        case .httpError(let code, let body):
            return CoachRemoteError.userMessage(forHTTP: code, body: body)
        case .invalidResponse:
            return "Réponse coach cloud invalide."
        case .incompleteStream:
            return "La réponse du coach a été coupée. Réessaie."
        case .overloaded:
            return "Le coach est surchargé — réessaie dans quelques secondes."
        }
    }

    static func userMessage(forHTTP code: Int, body: String) -> String {
        let lower = body.lowercased()
        if lower.contains("overloaded") || code == 529 {
            return CoachRemoteError.overloaded.errorDescription!
        }
        if code >= 500 {
            return "Le coach est indisponible pour le moment. Réessaie."
        }
        if code == 401 {
            return "Session expirée — reconnecte-toi."
        }
        return "Erreur coach (\(code)). Réessaie."
    }

    static func isRetryable(_ error: Error) -> Bool {
        if case .overloaded = error as? CoachRemoteError { return true }
        if case .incompleteStream = error as? CoachRemoteError { return true }
        if case .httpError(let code, let body) = error as? CoachRemoteError {
            if code >= 500 || code == 429 { return true }
            return body.lowercased().contains("overloaded")
        }
        let text = error.localizedDescription.lowercased()
        return text.contains("overloaded") || text.contains("timed out") || text.contains("network")
    }
}

/// Proxy Firebase Functions — clé Anthropic côté serveur uniquement.
enum CoachRemoteService {

    private static let streamRetryCount = 3

    static func complete(
        task: CoachRemoteTask,
        system: String,
        userText: String,
        history: [CoachMessage] = [],
        model: ClaudeModel,
        imageBase64: String? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        var lastError: Error?
        for attempt in 0..<streamRetryCount {
            do {
                return try await completeOnce(
                    task: task,
                    system: system,
                    userText: userText,
                    history: history,
                    model: model,
                    imageBase64: imageBase64,
                    maxTokens: maxTokens
                )
            } catch {
                lastError = error
                guard CoachRemoteError.isRetryable(error), attempt < streamRetryCount - 1 else { throw error }
                try await Task.sleep(nanoseconds: UInt64(900_000_000 * UInt64(attempt + 1)))
            }
        }
        throw lastError ?? CoachRemoteError.invalidResponse
    }

    private static func completeOnce(
        task: CoachRemoteTask,
        system: String,
        userText: String,
        history: [CoachMessage],
        model: ClaudeModel,
        imageBase64: String?,
        maxTokens: Int?
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
        await applyAppCheckHeader(to: &request)

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
                    try await streamChatOnce(
                        system: system,
                        userText: userText,
                        history: history,
                        model: model,
                        maxTokens: maxTokens,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private static func streamChatOnce(
        system: String,
        userText: String,
        history: [CoachMessage],
        model: ClaudeModel,
        maxTokens: Int,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
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
        await applyAppCheckHeader(to: &request)

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
        guard let http = response as? HTTPURLResponse else {
            throw CoachRemoteError.invalidResponse
        }

        if !(200...299).contains(http.statusCode) {
            var errorBody = Data()
            for try await byte in bytes {
                errorBody.append(byte)
                if errorBody.count > 4000 { break }
            }
            let body = String(data: errorBody, encoding: .utf8) ?? ""
            throw CoachRemoteError.httpError(http.statusCode, body)
        }

        var yieldedText = ""
        var receivedDone = false
        var finalTextFromServer: String?

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonLine = String(line.dropFirst(6))
            guard let data = jsonLine.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            if type == "delta", let text = event["text"] as? String, !text.isEmpty {
                yieldedText += text
                continuation.yield(text)
            } else if type == "error", let err = event["error"] as? String {
                if err.lowercased().contains("overloaded") {
                    throw CoachRemoteError.overloaded
                }
                throw CoachRemoteError.httpError(500, err)
            } else if type == "done" {
                receivedDone = true
                finalTextFromServer = event["text"] as? String
                break
            }
        }

        guard receivedDone else {
            throw CoachRemoteError.incompleteStream
        }

        if let final = finalTextFromServer?.trimmingCharacters(in: .whitespacesAndNewlines),
           !final.isEmpty,
           final.count > yieldedText.count,
           final.hasPrefix(yieldedText) {
            let suffix = String(final.dropFirst(yieldedText.count))
            if !suffix.isEmpty {
                continuation.yield(suffix)
            }
        }

        continuation.finish()
    }

    private static func idToken() async throws -> String {
        guard FirebaseBootstrap.isConfigured,
              let user = Auth.auth().currentUser else {
            throw CoachRemoteError.notAuthenticated
        }
        return try await user.getIDToken()
    }

    private static func applyAppCheckHeader(to request: inout URLRequest) async {
        guard let token = try? await FirebaseAppAttestation.token() else { return }
        request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
    }
}
