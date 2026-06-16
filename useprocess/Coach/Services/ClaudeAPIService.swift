import Foundation

enum CoachAPIMode: Sendable {
    case remote
    case local
    case unavailable
}

/// Route les appels Claude : proxy Firebase (prod) ou API directe (dev).
enum CoachAPITransport {

    static var activeMode: CoachAPIMode {
        if ClaudeConfiguration.prefersRemoteCoach, AuthUser.current != nil {
            return .remote
        }
        if ClaudeConfiguration.anthropicAPIKey != nil {
            return .local
        }
        return .unavailable
    }

    static func complete(
        task: CoachRemoteTask,
        system: String,
        userText: String,
        history: [CoachMessage] = [],
        model: ClaudeModel,
        imageBase64: String? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        if activeMode == .remote {
            do {
                return try await CoachRemoteService.complete(
                    task: task,
                    system: system,
                    userText: userText,
                    history: history,
                    model: model,
                    imageBase64: imageBase64,
                    maxTokens: maxTokens
                )
            } catch {
                if ClaudeConfiguration.anthropicAPIKey != nil {
                    return try await completeLocally(
                        task: task,
                        system: system,
                        userText: userText,
                        history: history,
                        model: model,
                        imageBase64: imageBase64,
                        maxTokens: maxTokens
                    )
                }
                throw error
            }
        }
        return try await completeLocally(
            task: task,
            system: system,
            userText: userText,
            history: history,
            model: model,
            imageBase64: imageBase64,
            maxTokens: maxTokens
        )
    }

    private static func completeLocally(
        task: CoachRemoteTask,
        system: String,
        userText: String,
        history: [CoachMessage],
        model: ClaudeModel,
        imageBase64: String?,
        maxTokens: Int?
    ) async throws -> String {
        guard ClaudeConfiguration.anthropicAPIKey != nil else {
            throw ClaudeAPIError.missingAPIKey
        }
        if let imageBase64, let data = Data(base64Encoded: imageBase64) {
            return try await ClaudeLocalAPIService.completeWithImage(
                system: system,
                prompt: userText,
                jpegData: data,
                model: model,
                maxTokens: maxTokens ?? 512
            )
        }
        if history.isEmpty {
            return try await ClaudeLocalAPIService.complete(
                system: system,
                userText: userText,
                model: model,
                maxTokens: maxTokens ?? 1024
            )
        }
        return try await ClaudeLocalAPIService.completeWithHistory(
            system: system,
            history: history,
            userMessage: userText,
            model: model,
            maxTokens: maxTokens ?? 1200
        )
    }

    static func streamChat(
        system: String,
        userText: String,
        history: [CoachMessage],
        model: ClaudeModel,
        maxTokens: Int = 1200
    ) -> AsyncThrowingStream<String, Error> {
        if activeMode == .remote {
            return CoachRemoteService.streamChat(
                system: system,
                userText: userText,
                history: history,
                model: model,
                maxTokens: maxTokens
            )
        }
        guard ClaudeConfiguration.anthropicAPIKey != nil else {
            return AsyncThrowingStream { $0.finish(throwing: ClaudeAPIError.missingAPIKey) }
        }
        return ClaudeLocalAPIService.streamWithHistory(
            system: system,
            history: history,
            userMessage: userText,
            model: model,
            maxTokens: maxTokens
        )
    }
}

enum ClaudeAPIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case httpError(status: Int, body: String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude indisponible — connecte Firebase ou ajoute ANTHROPIC_API_KEY (CoachSecrets.plist)."
        case .invalidResponse:
            return "Réponse Claude invalide"
        case .httpError(let status, let body):
            return "Claude HTTP \(status): \(body.prefix(200))"
        case .network(let error):
            return error.localizedDescription
        }
    }
}

/// Appels directs Anthropic (développement / fallback).
enum ClaudeLocalAPIService {

    static func complete(
        system: String,
        userText: String,
        model: ClaudeModel = .sonnet46,
        maxTokens: Int = 1024
    ) async throws -> String {
        let content: [[String: Any]] = [["type": "text", "text": userText]]
        return try await sendMessages(
            system: system,
            messages: [["role": "user", "content": content]],
            model: model,
            maxTokens: maxTokens,
            stream: false
        )
    }

