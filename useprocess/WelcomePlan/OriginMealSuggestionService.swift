import Foundation
import UIKit

enum OriginMealSuggestionService {

    enum RequestMode: Equatable {
        case fresh
        case another(previous: MealSuggestionContent)
        case modify(current: MealSuggestionContent)
        case modifyItem(current: MealSuggestionContent, item: MealSuggestionItem, instruction: String)
        case batch(count: Int, slot: MealTimeSlot)
        case itemAlternatives(current: MealSuggestionContent, item: MealSuggestionItem)
        case fromPhoto(slot: MealTimeSlot)
    }

    private static let jsonSchema = """
    {
      "name": "Nom appétissant",
      "mealType": "Petit-déjeuner|Déjeuner|Dîner|Collation",
      "protocolScore": 0-100,
      "scoreSummary": "1 phrase",
      "subScores": {"protocolFit": 0-100, "satiety": 0-100, "antiBloat": 0-100},
      "items": [{"name": "Aliment", "quantity": "150g", "role": "Protéine|Glucide|Légume|Gras|Autre"}],
      "prepMinutes": 15,
      "prepSummary": "1 phrase préparation",
      "coachTip": "1 conseil",
      "tags": ["tag1", "tag2"]
    }
    """

    private static let systemPrompt = """
    Tu es le coach nutrition Process (Protocole Origine debloat visage).
    Style Enzo : direct, tutoiement, bienveillant.
    Propose UN repas concret, dense, peu transformé, protéines + tubercules/légumes cuits.
    Pas de diagnostic médical. Pas de markdown.
    Réponds UNIQUEMENT avec un JSON valide (aucun texte avant/après) :
    \(jsonSchema)
    - 3 à 5 items. protocolScore réaliste (60-95). tags : 2 max.
    """

    @MainActor
    static func suggest(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        mode: RequestMode = .fresh,
        slot: MealTimeSlot? = nil
    ) async throws -> MealSuggestionContent {
        switch mode {
        case .batch(let count, let batchSlot):
            let meals = try await suggestBatch(
                plan: plan, day: day, profile: profile, count: count, slot: batchSlot
            )
            return meals.first ?? MealSuggestionParser.parseOrFallback("")
        case .itemAlternatives(let current, let item):
            let alts = try await suggestItemAlternatives(
                plan: plan, day: day, profile: profile, current: current, item: item
            )
            guard let first = alts.first else {
                throw MealHubError.noAlternatives
            }
            var updated = current
            if let index = updated.items.firstIndex(where: { $0.id == item.id }) {
                updated.items[index].name = first
            }
            return updated
        case .fromPhoto(let photoSlot):
            throw MealHubError.photoRequired
        default:
            break
        }

        let text = try await complete(
            plan: plan,
            day: day,
            profile: profile,
            mode: mode,
            slot: slot
        )
        return decode(text)
    }

    @MainActor
    static func suggestBatch(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        count: Int,
        slot: MealTimeSlot
    ) async throws -> [MealSuggestionContent] {
        var results: [MealSuggestionContent] = []
        var exclude: [String] = []

        for _ in 0..<count {
            let mode: RequestMode
            if let last = results.last {
                mode = .another(previous: last)
            } else {
                mode = .fresh
            }
            let text = try await complete(
                plan: plan,
                day: day,
                profile: profile,
                mode: mode,
                slot: slot,
                extraExclude: exclude
            )
            let meal = decode(text)
            results.append(meal)
            exclude.append(meal.name)
        }
        return results
    }

    @MainActor
    static func suggestItemAlternatives(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        current: MealSuggestionContent,
        item: MealSuggestionItem
    ) async throws -> [String] {
        let context = UserContextBuilder.build(profile: profile)
        let prompt = """
        \(UserContextBuilder.compactPromptBlock(from: context))

        Repas : \(current.name)
        Ingrédient à remplacer : \(item.name) (\(item.quantity), \(item.role))

        Propose EXACTEMENT 3 alternatives compatibles Protocole Origine pour remplacer cet ingrédient.
        Format : ALT_1: [nom] | ALT_2: [nom] | ALT_3: [nom]
        """

        let text = try await CoachAPITransport.complete(
            task: .chat,
            system: systemPrompt,
            userText: prompt,
            model: ClaudeModel.preferred(for: .chat),
            maxTokens: 120
        )

        return parseAlternatives(text)
    }

