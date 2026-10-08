import Foundation
import UIKit

/// Moteur IA central — point d'entrée unique pour Claude dans toute l'application.
@MainActor
enum CoachEngine {

    private static var replyLanguageLock: String {
        ProcessAppLanguage.currentCode.llmLanguageDirective
    }

    private static var chatSystemPrompt: String {
        if !ProcessAppLanguage.usesFrenchCopy {
            return """
            You are the useprocess coach. Enzo style: direct, warm, singular “you”.

            CHAT RULES:
            - Natural conversation only. You have access to the user’s debloat plan / protocol — use it to advise.
            - Clear, airy answers. No sheets, cards, or templates.
            - If you list meals, steps, or options: one line per point, prefixed with a dash (– ). Example:
              Today’s meals:
              – Breakfast: yogurt blueberries honey
              – Lunch: chicken avocado salad
              – Dinner: steak arugula potatoes
            - FORBIDDEN: structured meal format (INTRO:, MEAL_NAME:, ITEM_*, SCORE:, PREP:, TIP:, TAG_*).
            - Nutrition: advise from TODAY’S MEALS / the plan — do not generate a meal sheet.
            - Rest day: say it clearly. Do not propose “change the workout” or UI actions.
            - \(replyLanguageLock) No medical diagnosis. No pills.
            """
        }
        return """
        Tu es le coach useprocess. Style Enzo : direct, tutoiement, bienveillant.

        RÈGLES CHAT :
        - Discussion naturelle uniquement. Tu as accès au plan debloat / protocole de l'utilisateur — utilise-le pour conseiller.
        - Réponses claires et aérées. Pas de fiches, pas de cartes, pas de templates.
        - Si tu listes des repas, étapes ou options : une ligne par point, préfixée d'un tiret (– ). Exemple :
          Tes repas du jour :
          – Petit-déj : yaourt myrtilles miel
          – Déjeuner : salade poulet avocat
          – Dîner : steak roquette pommes de terre
        - INTERDIT : format structuré repas (INTRO:, MEAL_NAME:, ITEM_*, SCORE:, PREP:, TIP:, TAG_*).
        - Si on parle nutrition : conseille en t'appuyant sur REPAS AUJOURD'HUI / le plan — sans générer une fiche repas.
        - Si c'est un jour de repos : dis-le clairement. Ne propose pas de « changer la séance » ni d'actions UI.
        - Français. Pas de diagnostic médical. Zéro pilule. Pas de markdown (** #).
        """
    }

    private static var planModificationPrompt: String {
        if !ProcessAppLanguage.usesFrenchCopy {
            return """
            ⚡ PLAN MODIFICATION MODE — ACTIVE:
            - The user wants to MODIFY their personalized plan in the app.
            - The app AUTOMATICALLY APPLIES your changes to the plan calendar.
            - EXECUTE the request as stated. No refusal. No relevance score.
            - NO markdown (no **, no #). Plain text only.
            - If several changes: one line per point with a dash (– ).
            - Confirm in 2–3 sentences what changed.
            - For OMAD / 1 meal nutrition: write “Single meal: [content]” (not empty breakfast/lunch/dinner).
            - You may add 1 optional suggestion at the end (“If you want, we can also…”) — the user is not required to answer.
            - End of reply: ACTION_1: applyPlanChanges|Apply to program
            - For a proposed session, list EACH exercise on its own line:
              Dumbbell press 3x10
              Lateral raises 3x12
              Face pulls 3x15
            """
        }
        return """
        ⚡ MODE MODIFICATION DU PLAN — ACTIF :
        - L'utilisateur demande de MODIFIER son plan personnalisé dans l'app.
        - L'application APPLIQUE AUTOMATIQUEMENT tes changements dans le calendrier du plan.
        - EXÉCUTE sa demande telle quelle. Pas de refus. Pas de score de pertinence.
        - PAS de markdown (pas de **, pas de #). Texte brut uniquement.
        - Si plusieurs changements : une ligne par point avec tiret (– ).
        - Confirme en 2–3 phrases ce qui a changé.
        - Pour nutrition OMAD / 1 repas : écris « Repas unique: [contenu] » (pas PDJ/déj/dîner vides).
        - Tu peux ajouter 1 suggestion optionnelle à la fin (« Si tu veux, on peut aussi… ») — l'utilisateur n'est pas obligé de répondre.
        - Fin de réponse : ACTION_1: applyPlanChanges|Appliquer au programme
        - Pour une séance proposée, liste CHAQUE exercice sur sa propre ligne (pas en pavé) :
          Développé haltères 3x10
          Élévations latérales 3x12
          Face pulls 3x15
        """
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

        system += CoachIntelligencePromptBuilder.intelligenceBlock(isModify: isModify)
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
        try await analyzeAttachedImages(
            [image],
            caption: caption,
            profile: profile,
            history: history
        )
    }

