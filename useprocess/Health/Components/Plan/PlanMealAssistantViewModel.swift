import SwiftUI
import UIKit

// MARK: - Messages

struct PlanMealChatMessage: Identifiable, Equatable {
    enum Role: Equatable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let text: String
    var mealPreview: MealSuggestionContent?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        mealPreview: MealSuggestionContent? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.mealPreview = mealPreview
    }
}

struct PlanMealQuickSuggestion: Identifiable, Equatable {
    let id: String
    let label: String
    let prompt: String

    static func globalSuggestions() -> [PlanMealQuickSuggestion] {
        [
            PlanMealQuickSuggestion(
                id: "variant",
                label: "Proposer une variante",
                prompt: "Propose une variante de ce repas adaptée à mes contraintes du jour."
            ),
            PlanMealQuickSuggestion(
                id: "simpler",
                label: "Plus simple",
                prompt: "Simplifie ce repas avec moins d'ingrédients et une préparation plus rapide."
            ),
            PlanMealQuickSuggestion(
                id: "another",
                label: "Un autre repas",
                prompt: "Propose un autre repas différent pour ce créneau."
            )
        ]
    }

    static func itemSuggestions(for item: MealSuggestionItem) -> [PlanMealQuickSuggestion] {
        [
            PlanMealQuickSuggestion(
                id: "missing-\(item.id)",
                label: "Je n'en ai plus",
                prompt: "Je n'ai plus de \(item.name). Remplace-le par une alternative compatible."
            ),
            PlanMealQuickSuggestion(
                id: "dislike-\(item.id)",
                label: "Je n'aime pas",
                prompt: "Je n'aime pas \(item.name). Propose une substitution."
            ),
            PlanMealQuickSuggestion(
                id: "lighter-\(item.id)",
                label: "Portion plus légère",
                prompt: "Réduis la portion de \(item.name) tout en gardant l'équilibre du repas."
            )
        ]
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class PlanMealAssistantViewModel {
    private(set) var messages: [PlanMealChatMessage] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var comparisonCandidate: MealSuggestionContent?
    private(set) var selectedItem: MealSuggestionItem?
    private(set) var itemAlternatives: [String] = []
    private(set) var isLoadingAlternatives = false

    var inputText = ""
    var pendingAttachmentImage: UIImage?
    var isVoiceRecording = false
    var isVoiceExiting = false
    var voiceAudioLevel: CGFloat = 0
    var voiceAudioLevels: [CGFloat] = []

    private var voiceTimerTask: Task<Void, Never>?
    private var voiceTranscript = ""
    private var hasBootstrapped = false

    var isSending: Bool { isLoading }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        appendAssistant(
            """
            Besoin d'ajuster ce repas ? Dis-moi un ingrédient manquant, une substitution ou une variante — \
            je m'adapte à ce que tu as vraiment sous la main.
            """
        )
    }

    func selectItem(
        _ item: MealSuggestionItem?,
        meal: MealSuggestionContent,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?
    ) {
        selectedItem = item
        itemAlternatives = []
        guard let item else { return }
        Task { await loadAlternatives(for: item, meal: meal, plan: plan, day: day, profile: profile) }
    }

    func quickSuggestions(for meal: MealSuggestionContent) -> [PlanMealQuickSuggestion] {
        if let selectedItem {
            var suggestions = PlanMealQuickSuggestion.itemSuggestions(for: selectedItem)
            if !itemAlternatives.isEmpty {
                suggestions += itemAlternatives.prefix(3).map { alt in
                    PlanMealQuickSuggestion(
                        id: "alt-\(alt)",
                        label: alt,
                        prompt: "Remplacer \(selectedItem.name) par \(alt)."
                    )
                }
            }
            return suggestions
        }
        return PlanMealQuickSuggestion.globalSuggestions()
    }

    func sendCurrentMessage(
        meal: MealSuggestionContent,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot
    ) async -> MealSuggestionContent? {
        guard !isLoading else { return nil }

        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let image = pendingAttachmentImage {
            pendingAttachmentImage = nil
            inputText = ""
            return await processPhoto(
                image: image,
                caption: trimmed,
                meal: meal,
                plan: plan,
                day: day,
                profile: profile,
                slot: slot
            )
        }

        guard !trimmed.isEmpty else { return nil }
        inputText = ""
        return await processInstruction(
            displayText: trimmed,
            instruction: trimmed,
            meal: meal,
            plan: plan,
            day: day,
            profile: profile,
            slot: slot
        )
    }

    func sendQuickSuggestion(
        _ suggestion: PlanMealQuickSuggestion,
        meal: MealSuggestionContent,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot
    ) async -> MealSuggestionContent? {
        guard !isLoading else { return nil }
        return await processInstruction(
            displayText: suggestion.label,
            instruction: suggestion.prompt,
            meal: meal,
            plan: plan,
            day: day,
            profile: profile,
            slot: slot
        )
    }

    func acceptComparisonCandidate() -> MealSuggestionContent? {
        guard let candidate = comparisonCandidate else { return nil }
        comparisonCandidate = nil
        appendAssistant(assistantReply(for: candidate), mealPreview: candidate)
        noteMealAdjustment(candidate, trigger: "Nouveau repas choisi")
        return candidate
    }

    func rejectComparisonCandidate() {
        comparisonCandidate = nil
        appendAssistant("Pas de souci — on garde le repas actuel. Tu veux ajuster autre chose ?")
    }

    func stageImageAttachment(_ image: UIImage) {
        pendingAttachmentImage = image
    }

    func clearPendingAttachment() {
        pendingAttachmentImage = nil
    }

    // MARK: - Voice

    func startVoiceRecording() async {
        guard !isLoading, !isVoiceRecording else { return }
        let authorized = await CoachSpeechTranscriber.shared.requestAuthorization()
        guard authorized else {
            errorMessage = CoachSpeechError.permissionDenied.errorDescription
            return
        }
        do {
            try CoachSpeechTranscriber.shared.startRecording()
            errorMessage = nil
            isVoiceExiting = false
            isVoiceRecording = true
            voiceTranscript = ""
            voiceAudioLevel = 0
            voiceAudioLevels = Array(repeating: 0.06, count: 52)
            startVoiceTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelVoiceRecording() {
        guard isVoiceRecording || isVoiceExiting else { return }
        voiceTimerTask?.cancel()
        isVoiceExiting = true
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            CoachSpeechTranscriber.shared.cancelRecording()
            isVoiceRecording = false
            isVoiceExiting = false
            voiceTranscript = ""
            voiceAudioLevel = 0
            voiceAudioLevels = Array(repeating: 0.06, count: 52)
        }
    }

    func confirmVoiceRecording() async -> Bool {
        guard isVoiceRecording else { return false }
        voiceTimerTask?.cancel()
        isVoiceExiting = true
        try? await Task.sleep(for: .milliseconds(180))

        let fallback = voiceTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let captured = CoachSpeechTranscriber.shared.stopRecording()
        let finalText = captured.isEmpty ? fallback : captured

        isVoiceRecording = false
        isVoiceExiting = false
        voiceTranscript = ""
        voiceAudioLevel = 0
        voiceAudioLevels = Array(repeating: 0.06, count: 52)

        guard !finalText.isEmpty else {
            errorMessage = "Aucune voix détectée — réessaie."
            return false
        }

        inputText = finalText
        errorMessage = nil
        return true
    }

    // MARK: - Private

    private func processInstruction(
        displayText: String,
        instruction: String,
        meal: MealSuggestionContent,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot
    ) async -> MealSuggestionContent? {
        appendUser(displayText)
        return await runMealRequest(
            meal: meal,
            plan: plan,
            day: day,
            profile: profile,
            slot: slot,
            mode: resolveMode(instruction: instruction, meal: meal)
        )
    }

    private func processPhoto(
        image: UIImage,
        caption: String,
        meal: MealSuggestionContent,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot
    ) async -> MealSuggestionContent? {
        let userLine = caption.isEmpty ? "Voici une photo de mes ingrédients." : caption
        appendUser(userLine)

        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                Task {
                    _ = await self.processPhoto(
                        image: image,
                        caption: caption,
                        meal: meal,
                        plan: plan,
                        day: day,
                        profile: profile,
                        slot: slot
                    )
                }
            }
            return nil
        }

        guard ClaudeConfiguration.isConfigured else {
            errorMessage = "Coach IA indisponible — configure l'API Claude."
            appendAssistant("Je ne peux pas analyser la photo pour l'instant. Réessaie dans un instant.")
            return nil
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let content = try await OriginMealSuggestionService.suggestFromPhoto(
                image: image,
                plan: plan,
                day: day,
                profile: profile,
                slot: slot
            )
            appendAssistant(assistantReply(for: content), mealPreview: content)
            noteMealAdjustment(content, trigger: "Photo ingrédients")
            syncSelection(with: content)
            return content
        } catch {
            errorMessage = "Analyse photo impossible."
            appendAssistant("Je n'ai pas réussi à lire la photo. Décris plutôt ce que tu as sous la main.")
            return nil
        }
    }