    @MainActor
    static func suggestFromPhoto(
        image: UIImage,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        slot: MealTimeSlot
    ) async throws -> MealSuggestionContent {
        guard let jpeg = image.jpegData(compressionQuality: 0.72) else {
            throw MealHubError.photoRequired
        }

        let context = UserContextBuilder.build(profile: profile)
        let principles = day.nutrition.principles.joined(separator: " · ")

        let prompt = """
        \(UserContextBuilder.compactPromptBlock(from: context))

        Jour protocole : \(day.title)
        Créneau : \(slot.rawValue)
        Principes : \(principles)

        Analyse cette photo (frigo, placard ou ingrédients visibles).
        Compose UN repas réalisable avec ce que tu vois, aligné Protocole Origine.
        """

        let text = try await CoachAPITransport.complete(
            task: .chat,
            system: systemPrompt + "\n\nObjectif plan : \(plan.primaryFaceGoal)",
            userText: prompt,
            model: ClaudeModel.preferred(for: .chat),
            imageBase64: jpeg.base64EncodedString(),
            maxTokens: 520
        )

        return decode(text)
    }

    // MARK: - Private

    @MainActor
    private static func complete(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        profile: UnifiedUserProfile?,
        mode: RequestMode,
        slot: MealTimeSlot?,
        extraExclude: [String] = []
    ) async throws -> String {
        let context = UserContextBuilder.build(profile: profile)
        let principles = day.nutrition.principles.joined(separator: " · ")
        let foods = day.nutrition.foodsToday.joined(separator: ", ")
        let slotLabel = slot?.rawValue ?? "Repas"
        let planType = plan.nutritionPlanType
        let mealStructure = planType.label
        let slotHint = slot.map { planType.slotGuidance(for: $0) } ?? planType.aiStructureHint

        let userPrompt: String
        switch mode {
        case .fresh:
            userPrompt = """
            \(UserContextBuilder.compactPromptBlock(from: context))

            Jour protocole : \(day.title)
            Créneau cible : \(slotLabel)
            Structure repas : \(mealStructure)
            Consigne créneau : \(slotHint)
            Principes : \(principles)
            Aliments à privilégier : \(foods)
            Hydratation : \(day.nutrition.hydration)

            Propose une idée de repas pour \(slotLabel.lowercased()) aujourd'hui.
            """
        case .another(let previous):
            userPrompt = """
            \(UserContextBuilder.compactPromptBlock(from: context))

            Repas déjà proposé (ne pas répéter) :
            \(previous.encodedForStorage())
            \(excludeBlock(extraExclude))

            Propose un AUTRE repas différent, créneau \(slotLabel).
            """
        case .modify(let current):
            userPrompt = """
            \(UserContextBuilder.compactPromptBlock(from: context))

            Repas actuel :
            \(current.encodedForStorage())

            Propose une VARIANTE ajustée — même esprit, légèrement modifié.
            """
        case .modifyItem(let current, let item, let instruction):
            userPrompt = """
            \(UserContextBuilder.compactPromptBlock(from: context))

            Repas actuel :
            \(current.encodedForStorage())

            Modification sur « \(item.name) (\(item.quantity)) » :
            \(instruction)

            Regénère le repas complet en appliquant cette modification.
            """
        case .batch, .itemAlternatives, .fromPhoto:
            userPrompt = ""
        }

        return try await CoachAPITransport.complete(
            task: .chat,
            system: systemPrompt + "\n\nObjectif plan : \(plan.primaryFaceGoal)",
            userText: userPrompt,
            model: ClaudeModel.preferred(for: .chat),
            maxTokens: 520
        )
    }

    private static func decode(_ text: String) -> MealSuggestionContent {
        let sanitized = MealSuggestionParser.sanitize(text)
        return MealSuggestionParser.parse(sanitized) ?? MealSuggestionParser.parseOrFallback(sanitized)
    }

    private static func excludeBlock(_ names: [String]) -> String {
        guard !names.isEmpty else { return "" }
        return "Noms déjà utilisés : " + names.joined(separator: ", ")
    }

    private static func parseAlternatives(_ raw: String) -> [String] {
        var results: [String] = []
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for prefix in ["ALT_1:", "ALT_2:", "ALT_3:", "ALT 1:", "ALT 2:", "ALT 3:"] {
                if trimmed.uppercased().hasPrefix(prefix) {
                    let value = String(trimmed.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                    let name = value.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? value
                    if !name.isEmpty { results.append(name) }
                }
            }
        }
        if results.isEmpty {
            return raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.prefix(3).map { String($0) }
        }
        return Array(results.prefix(3))
    }
}

enum MealHubError: Error {
    case noAlternatives
    case photoRequired
}
