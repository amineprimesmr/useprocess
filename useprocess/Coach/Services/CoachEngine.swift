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

    private static let dailyBriefSystemPrompt = """
    Tu es le coach Process AI. Tu t'adresses à UNE seule personne (tu / ton / ta).
    Jamais « les gars », jamais pluriel de groupe, jamais tutoiement collectif.

    Brief Santé : court, clair, actionnable. Pas de diagnostic médical.
    Pas de cours de biologie. Pas de markdown. Pas de listes longues.
    """

    static func generateDailyBrief(
        profile: UnifiedUserProfile?,
        forceRefresh: Bool = false
    ) async -> CoachDailyBriefContent? {
        if !forceRefresh, let cached = CoachConversationStore.cachedDailyBrief() {
            let parsed = CoachDailyBriefParser.parse(cached)
            if parsed.isValid { return parsed }
        }
        guard ClaudeConfiguration.isConfigured else { return nil }

        let context = UserContextBuilder.build(profile: profile)
        let firstName = profile?.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameHint = (firstName?.isEmpty == false) ? "Prénom : \(firstName!)." : ""

        let prompt = """
        \(nameHint)
        \(UserContextBuilder.compactPromptBlock(from: context))

        Génère le brief du jour. Réponds UNIQUEMENT avec ces 4 lignes (labels exacts) :

        VERDICT: [1 phrase, max 12 mots — état readiness]
        POURQUOI: [1 phrase, max 18 mots — cause principale]
        ACTION_1: [action concrète pour aujourd'hui]
        ACTION_2: [action concrète pour demain]

        Règles : tutoiement singulier, 2 actions max, pas de pavé, pas de chiffres inventés.
        """

        do {
            let model = ClaudeModel.preferred(for: .dailyBrief)
            let text = try await CoachAPITransport.complete(
                task: .dailyBrief,
                system: dailyBriefSystemPrompt,
                userText: prompt,
                model: model,
                maxTokens: 160
            )
            let sanitized = CoachDailyBriefParser.sanitize(text)
            CoachConversationStore.cacheDailyBrief(sanitized)
            return CoachDailyBriefParser.parse(sanitized)
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

    // MARK: - Scan visage

    private static let faceScanSystemPrompt = """
    Tu es le coach Process AI — analyse visage wellness (rétention d'eau, fatigue, cortisol, tension mâchoire/cervicales).
    Tu t'adresses à UNE personne (tu). Jamais « les gars ». Pas de diagnostic médical.
    """

    static func analyzeFaceScan(
        result: FaceScanResult,
        profile: UnifiedUserProfile?,
        history: [FaceScanResult]
    ) async -> FaceScanResult? {
        guard ClaudeConfiguration.isConfigured else { return nil }

        let context = UserContextBuilder.build(profile: profile)
        let historyBlock = faceScanHistoryBlock(history: history, current: result)
        let markers = result.markers

        let prompt = """
        \(UserContextBuilder.compactPromptBlock(from: context))

        Scores locaux (0-100, plus haut = signal plus marqué pour fatigue/gonflement/tension) :
        - Gonflement : \(markers.puffinessScore)
        - Cernes / fatigue : \(markers.underEyeFatigueScore)
        - Tension mâchoire : \(markers.jawTensionScore)
        - Clarté peau : \(markers.skinClarityScore)
        - Symétrie : \(markers.facialSymmetryScore)

        \(historyBlock)

        Analyse cette photo + scores. Format EXACT :

        RESUME: [1 phrase — état global du visage aujourd'hui, max 18 mots]
        SIGNAUX: [signal 1] | [signal 2] | [signal 3 max — ex: rétention eau, cortisol, cervicales]
        EVOLUTION: [1 phrase vs scan précédent si historique, sinon "Premier scan de référence."]
        CONSEIL_1: [action concrète aujourd'hui]
        CONSEIL_2: [action demain matin]
        """

        do {
            let jpeg: Data?
            if let filename = result.snapshotFilename,
               let image = FaceScanImageStore.load(filename: filename) {
                jpeg = image.jpegData(compressionQuality: 0.78)
            } else {
                jpeg = nil
            }

            let raw = try await CoachAPITransport.complete(
                task: .faceScanVision,
                system: faceScanSystemPrompt,
                userText: prompt,
                model: ClaudeModel.preferred(for: .faceScanVision),
                imageBase64: jpeg?.base64EncodedString(),
                maxTokens: 320
            )

            var updated = result
            updated.claudeAnalysis = FaceScanAnalysisParser.sanitize(raw)
            updated.aiEnhanced = true
            return updated
        } catch {
            print("[CoachEngine] faceScan: \(error.localizedDescription)")
            return nil
        }
    }

    static func parsedFaceAnalysis(for result: FaceScanResult) -> FaceScanAnalysisContent {
        guard let text = result.claudeAnalysis else { return .empty }
        return FaceScanAnalysisParser.parse(text)
    }

    private static func faceScanHistoryBlock(history: [FaceScanResult], current: FaceScanResult) -> String {
        let past = history.filter { $0.id != current.id }.prefix(6)
        guard !past.isEmpty else { return "Historique : aucun scan précédent enregistré." }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")

        let lines = past.map { scan in
            let date = formatter.string(from: scan.createdAt)
            let m = scan.markers
            return "- \(date) : gonflement \(m.puffinessScore), cernes \(m.underEyeFatigueScore), mâchoire \(m.jawTensionScore)"
        }
        return "Historique récent :\n" + lines.joined(separator: "\n")
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
