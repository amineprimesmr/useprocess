import Foundation
import UIKit

/// Moteur IA central — point d'entrée unique pour Claude dans toute l'application.
@MainActor
enum CoachEngine {

    private static var chatSystemPrompt: String {
        """
        Tu es le coach useprocess. Style Enzo : direct, tutoiement, bienveillant.

        RÈGLES CHAT (strictes) :
        - MAX 2-3 phrases courtes. Jamais plus sauf si l'utilisateur demande explicitement un plan détaillé.
        - Réponds UNIQUEMENT à la question posée. Pas de cours, pas de listes, pas d'analyse complète du profil.
        - 1 insight max + 1 action concrète. Cite 0-1 chiffre du contexte si utile.
        - Français. Pas de diagnostic médical. Pas de CTA externe.
        """
    }

    private static func contextualSystem(profile: UnifiedUserProfile?) -> String {
        let context = UserContextBuilder.build(profile: profile)
        return chatSystemPrompt + "\n\n" + UserContextBuilder.compactPromptBlock(from: context)
    }

    // MARK: - Chat (streaming)

    static func streamChatMessage(
        _ text: String,
        profile: UnifiedUserProfile?,
        history: [CoachMessage]? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let system = contextualSystem(profile: profile)
        let resolvedHistory = history ?? CoachConversationStore.loadThreadLocal().messages
        let model = ClaudeModel.preferred(for: .chat)
        return CoachAPITransport.streamChat(
            system: system,
            userText: text,
            history: resolvedHistory,
            model: model,
            maxTokens: 380
        )
    }

    static func sendChatMessage(
        _ text: String,
        profile: UnifiedUserProfile?,
        history: [CoachMessage]? = nil
    ) async throws -> CoachMessage {
        var full = ""
        for try await chunk in streamChatMessage(text, profile: profile, history: history) {
            full += chunk
        }
        return CoachMessage(
            role: .assistant,
            text: full,
            modelUsed: ClaudeModel.preferred(for: .chat).rawValue
        )
    }

    static func analyzeAttachedImage(
        _ image: UIImage,
        caption: String,
        profile: UnifiedUserProfile?,
        history: [CoachMessage]
    ) async throws -> CoachMessage {
        guard let jpeg = image.jpegData(compressionQuality: 0.72) else {
            throw ClaudeAPIError.invalidResponse
        }
        let system = contextualSystem(profile: profile)
        let model = ClaudeModel.preferred(for: .chat)
        let text = try await CoachAPITransport.complete(
            task: .chat,
            system: system,
            userText: caption,
            history: history,
            model: model,
            imageBase64: jpeg.base64EncodedString(),
            maxTokens: 380
        )
        return CoachMessage(role: .assistant, text: text, modelUsed: model.rawValue)
    }

    static func runTool(
        _ tool: CoachTool,
        profile: UnifiedUserProfile?
    ) async throws -> CoachMessage {
        let context = UserContextBuilder.build(profile: profile)
        let prompt = tool.buildPrompt(context: context) + "\n\nRéponds en MAX 3 phrases.\n\n" + UserContextBuilder.compactPromptBlock(from: context)
        let model = ClaudeModel.preferred(for: .readinessAnalysis)

        let text = try await CoachAPITransport.complete(
            task: .tool,
            system: EnzoCoachingVoiceGuide.systemPrompt,
            userText: prompt,
            model: model,
            maxTokens: 280
        )

        return CoachMessage(role: .assistant, text: text, modelUsed: model.rawValue)
    }

    static func welcomeMessage(profile: UnifiedUserProfile?) -> CoachMessage {
        let name = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let greeting = (name?.isEmpty == false) ? "Salut \(name!) 👋" : "Salut 👋"
        let mode = ClaudeConfiguration.transportLabel
        return CoachMessage(
            role: .assistant,
            text: """
            \(greeting) Je suis ton coach useprocess (\(mode)).
            Pose-moi une question — je réponds court et concret.
            """
        )
    }

    // MARK: - Brief quotidien

