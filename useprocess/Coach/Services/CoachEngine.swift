import Foundation
import UIKit

/// Moteur IA central — point d'entrée unique pour Claude dans toute l'application.
@MainActor
enum CoachEngine {

    private static var chatSystemPrompt: String {
        """
        Tu es le coach useprocess. Style Enzo : direct, tutoiement, bienveillant.

        RÈGLES CHAT :
        - Le Protocole Origine (plan 13 semaines) est TA BASE. Chaque réponse doit s'y rattacher.
        - Tu as accès à la mémoire, au calendrier jour par jour, à la santé HealthKit et aux scans — utilise-les.
        - Réponses courtes (2–4 phrases) sauf demande de détail plan / modification / programme complet.
        - 1 insight + 1 action concrète minimum. Français. Pas de diagnostic médical. Zéro pilule.
        - PAS de markdown dans tes réponses (pas de **, pas de #, pas de listes avec tirets).
        """
    }

    private static let planModificationPrompt = """
    
    ⚡ MODE MODIFICATION DU PLAN — ACTIF :
    - L'utilisateur demande de MODIFIER son Protocole Origine dans l'app.
    - L'application APPLIQUE AUTOMATIQUEMENT tes changements dans le calendrier (91 jours).
    - EXÉCUTE sa demande telle quelle. Pas de refus. Pas de score de pertinence.
    - PAS de markdown (pas de **, pas de #). Texte brut uniquement.
    - Confirme en 2–3 phrases ce qui a changé.
    - Pour nutrition OMAD / 1 repas : écris « Repas unique: [contenu] » (pas PDJ/déj/dîner vides).
    - Tu peux ajouter 1 suggestion optionnelle à la fin (« Si tu veux, on peut aussi… ») — l'utilisateur n'est pas obligé de répondre.
    """

    private static let mealSuggestionPrompt = """

    🍽 MODE REPAS — ACTIF :
    L'utilisateur demande une idée de repas. Réponds UNIQUEMENT avec ce format (labels exacts, pas de markdown) :

    MEAL_NAME: [nom appétissant court]
    MEAL_TYPE: [Petit-déjeuner|Déjeuner|Dîner|Collation]
    SCORE: [0-100 alignement Protocole Origine]
    SCORE_WHY: [1 phrase max]
    ITEM_1: [aliment] | [quantité] | [Protéine|Glucide|Légume|Gras|Autre]
    ITEM_2: [aliment] | [quantité] | [role]
    ITEM_3: [aliment] | [quantité] | [role]
    PREP_MIN: [minutes]
    PREP: [1 phrase préparation]
    TIP: [1 conseil coach court]
    TAG_1: [tag court ex: Anti-gonflement]
    TAG_2: [tag optionnel]
    SCORE_PROTOCOL: [0-100]
    SCORE_SATIETY: [0-100]
    SCORE_BLOAT: [0-100]

    - 3 à 5 items. Protocole Origine : dense, peu transformé, protéines + légumes/tubercules cuits.
    """

    private static func isMealQuestion(_ text: String?) -> Bool {
        guard let text else { return false }
        return CoachMealMessageDetector.isMealRelated(userText: text)
    }

    private static func contextualSystem(profile: UnifiedUserProfile?, planFocus: CoachPlanFocus? = nil, userText: String? = nil) -> String {
        CoachMemoryStore.shared.refreshConversationDigests(
            excludingActiveId: CoachConversationLibraryStore.shared.activeConversationId
        )
        let context = UserContextBuilder.build(profile: profile)
        var system = chatSystemPrompt + "\n\n" + UserContextBuilder.compactPromptBlock(from: context)

        let isModify = planFocus?.mode == .modify
            || (userText.flatMap { CoachPlanModificationService.detectIntent(in: $0) } != nil)

        if isModify {
            system += planModificationPrompt
        } else if isMealQuestion(userText) {
            system += mealSuggestionPrompt
        }

        if let focus = planFocus {
            system += """

            FOCUS PLAN (\(focus.mode.rawValue)) :
            Section : \(focus.sectionTitle)
            Chemin : \(focus.sectionPath)
            Contenu actuel :
            \(focus.sectionContent)
            """
        }
        return system
    }

    // MARK: - Chat (streaming)

    static func streamChatMessage(
        _ text: String,
        profile: UnifiedUserProfile?,
        history: [CoachMessage]? = nil,
        planFocus: CoachPlanFocus? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let system = contextualSystem(profile: profile, planFocus: planFocus, userText: text)
        let resolvedHistory = history ?? CoachConversationStore.loadThreadLocal().messages
        let model = ClaudeModel.preferred(for: .chat)
        let isModify = planFocus?.mode == .modify
            || CoachPlanModificationService.detectIntent(in: text) != nil
        let maxTokens = isModify ? 1400 : 1100
        return CoachAPITransport.streamChat(
            system: system,
            userText: text,
            history: resolvedHistory,
            model: model,
            maxTokens: maxTokens
        )
    }

    static func sendChatMessage(
        _ text: String,
        profile: UnifiedUserProfile?,
        history: [CoachMessage]? = nil,
        planFocus: CoachPlanFocus? = nil
    ) async throws -> CoachMessage {
        var full = ""
        for try await chunk in streamChatMessage(text, profile: profile, history: history, planFocus: planFocus) {
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
        let system = contextualSystem(profile: profile, planFocus: nil, userText: caption)
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

        let validatedMealHint: String = {
            guard let plan = WelcomePlanStore.shared.plan else { return "" }
            let idx = plan.calendar.currentProgramDayIndex()
            guard let day = plan.calendar.day(globalIndex: idx),
                  let raw = plan.progress.validatedMeals[day.id],
                  let meal = MealSuggestionContent.fromStored(raw) else { return "" }
            return "\nRepas validé aujourd'hui : \(meal.name) (score \(meal.protocolScore)/100)."
        }()

        let prompt = """
        \(nameHint)
        \(UserContextBuilder.compactPromptBlock(from: context))\(validatedMealHint)

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
        let hasScans = context.lastBodyScan != nil
            || context.latestFaceScan != nil
            || !(context.recentFaceScans?.isEmpty ?? true)
            || !(context.recentScans?.isEmpty ?? true)
        let scanInstruction = hasScans
            ? "Tu peux t'appuyer sur les données de scan si elles sont présentes dans le contexte."
            : "IMPORTANT : aucun scan visage ni corporel n'a été effectué. Ne dis JAMAIS « ton scan révèle » ni ne fais référence à un scan — base-toi uniquement sur le profil et les données HealthKit."
        let prompt = """
        \(scanInstruction)
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
            return nil
        }
    }

    // MARK: - Private body scan

    private static func bodyScanVisionSummary(result: BodyScanResult) async -> String? {
        guard ProcessPrivacyConsentStore.shared.canSendFacePhotoToAI else { return nil }
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