    static func analyzeAttachedImages(
        _ images: [UIImage],
        caption: String,
        profile: UnifiedUserProfile?,
        history: [CoachMessage]
    ) async throws -> CoachMessage {
        let jpegs = await Task.detached(priority: .userInitiated) {
            images.compactMap { $0.jpegData(compressionQuality: 0.72) }
        }.value
        guard !jpegs.isEmpty else {
            throw ClaudeAPIError.invalidResponse
        }

        let system = contextualSystem(profile: profile, planFocus: nil, userText: caption)
        let model = ClaudeModel.preferred(for: .chat)
        let maxTokens = min(380 + jpegs.count * 60, 900)

        let text: String
        if jpegs.count == 1 {
            text = try await CoachAPITransport.complete(
                task: .chat,
                system: system,
                userText: caption,
                history: history,
                model: model,
                imageBase64: jpegs[0].base64EncodedString(),
                maxTokens: maxTokens
            )
        } else if CoachAPITransport.activeMode == .remote {
            let remoteCaption = caption + "\n(L'utilisateur a envoyé \(jpegs.count) photos.)"
            text = try await CoachAPITransport.complete(
                task: .chat,
                system: system,
                userText: remoteCaption,
                history: history,
                model: model,
                imageBase64: jpegs[0].base64EncodedString(),
                maxTokens: maxTokens
            )
        } else {
            text = try await ClaudeLocalAPIService.completeWithImages(
                system: system,
                prompt: caption,
                jpegDatas: jpegs,
                model: model,
                maxTokens: maxTokens
            )
        }

        return CoachMessage(role: .assistant, text: text, modelUsed: model.rawValue)
    }