    static func generateDailyBrief(profile: UnifiedUserProfile?) async -> String? {
        if let cached = CoachConversationStore.cachedDailyBrief() {
            return cached
        }
        guard ClaudeConfiguration.isConfigured else { return nil }

        let context = UserContextBuilder.build(profile: profile)
        let prompt = """
        Génère un brief coaching du jour (5-7 phrases max) pour l'écran Santé useprocess.
        \(UserContextBuilder.promptBlock(from: context))
        Structure : readiness → cause habitudes → 2 actions. Tutoiement direct.
        """

        do {
            let model = ClaudeModel.preferred(for: .dailyBrief)
            let text = try await CoachAPITransport.complete(
                task: .dailyBrief,
                system: EnzoCoachingVoiceGuide.systemPrompt,
                userText: prompt,
                model: model,
                maxTokens: 350
            )
            CoachConversationStore.cacheDailyBrief(text)
            return text
        } catch {
            print("[CoachEngine] dailyBrief: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Readiness

    static func explainReadiness(profile: UnifiedUserProfile?) async -> String? {
        guard ClaudeConfiguration.isConfigured else { return nil }
        do {
            return try await CoachAPITransport.complete(
                task: .readinessAnalysis,
                system: EnzoCoachingVoiceGuide.systemPrompt,
                userText: CoachTool.explainReadiness.buildPrompt(
                    context: UserContextBuilder.build(profile: profile)
                ) + "\n\n" + UserContextBuilder.promptBlock(from: UserContextBuilder.build(profile: profile)),
                model: ClaudeModel.preferred(for: .readinessAnalysis),
                maxTokens: 450
            )
        } catch {
            print("[CoachEngine] readiness: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Body Scan

    static func enhanceBodyScanReport(_ result: BodyScanResult) async -> BodyScanResult {
        guard ClaudeConfiguration.isConfigured else { return result }

        var narrative = result.narrativeReport
        var didEnhance = false

        if let visionNote = await bodyScanVisionSummary(result: result) {
            narrative += "\n\n## Ce que je vois sur ton scan\n\(visionNote)"
            didEnhance = true
        }

        if let fullReport = await bodyScanFullReport(result: result, base: narrative) {
            narrative = fullReport
            didEnhance = true
        }

        guard didEnhance else { return result }

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

    // MARK: - Programme onboarding

    static func generateProgramSummary(profile: UnifiedUserProfile?) async -> String? {
        guard ClaudeConfiguration.isConfigured, profile != nil else { return nil }

        let context = UserContextBuilder.build(profile: profile)
        let prompt = """
        Génère un résumé de plan personnalisé 13 semaines (8-12 phrases).
        \(UserContextBuilder.promptBlock(from: context))
        Objectif, 3 piliers Protocole Origine, rythme hebdo, 3 habitudes quotidiennes.
        """

        do {
            return try await CoachAPITransport.complete(
                task: .programSummary,
                system: EnzoCoachingVoiceGuide.systemPrompt,
                userText: prompt,
                model: ClaudeModel.preferred(for: .programSummary),
                maxTokens: 700
            )
        } catch {
            print("[CoachEngine] programSummary: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Private body scan

    private static func bodyScanVisionSummary(result: BodyScanResult) async -> String? {
        guard let capture = bestCaptureForVision(from: result.captures),
              let path = capture.imagePath,
              let image = BodyScanImageStore.load(filename: path),
              let jpeg = image.jpegData(compressionQuality: 0.72) else {
            return nil
        }

        let prompt = """
        Analyse cette photo de scan corporel en 4-6 phrases.
        Score posture: \(result.postureScore)/100.
        \(scanMetricsBlock(result))
        Pas de diagnostic médical. Ton direct Enzo.
        """

        do {
            return try await CoachAPITransport.complete(
                task: .bodyScanVision,
                system: EnzoCoachingVoiceGuide.systemPrompt,
                userText: prompt,
                model: ClaudeModel.preferred(for: .bodyScanVision),
                imageBase64: jpeg.base64EncodedString(),
                maxTokens: 400
            )
        } catch {
            print("[CoachEngine] vision: \(error.localizedDescription)")
            return nil
        }
    }

    private static func bodyScanFullReport(result: BodyScanResult, base: String) async -> String? {
        let pillarHints = EnzoCoachingVoiceGuide.pillarHints(for: result)
        let prompt = """
        Reformate ce rapport scan useprocess (Protocole Origine, max 750 mots).
        \(scanMetricsBlock(result))
        Piliers : \(pillarHints)
        Rapport brut : \(base)
        """

        do {
            return try await CoachAPITransport.complete(
                task: .bodyScanReport,
                system: EnzoCoachingVoiceGuide.systemPrompt,
                userText: prompt,
                model: ClaudeModel.preferred(for: .bodyScanReport),
                maxTokens: 1400
            )
        } catch {
            print("[CoachEngine] fullReport: \(error.localizedDescription)")
            return nil
        }
    }

    private static func scanMetricsBlock(_ result: BodyScanResult) -> String {
        let zones = result.bodyZones.map { "• \($0.zoneName): \($0.status)" }.joined(separator: "\n")
        let priorities = result.musclePriorities.prefix(3).map { "• \($0.name): \($0.reason)" }.joined(separator: "\n")
        return """
        Score: \(result.postureScore)/100 | Épaules: \(result.metrics.shoulderAlignmentScore) | Colonne: \(result.metrics.spineAlignmentScore)
        Zones: \(zones)
        Priorités: \(priorities)
        """
    }

    private static func bestCaptureForVision(from captures: [BodyScanCaptureRecord]) -> BodyScanCaptureRecord? {
        if let front = captures.first(where: { $0.poseKind == .frontStanding && $0.imagePath != nil }) {
            return front
        }
        return captures
            .filter { $0.poseKind == .turntable && $0.imagePath != nil }
            .min(by: { abs($0.yawDegrees ?? 999) < abs($1.yawDegrees ?? 999) })
    }
}