    private func runMealRequest(
        meal: MealSuggestionContent,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot,
        mode: OriginMealSuggestionService.RequestMode
    ) async -> MealSuggestionContent? {
        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded {
                Task {
                    _ = await self.runMealRequest(
                        meal: meal,
                        plan: plan,
                        day: day,
                        profile: profile,
                        slot: slot,
                        mode: mode
                    )
                }
            }
            return nil
        }

        guard ClaudeConfiguration.isConfigured else {
            errorMessage = "Coach IA indisponible — configure l'API Claude."
            appendAssistant("Coach indisponible pour l'instant. Réessaie dans quelques instants.")
            return nil
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let content = try await OriginMealSuggestionService.suggest(
                plan: plan,
                day: day,
                profile: profile,
                mode: mode,
                slot: slot
            )

            if case .another = mode {
                comparisonCandidate = content
                appendAssistant(
                    """
                    Voici une autre idée : \(content.name). \
                    Tu préfères garder ton repas actuel ou essayer celui-ci ?
                    """,
                    mealPreview: content
                )
                return nil
            }

            appendAssistant(assistantReply(for: content), mealPreview: content)
            noteMealAdjustment(content, trigger: instructionSummary(for: mode))
            syncSelection(with: content)
            return content
        } catch {
            errorMessage = "Impossible d'ajuster le repas. Réessaie."
            appendAssistant("Je n'ai pas réussi à ajuster le repas. Reformule ta demande ou choisis une suggestion.")
            return nil
        }
    }

    private func loadAlternatives(
        for item: MealSuggestionItem,
        meal: MealSuggestionContent,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?
    ) async {
        isLoadingAlternatives = true
        itemAlternatives = []
        defer { isLoadingAlternatives = false }

        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI,
              ClaudeConfiguration.isConfigured else { return }

        do {
            itemAlternatives = try await OriginMealSuggestionService.suggestItemAlternatives(
                plan: plan,
                day: day,
                profile: profile,
                current: meal,
                item: item
            )
        } catch {
            itemAlternatives = []
        }
    }

    private func resolveMode(
        instruction: String,
        meal: MealSuggestionContent
    ) -> OriginMealSuggestionService.RequestMode {
        let lower = instruction.lowercased()

        if lower.contains("autre repas")
            || lower.contains("remplace tout")
            || lower.contains("propose un autre")
            || lower.contains("un autre repas") {
            return .another(previous: meal)
        }

        if let focused = selectedItem ?? matchedItem(in: instruction, meal: meal) {
            return .modifyItem(
                current: meal,
                item: focused,
                instruction: instruction
            )
        }

        return .modify(current: meal, instruction: instruction)
    }

    private func matchedItem(in text: String, meal: MealSuggestionContent) -> MealSuggestionItem? {
        let lower = text.lowercased()
        let scored = meal.items.map { ($0, score(item: $0, in: lower)) }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return best.0
    }

    private func score(item: MealSuggestionItem, in text: String) -> Int {
        let name = item.name.lowercased()
        if text.contains(name) { return name.count + 10 }
        let tokens = name.split(separator: " ").map(String.init)
        let hits = tokens.filter { $0.count > 2 && text.contains($0) }.count
        return hits * 4
    }

    private func syncSelection(with meal: MealSuggestionContent) {
        guard let current = selectedItem else { return }
        if let updated = meal.items.first(where: { $0.id == current.id }) {
            selectedItem = updated
        } else if let byName = meal.items.first(where: {
            $0.name.caseInsensitiveCompare(current.name) == .orderedSame
        }) {
            selectedItem = byName
        } else {
            selectedItem = nil
            itemAlternatives = []
        }
    }

    private func assistantReply(for meal: MealSuggestionContent) -> String {
        var parts: [String] = ["Repas mis à jour : \(meal.name)."]
        if !meal.scoreSummary.isEmpty {
            parts.append(meal.scoreSummary)
        } else if !meal.coachTip.isEmpty {
            parts.append(meal.coachTip)
        }
        return parts.joined(separator: " ")
    }

    private func appendUser(_ text: String) {
        messages.append(PlanMealChatMessage(role: .user, text: text))
    }

    private func appendAssistant(_ text: String, mealPreview: MealSuggestionContent? = nil) {
        messages.append(
            PlanMealChatMessage(
                role: .assistant,
                text: text,
                mealPreview: mealPreview
            )
        )
    }

    private func noteMealAdjustment(_ meal: MealSuggestionContent, trigger: String) {
        let ingredients = meal.items.map(\.name).joined(separator: ", ")
        CoachMemoryStore.shared.recordPlanAdjustment(
            "Repas \(meal.mealType) — \(meal.name) : \(ingredients.prefix(100)) · \(trigger.prefix(80))"
        )
    }

    private func instructionSummary(for mode: OriginMealSuggestionService.RequestMode) -> String {
        switch mode {
        case .another: return "Autre repas"
        case .modify(_, let instruction): return instruction ?? "Variante"
        case .modifyItem(_, let item, let instruction): return "\(item.name) : \(instruction)"
        default: return "Ajustement"
        }
    }

    private func startVoiceTimer() {
        voiceTimerTask?.cancel()
        voiceTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { break }
                voiceTranscript = CoachSpeechTranscriber.shared.partialTranscript
                voiceAudioLevel = CoachSpeechTranscriber.shared.audioLevel
                voiceAudioLevels = CoachSpeechTranscriber.shared.audioLevels
            }
        }
    }
}
