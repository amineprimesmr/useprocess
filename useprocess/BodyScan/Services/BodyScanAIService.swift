import Foundation
import UIKit

/// Analyse IA — Claude avec voix coaching Enzo / useprocess.
enum BodyScanAIService {

    private static let model = "claude-sonnet-4-20250514"
    private static let apiVersion = "2023-06-01"

    static func enhanceReport(_ result: BodyScanResult) async -> BodyScanResult {
        guard let apiKey = BodyScanConfiguration.anthropicAPIKey else {
            return result
        }

        var narrative = result.narrativeReport

        if let visionNote = await requestClaudeVisionSummary(result: result, apiKey: apiKey) {
            narrative += "\n\n## Ce que je vois sur ton scan\n\(visionNote)"
        }

        if let fullReport = await requestClaudeFullReport(result: result, apiKey: apiKey, base: narrative) {
            narrative = fullReport
        }

        return BodyScanResult(
            id: result.id,
            userId: result.userId,
            createdAt: result.createdAt,
            postureScore: result.postureScore,
            confidence: min(0.99, result.confidence + 0.06),
            captures: result.captures,
            metrics: result.metrics,
            faceMarkers: result.faceMarkers,
            asymmetries: result.asymmetries,
            musclePriorities: result.musclePriorities,
            bodyZones: result.bodyZones,
            lifestyleInsights: result.lifestyleInsights,
            narrativeReport: narrative,
            aiEnhanced: true,
            disclaimer: result.disclaimer
        )
    }

    // MARK: - Vision

    private static func requestClaudeVisionSummary(result: BodyScanResult, apiKey: String) async -> String? {
        guard let capture = bestCaptureForVision(from: result.captures),
              let path = capture.imagePath,
              let image = BodyScanImageStore.load(filename: path),
              let jpeg = image.jpegData(compressionQuality: 0.72)
        else { return nil }

        let base64 = jpeg.base64EncodedString()
        let metricsSummary = scanContext(result)

        let prompt = """
        Analyse cette photo de scan corporel en 4-6 phrases.
        Relie ce que tu vois aux habitudes possibles (posture, tête en avant, asymétrie, langue, respiration).
        Score posture: \(result.postureScore)/100.
        \(metricsSummary)
        Pas de diagnostic médical. Ton direct Enzo : cause → conséquence courte.
        """

        let content: [[String: Any]] = [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ],
            ["type": "text", "text": prompt]
        ]

        return await claudeMessage(
            apiKey: apiKey,
            system: EnzoCoachingVoiceGuide.systemPrompt,
            content: content,
            maxTokens: 400
        )
    }

    // MARK: - Rapport complet

    private static func requestClaudeFullReport(
        result: BodyScanResult,
        apiKey: String,
        base: String
    ) async -> String? {
        let context = scanContext(result)
        let pillarHints = EnzoCoachingVoiceGuide.pillarHints(for: result)
        let topics = EnzoCoachingVoiceGuide.knownTopics.joined(separator: "\n- ")

        let prompt = """
        Reformate ce rapport de scan corporel useprocess avec le Protocole Origine (4 piliers).

        \(context)

        Piliers à prioriser pour CE scan :
        \(pillarHints)

        Thèmes coaching maîtrisés :
        - \(topics)

        Rapport brut :
        \(base)

        Respecte la structure du system prompt. Maximum 750 mots.
        """

        let content: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]

        return await claudeMessage(
            apiKey: apiKey,
            system: EnzoCoachingVoiceGuide.systemPrompt,
            content: content,
            maxTokens: 1400
        )
    }

    private static func scanContext(_ result: BodyScanResult) -> String {
        let zones = result.bodyZones.map { "• \($0.zoneName): \($0.status) — \($0.detail)" }.joined(separator: "\n")
        let priorities = result.musclePriorities.map { "• \($0.priority). \($0.name) — \($0.reason)" }.joined(separator: "\n")
        let asym = result.asymmetries.isEmpty
            ? "Aucune asymétrie majeure détectée."
            : result.asymmetries.map { "• \($0)" }.joined(separator: "\n")

        var faceBlock = ""
        if let face = result.faceMarkers {
            faceBlock = """
            Marqueurs visage :
            - Clarté: \(face.skinClarityScore)/100
            - Fatigue sous les yeux: \(face.underEyeFatigueScore)/100
            - Gonflement: \(face.puffinessScore)/100
            - Symétrie faciale: \(face.facialSymmetryScore)/100
            """
        }

        return """
        DONNÉES SCAN :
        - Score posture global: \(result.postureScore)/100
        - Confiance: \(Int(result.confidence * 100))%
        - Épaules: \(result.metrics.shoulderAlignmentScore)/100
        - Bassin: \(result.metrics.hipAlignmentScore)/100
        - Colonne: \(result.metrics.spineAlignmentScore)/100
        - Genoux: \(result.metrics.kneeAlignmentScore)/100
        - Symétrie: \(result.metrics.leftRightSymmetryScore)/100

        Asymétries :
        \(asym)

        Zones :
        \(zones)

        Priorités musculaires :
        \(priorities)

        \(faceBlock)
        """
    }

    // MARK: - API

    private static func claudeMessage(
        apiKey: String,
        system: String,
        content: [[String: Any]],
        maxTokens: Int
    ) async -> String? {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]

        return await postJSON(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            headers: [
                "x-api-key": apiKey,
                "anthropic-version": apiVersion
            ],
            body: payload,
            extract: extractClaudeContent
        )
    }

    private static func extractClaudeContent(from json: [String: Any]) -> String? {
        guard let content = json["content"] as? [[String: Any]],
              let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String
        else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bestCaptureForVision(from captures: [BodyScanCaptureRecord]) -> BodyScanCaptureRecord? {
        if let front = captures.first(where: { $0.poseKind == .frontStanding && $0.imagePath != nil }) {
            return front
        }
        return captures
            .filter { $0.poseKind == .turntable && $0.imagePath != nil }
            .min(by: { abs($0.yawDegrees ?? 999) < abs($1.yawDegrees ?? 999) })
    }

    private static func postJSON<T>(
        url: URL,
        headers: [String: String],
        body: [String: Any],
        extract: ([String: Any]) -> T?
    ) async -> T? {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }

            if !(200...299).contains(http.statusCode) {
                let body = String(data: responseData, encoding: .utf8) ?? ""
                print("[Claude API] HTTP \(http.statusCode): \(body.prefix(400))")
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                return nil
            }
            return extract(json)
        } catch {
            print("[Claude API] Network error: \(error.localizedDescription)")
            return nil
        }
    }
}