    static func completeWithImage(
        system: String,
        prompt: String,
        jpegData: Data,
        model: ClaudeModel = .sonnet46,
        maxTokens: Int = 512
    ) async throws -> String {
        let content: [[String: Any]] = [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": jpegData.base64EncodedString()
                ]
            ],
            ["type": "text", "text": prompt]
        ]
        return try await sendMessages(
            system: system,
            messages: [["role": "user", "content": content]],
            model: model,
            maxTokens: maxTokens,
            stream: false
        )
    }

    static func completeWithHistory(
        system: String,
        history: [CoachMessage],
        userMessage: String,
        model: ClaudeModel = .sonnet46,
        maxTokens: Int = 1200
    ) async throws -> String {
        let messages = messagesIncludingUserTurn(history: history, userMessage: userMessage)
        return try await sendMessages(
            system: system,
            messages: messages,
            model: model,
            maxTokens: maxTokens,
            stream: false
        )
    }

    static func streamWithHistory(
        system: String,
        history: [CoachMessage],
        userMessage: String,
        model: ClaudeModel = .sonnet46,
        maxTokens: Int = 1200
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let messages = messagesIncludingUserTurn(history: history, userMessage: userMessage)

                    let stream = openStream(
                        system: system,
                        messages: messages,
                        model: model,
                        maxTokens: maxTokens
                    )

                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private static func apiMessages(from history: [CoachMessage]) -> [[String: Any]] {
        history
            .filter { $0.role != .system }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { msg in
                [
                    "role": msg.role == .user ? "user" : "assistant",
                    "content": [["type": "text", "text": msg.text]]
                ]
            }
    }

    /// Évite de dupliquer le dernier message user déjà présent dans l'historique UI.
    private static func messagesIncludingUserTurn(
        history: [CoachMessage],
        userMessage: String
    ) -> [[String: Any]] {
        var messages = apiMessages(from: history)
        if let last = history.last, last.role == .user, last.text == userMessage {
            return messages
        }
        messages.append([
            "role": "user",
            "content": [["type": "text", "text": userMessage]]
        ])
        return messages
    }

    private static func sendMessages(
        system: String,
        messages: [[String: Any]],
        model: ClaudeModel,
        maxTokens: Int,
        stream: Bool
    ) async throws -> String {
        if stream {
            var fullText = ""
            for try await chunk in openStream(
                system: system,
                messages: messages,
                model: model,
                maxTokens: maxTokens
            ) {
                fullText += chunk
            }
            return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return try await fetchNonStream(
            system: system,
            messages: messages,
            model: model,
            maxTokens: maxTokens
        )
    }

    private static func fetchNonStream(
        system: String,
        messages: [[String: Any]],
        model: ClaudeModel,
        maxTokens: Int
    ) async throws -> String {
        guard let apiKey = ClaudeConfiguration.anthropicAPIKey else {
            throw ClaudeAPIError.missingAPIKey
        }

        let payload: [String: Any] = [
            "model": model.apiModelId,
            "max_tokens": maxTokens,
            "system": system,
            "messages": messages
        ]

        var request = URLRequest(url: ClaudeConfiguration.messagesURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(ClaudeConfiguration.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeAPIError.invalidResponse }
        if !(200...299).contains(http.statusCode) {
            throw ClaudeAPIError.httpError(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = extractText(from: json) else {
            throw ClaudeAPIError.invalidResponse
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func openStream(
        system: String,
        messages: [[String: Any]],
        model: ClaudeModel,
        maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey = ClaudeConfiguration.anthropicAPIKey else {
                        throw ClaudeAPIError.missingAPIKey
                    }

                    let payload: [String: Any] = [
                        "model": model.apiModelId,
                        "max_tokens": maxTokens,
                        "system": system,
                        "messages": messages,
                        "stream": true
                    ]

                    var request = URLRequest(url: ClaudeConfiguration.messagesURL)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 180
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue(ClaudeConfiguration.apiVersion, forHTTPHeaderField: "anthropic-version")
                    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ClaudeAPIError.invalidResponse
                    }
                    if !(200...299).contains(http.statusCode) {
                        var errorBody = Data()
                        for try await byte in bytes {
                            errorBody.append(byte)
                            if errorBody.count > 4000 { break }
                        }
                        throw ClaudeAPIError.httpError(
                            status: http.statusCode,
                            body: String(data: errorBody, encoding: .utf8) ?? "Réponse vide"
                        )
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payloadLine = String(line.dropFirst(6))
                        if payloadLine == "[DONE]" { break }
                        guard let data = payloadLine.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = json["type"] as? String else { continue }

                        if type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String, !text.isEmpty {
                            continuation.yield(text)
                        } else if type == "message_stop" {
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

    private static func extractText(from json: [String: Any]) -> String? {
        guard let content = json["content"] as? [[String: Any]] else { return nil }
        return content
            .compactMap { block -> String? in
                guard (block["type"] as? String) == "text" else { return nil }
                return block["text"] as? String
            }
            .joined(separator: "\n")
    }
}

/// Alias historique — délègue au routeur central.
enum ClaudeAPIService {
    static func complete(
        system: String,
        userText: String,
        model: ClaudeModel = .sonnet46,
        maxTokens: Int = 1024
    ) async throws -> String {
        try await CoachAPITransport.complete(
            task: .chat,
            system: system,
            userText: userText,
            model: model,
            maxTokens: maxTokens
        )
    }

    static func completeWithImage(
        system: String,
        prompt: String,
        jpegData: Data,
        model: ClaudeModel = .sonnet46,
        maxTokens: Int = 512
    ) async throws -> String {
        try await CoachAPITransport.complete(
            task: .bodyScanVision,
            system: system,
            userText: prompt,
            model: model,
            imageBase64: jpegData.base64EncodedString(),
            maxTokens: maxTokens
        )
    }

    static func completeWithHistory(
        system: String,
        history: [CoachMessage],
        userMessage: String,
        model: ClaudeModel = .sonnet46,
        maxTokens: Int = 1200
    ) async throws -> String {
        try await CoachAPITransport.complete(
            task: .chat,
            system: system,
            userText: userMessage,
            history: history,
            model: model,
            maxTokens: maxTokens
        )
    }
}