    static func runTool(
        _ tool: CoachTool,
        profile: UnifiedUserProfile?
    ) async throws -> CoachMessage {
        let context = UserContextBuilder.build(profile: profile)
        let prompt = tool.buildPrompt(context: context) + AppCopy.tSync(
            "\n\nRéponds en MAX 3 phrases.\n\n",
            en: "\n\nReply in MAX 3 sentences.\n\n"
        ) + UserContextBuilder.compactPromptBlock(from: context)
        let model = ClaudeModel.preferred(for: .quickHint)

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

    private static var dailyBriefSystemPrompt: String {
        if !ProcessAppLanguage.usesFrenchCopy {
            return """
            You are the Process coach. Address ONE person (you / your).
            Never “guys”, never group plural.

            Health brief: short, clear, actionable. No medical diagnosis.
            No biology lecture. No markdown. No long lists.
            \(replyLanguageLock)
            """
        }
        return """
        Tu es le coach Process. Tu t'adresses à UNE seule personne (tu / ton / ta).
        Jamais « les gars », jamais pluriel de groupe, jamais tutoiement collectif.

        Brief Santé : court, clair, actionnable. Pas de diagnostic médical.
        Pas de cours de biologie. Pas de markdown. Pas de listes longues.
        """
    }

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
        let nameHint: String = {
            guard firstName?.isEmpty == false, let firstName else { return "" }
            return AppCopy.tSync("Prénom : \(firstName).", en: "First name: \(firstName).")
        }()

        let validatedMealHint: String = {
            guard let plan = WelcomePlanStore.shared.plan else { return "" }
            return "\n" + CoachPlanContextBuilder.todayMealsBlock(plan: plan)
        }()

        let prompt = """
        \(nameHint)
        \(UserContextBuilder.compactPromptBlock(from: context))\(validatedMealHint)

        \(AppCopy.tSync(
            """
            Génère le brief du jour. Réponds UNIQUEMENT avec ces 4 lignes (labels exacts) :

            VERDICT: [1 phrase, max 12 mots — état du jour basé sur sommeil / plan]
            POURQUOI: [1 phrase, max 18 mots — cause principale]
            ACTION_1: [action concrète pour aujourd'hui]
            ACTION_2: [action concrète pour demain]

            Règles : tutoiement singulier, 2 actions max, pas de pavé, pas de chiffres inventés, jamais le mot readiness.
            """,
            en: """
            Generate today’s brief. Reply ONLY with these 4 lines (exact labels):

            VERDICT: [1 sentence, max 12 words — today’s state based on sleep / plan]
            POURQUOI: [1 sentence, max 18 words — main cause]
            ACTION_1: [concrete action for today]
            ACTION_2: [concrete action for tomorrow]

            Rules: singular you, 2 actions max, no walls of text, no invented numbers, never the word readiness. \(replyLanguageLock)
            """
        ))
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

    // MARK: - Scan visage

    private static var faceScanSystemPrompt: String {
        if !ProcessAppLanguage.usesFrenchCopy {
            return """
            You describe visible appearance and capture quality only. All supplied indices are experimental visual heuristics, not biological measurements. Never infer hormones, cortisol, fluid amounts, fat, inflammation, disease, or the cause of a change. Do not establish causal links with nutrition or promise improvement. Compare only captures in similar conditions; state uncertainty.
            Address ONE person (you). Never “guys”. No medical diagnosis.
            \(replyLanguageLock) Every user-visible sentence must follow it.
            """
        }
        return """
        Tu décris uniquement l’apparence visible et la qualité de capture. Tous les indices fournis sont des heuristiques visuelles expérimentales, pas des mesures biologiques. N’infère jamais hormones, cortisol, quantité d’eau, graisse, inflammation, maladie ou cause d’un changement. N’établis pas de lien causal avec l’alimentation et ne promets pas d’amélioration. Compare uniquement des captures similaires et explique l’incertitude.
        Tu t'adresses à UNE personne (tu). Jamais « les gars ». Pas de diagnostic médical.
        """
    }

    @MainActor
    static func analyzeFaceScan(
        result: FaceScanResult,
        profile: UnifiedUserProfile?,
        history: [FaceScanResult]
    ) async -> FaceScanResult? {
        guard ClaudeConfiguration.isConfigured else { return nil }

        let context = UserContextBuilder.build(profile: profile)
        let historyBlock = faceScanHistoryBlock(history: history, current: result)
        let markers = result.markers
        let relativeBlock = relativeFaceScanBlock(result)
        let insightContext = FaceScanInsightContext.fromTodayHealth()
        let factsBlock = FaceScanEvolutionEngine.factsPromptBlock(
            for: result,
            history: history,
            context: insightContext
        )

        let definitionScore = FaceScanIndicators.definitionScore(from: markers)
        let stressLoad = FaceScanIndicators.stressLoad(for: result)
        let prompt = """
        \(UserContextBuilder.compactPromptBlock(from: context))

        \(AppCopy.tSync(
            """
            Règle critique : ne juge jamais la forme naturelle du visage. Un visage large, fin, asymétrique ou avec traits marqués n'est jamais un défaut.
            Décris seulement les variations d’apparence et de qualité de capture, sensibles à la lumière et à la pose.
            Base ton analyse sur les FAITS ci-dessous — ne les recopie pas mot pour mot, mais respecte leur direction (hausse/baisse/persistance).

            Scores locaux (0-100). Ces indices décrivent l’apparence ou la qualité de capture, sans mesure biologique :
            - Aspect gonflé apparent : \(markers.puffinessScore)
            - Récupération (cernes / fatigue) : \(markers.underEyeFatigueScore)
            - Qualité de capture : \(markers.skinClarityScore)
            - Définition (mâchoire / pommettes) : \(definitionScore)
            - Indice visuel expérimental, sans mesure hormonale : \(stressLoad)
            """,
            en: """
            Critical rule: never judge the natural shape of the face. A wide, slim, asymmetric, or strongly featured face is never a flaw.
            Describe only appearance and capture-quality changes, sensitive to lighting and pose.
            Base your analysis on the FACTS below — do not copy them word for word, but respect their direction (up/down/persisting).

            Local scores (0-100). These indices describe appearance or capture quality, not biology:
            - Apparent puffiness: \(markers.puffinessScore)
            - Recovery (under-eyes / fatigue): \(markers.underEyeFatigueScore)
            - Capture quality: \(markers.skinClarityScore)
            - Definition (jaw / cheekbones): \(definitionScore)
            - Experimental visual index, no hormone measurement: \(stressLoad)
            """
        ))

        \(relativeBlock)

        \(historyBlock)

        \(factsBlock)

        \(AppCopy.tSync(
            """
            Règles obligatoires :
            - Aucun indice ne prouve une rétention d’eau, une fatigue biologique ou un niveau de stress.
            - Décris l’apparence avec prudence et la comparabilité des captures ; n’attribue pas les changements à un aliment ou une hormone.
            - Si les captures ne sont pas comparables, signale l’incertitude plutôt qu’une évolution certaine.
            - Propose seulement des actions de suivi : capture sous une lumière similaire, noter ses habitudes ; pas de diagnostic ni traitement.

            Analyse cette photo + faits évolutifs. Format EXACT (labels inchangés, contenu en français) :

            RESUME: [1 phrase — état global du visage aujourd'hui, max 18 mots, factuel]
            SIGNAUX: [signal 1] | [signal 2] | [signal 3 max — observation factuelle]
            EVOLUTION: [1 phrase vs historique récent — compare aux scans précédents, mentionne persistance ou amélioration]
            ACTIONS: [action 1 concrète aujourd'hui] | [action 2 concrète aujourd'hui]
            """,
            en: """
            Mandatory rules:
            - No index proves water retention, biological fatigue or a stress level.
            - Describe appearance and capture comparability cautiously; never attribute changes to a food or hormone.
            - If captures are not comparable, state uncertainty rather than a definite trend.
            - Suggest tracking actions only: similar lighting, recording habits; no diagnosis or treatment.

            Analyze this photo + evolution facts. EXACT format (keep these labels, write VALUES in the required language):

            RESUME: [1 sentence — overall face state today, max 18 words, factual]
            SIGNAUX: [signal 1] | [signal 2] | [signal 3 max — factual observation]
            EVOLUTION: [1 sentence vs recent history — compare to previous scans, mention persistence or improvement]
            ACTIONS: [concrete action for today] | [concrete action for today]
            """
        ))
        """

        do {
            let filename = result.snapshotFilename
            let jpeg = await Task.detached(priority: .userInitiated) { () -> Data? in
                guard let filename, let image = FaceScanImageStore.load(filename: filename) else { return nil }
                return image.jpegData(compressionQuality: 0.78)
            }.value

            let raw = try await CoachAPITransport.complete(
                task: .faceScanVision,
                system: faceScanSystemPrompt,
                userText: prompt,
                model: ClaudeModel.preferred(for: .faceScanVision),
                imageBase64: jpeg?.base64EncodedString(),
                maxTokens: 220
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
        let past = history
            .filter { $0.id != current.id && $0.source == .daily }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(14)
        guard !past.isEmpty else {
            return AppCopy.tSync(
                "Historique : aucun scan précédent enregistré.",
                en: "History: no previous scan on record."
            )
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = ProcessAppLanguage.currentLocale
        let en = !ProcessAppLanguage.usesFrenchCopy

        let lines = past.map { scan in
            let date = formatter.string(from: scan.createdAt)
            if let signals = scan.relativeSignals {
                return en
                    ? "- \(date): relative score \(scan.resolvedFaceDayScore), puffiness \(signed(signals.puffinessDelta)), under-eyes \(signed(signals.underEyeFatigueDelta)), jaw \(signed(signals.jawTensionDelta))"
                    : "- \(date) : score relatif \(scan.resolvedFaceDayScore), gonflement \(signed(signals.puffinessDelta)), cernes \(signed(signals.underEyeFatigueDelta)), mâchoire \(signed(signals.jawTensionDelta))"
            } else {
                let m = scan.markers
                return en
                    ? "- \(date): raw scores puffiness \(m.puffinessScore), under-eyes \(m.underEyeFatigueScore), jaw \(m.jawTensionScore)"
                    : "- \(date) : scores bruts gonflement \(m.puffinessScore), cernes \(m.underEyeFatigueScore), mâchoire \(m.jawTensionScore)"
            }
        }
        return AppCopy.tSync("Historique récent :\n", en: "Recent history:\n") + lines.joined(separator: "\n")
    }

    private static func relativeFaceScanBlock(_ result: FaceScanResult) -> String {
        guard let confidence = result.scanConfidence,
              let baselineCount = result.baselineSampleCount,
              let signals = result.relativeSignals else {
            return AppCopy.tSync(
                "Lecture relative : indisponible, utiliser les scores bruts avec prudence.",
                en: "Relative reading unavailable — use raw scores with caution."
            )
        }

        return AppCopy.tSync(
            """
            Lecture relative anti-morphologie :
            - Score relatif visage du jour : \(result.resolvedFaceDayScore)/100
            - Confiance scan : \(confidence)/100 (\(FaceWellnessScore.confidenceLabel(for: confidence)))
            - Baseline : \(signals.localizedBaselineLabel), \(baselineCount) scan(s)
            - Variation d’aspect gonflé apparent vs baseline : \(signed(signals.puffinessDelta))
            - Delta récupération vs baseline : \(signed(signals.underEyeFatigueDelta))
            - Delta peau vs baseline : \(signed(signals.skinClarityDelta))
            - Delta définition vs baseline : \(signed(signals.faceDefinitionDelta ?? 0))
            - Delta charge stress vs baseline : \(signed(signals.stressLoadDelta ?? 0))
            """,
            en: """
            Relative anti-morphology reading:
            - Today’s relative face score: \(result.resolvedFaceDayScore)/100
            - Scan confidence: \(confidence)/100 (\(FaceWellnessScore.confidenceLabel(for: confidence)))
            - Baseline: \(signals.localizedBaselineLabel), \(baselineCount) scan(s)
            - Retention delta vs baseline: \(signed(signals.puffinessDelta))
            - Recovery delta vs baseline: \(signed(signals.underEyeFatigueDelta))
            - Capture-quality delta vs baseline: \(signed(signals.skinClarityDelta))
            - Definition delta vs baseline: \(signed(signals.faceDefinitionDelta ?? 0))
            - Stress-load delta vs baseline: \(signed(signals.stressLoadDelta ?? 0))
            """
        )
    }

    private static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    // MARK: - Body Scan

    static func enhanceBodyScanReport(_ result: BodyScanResult) async -> BodyScanResult {
        guard ClaudeConfiguration.isConfigured else { return result }

        var narrative = result.narrativeReport
        var didEnhance = false

        if let visionNote = await bodyScanVisionSummary(result: result) {
            narrative += AppCopy.tSync(
                "\n\n## Ce que je vois sur ton scan\n\(visionNote)",
                en: "\n\n## What I see on your scan\n\(visionNote)"
            )
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
            ? AppCopy.tSync(
                "Tu peux t'appuyer sur les données de scan si elles sont présentes dans le contexte.",
                en: "You can use scan data if it is present in the context."
            )
            : AppCopy.tSync(
                "IMPORTANT : aucun scan visage ni corporel n'a été effectué. Ne dis JAMAIS « ton scan révèle » ni ne fais référence à un scan — base-toi uniquement sur le profil et les données HealthKit.",
                en: "IMPORTANT: no face or body scan has been done. NEVER say “your scan shows” or refer to a scan — use only the profile and HealthKit data."
            )
        let prompt = """
        \(scanInstruction)
        \(AppCopy.tSync(
            "Génère un résumé du plan personnalisé de l'utilisateur (8-12 phrases, durée exacte dans le contexte).",
            en: "Generate a summary of the user’s personalized plan (8–12 sentences, exact duration from context)."
        ))
        \(UserContextBuilder.promptBlock(from: context))
        \(AppCopy.tSync(
            "Objectif, 3 piliers du plan personnalisé, rythme hebdo, 3 habitudes quotidiennes.",
            en: "Goal, 3 pillars of the personalized plan, weekly rhythm, 3 daily habits."
        ))
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

        let prompt = AppCopy.tSync(
            """
            Analyse cette photo de scan corporel en 4-6 phrases.
            Score posture: \(result.postureScore)/100.
            \(scanMetricsBlock(result))
            Pas de diagnostic médical. Ton direct Enzo.
            """,
            en: """
            Analyze this body-scan photo in 4–6 sentences.
            Posture score: \(result.postureScore)/100.
            \(scanMetricsBlock(result))
            No medical diagnosis. Direct Enzo tone. \(ProcessAppLanguage.currentCode.llmLanguageDirective)
            """
        )

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
        let prompt = AppCopy.tSync(
            """
            Reformate ce rapport scan useprocess (plan personnalisé, max 750 mots).
            \(scanMetricsBlock(result))
            Piliers : \(pillarHints)
            Rapport brut : \(base)
            """,
            en: """
            Reformat this useprocess scan report (personalized plan, max 750 words).
            \(scanMetricsBlock(result))
            Pillars: \(pillarHints)
            Raw report: \(base)
            \(replyLanguageLock)
            """
        )

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
        return AppCopy.tSync(
            """
            Score: \(result.postureScore)/100 | Épaules: \(result.metrics.shoulderAlignmentScore) | Colonne: \(result.metrics.spineAlignmentScore)
            Zones: \(zones)
            Priorités: \(priorities)
            """,
            en: """
            Score: \(result.postureScore)/100 | Shoulders: \(result.metrics.shoulderAlignmentScore) | Spine: \(result.metrics.spineAlignmentScore)
            Zones: \(zones)
            Priorities: \(priorities)
            """
        )
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
