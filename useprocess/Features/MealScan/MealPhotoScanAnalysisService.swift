import Foundation
import UIKit

/// Analyse vision repas — indépendant du catalogue Process.
/// Ne doit lister QUE ce qui est visible sur la photo.
enum MealPhotoScanAnalysisService {

    /// Format labelé — même pattern que le scan visage (plus fiable que JSON pur).
    private static let labeledFormatExample = """
    MEAL_NAME: Patate douce et crème
    MEAL_TYPE: Repas
    SCORE: 58
    SCORE_WHY: Glucides OK mais crème lactée = risque rétention.
    ITEM_1: Patate douce | 200 g | Glucide
    ITEM_2: Crème fraîche | 2 c. à soupe | Gras
    PREP: Assiette maison, cuisson douce
    TIP: Remplace la crème par yaourt grec nature pour limiter le lactose.
    """

    private static let visionSystemPrompt = """
    Tu es un analyseur VISUEL de repas pour Process (debloat visage).
    Tu regardes la photo et tu décris UNIQUEMENT ce qui est réellement visible.

    INTERDIT :
    - Inventer des aliments absents de la photo
    - Reprendre une recette catalogue Process
    - Compléter le repas pour le rendre « équilibré »
    - Markdown, JSON, texte libre

    OBLIGATOIRE :
    - 1 à 4 lignes ITEM_ (aliments visibles seulement)
    - SCORE honnête selon debloat (sel, sodium, lactose, ultra-transformés)
    - Si aucun aliment visible : MEAL_NAME: Aucun repas détecté, SCORE: 0, ITEM_1: Photo sans aliment | — | Autre

    Réponds UNIQUEMENT avec ces labels (une ligne par label) :
    \(labeledFormatExample)
    """

    private static let optimizeSystemPrompt = """
    Tu optimises un repas DÉJÀ SCANNÉ pour le debloat visage Process.
    Tu partes des ingrédients du scan — tu ne remplaces pas le repas par une recette catalogue.

    AUTORISÉ : retirer/substituer un ingrédient pénalisant, ajouter max 1 élément debloat simple.
    INTERDIT : repas catalogue complet, ingrédients absents du scan original.

    Même format labelé (MEAL_NAME, SCORE, SCORE_WHY, ITEM_1…, PREP, TIP). Pas de JSON. Pas de markdown.
    """

    // MARK: - Public

    @MainActor
    static func analyzePhoto(
        image: UIImage,
        slot: MealTimeSlot,
        profile: UnifiedUserProfile?
    ) async throws -> MealSuggestionContent {
        guard let jpeg = prepareImageData(image) else {
            throw MealHubError.photoRequired
        }

        let imageBase64 = jpeg.base64EncodedString()
        let prompt = """
        Analyse VISUELLE de cette photo de repas.
        Liste uniquement les aliments visibles avec portions estimées.
        """

        let text = try await completeVision(
            system: visionSystemPrompt,
            userText: prompt,
            imageBase64: imageBase64,
            maxTokens: 480
        )

        var meal = try parsePhotoScanResponse(text)

        if meal.isNoFoodDetected {
            throw MealHubError.noFoodVisible
        }

        meal = sanitize(meal, slot: slot)
        guard !meal.items.isEmpty else {
            throw MealHubError.noFoodVisible
        }

        if looksLikeCatalogLeak(meal) {
            do {
                let retryText = try await completeVision(
                    system: visionSystemPrompt + """

                    ERREUR : réponse trop générique ou catalogue inventé.
                    Regarde la photo à nouveau. Maximum 4 ITEM_. Uniquement VISIBLE.
                    """,
                    userText: prompt,
                    imageBase64: imageBase64,
                    maxTokens: 480
                )
                let retried = sanitize(try parsePhotoScanResponse(retryText), slot: slot)
                if !retried.isNoFoodDetected, !retried.items.isEmpty {
                    meal = retried
                }
            } catch {
                // Garde la première analyse si le retry échoue.
            }
        }

        return meal
    }

    @MainActor
    static func optimizeScannedMeal(
        _ scanned: MealSuggestionContent,
        assessment: MealDebloatAssessment,
        slot: MealTimeSlot,
        profile: UnifiedUserProfile?
    ) async throws -> MealSuggestionContent {
        let itemsList = scanned.items
            .map { "• \($0.ingredientDisplayLine) (\($0.role))" }
            .joined(separator: "\n")

        let caution = assessment.caution ?? assessment.summary
        let prompt = """
        REPAS SCANNÉ (à optimiser, pas remplacer) :
        Nom : \(scanned.name)
        Ingrédients visibles :
        \(itemsList)

        Score debloat actuel : \(assessment.score)/100 — \(assessment.label)
        Diagnostic : \(caution)

        Propose la version OPTIMISÉE du MÊME repas visible.
        """

        let text = try await CoachAPITransport.complete(
            task: .chat,
            system: optimizeSystemPrompt,
            userText: prompt,
            model: ClaudeModel.preferred(for: .chat),
            maxTokens: 480
        )

        var optimized = try parsePhotoScanResponse(text)
        optimized = sanitize(optimized, slot: slot)
        optimized = clampOptimizedToScanBasis(optimized, scanned: scanned)
        return optimized
    }

    // MARK: - API

    @MainActor
    private static func completeVision(
        system: String,
        userText: String,
        imageBase64: String,
        maxTokens: Int
    ) async throws -> String {
        let text = try await CoachAPITransport.complete(
            task: .chat,
            system: system,
            userText: userText,
            model: ClaudeModel.preferred(for: .chat),
            imageBase64: imageBase64,
            maxTokens: maxTokens
        )
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MealHubError.invalidResponse
        }
        return trimmed
    }

    // MARK: - Image

    private static func prepareImageData(_ image: UIImage, maxPixel: CGFloat = 1400) -> Data? {
        let normalized = image.mealScanNormalized(maxPixel: maxPixel)
        return normalized.jpegData(compressionQuality: 0.78)
    }

    // MARK: - Parsing

    private static func parsePhotoScanResponse(_ text: String) throws -> MealSuggestionContent {
        let sanitized = MealSuggestionParser.sanitize(text)
        let repaired = repairMalformedJSON(sanitized)

        if let meal = MealSuggestionParser.parse(repaired), meal.isValid {
            return scored(meal)
        }

        if let meal = parseLenientJSONObject(from: repaired), meal.isValid {
            return scored(meal)
        }

        if let meal = parseFromItemLines(in: text), meal.isValid {
            return scored(meal)
        }

        #if DEBUG
        print("[MealPhotoScan] Réponse non parsable (\(text.count) chars): \(text.prefix(400))")
        #endif

        throw MealHubError.invalidResponse
    }

    private static func scored(_ meal: MealSuggestionContent) -> MealSuggestionContent {
        var result = meal
        result.showsScore = true
        return result
    }

    private static func repairMalformedJSON(_ raw: String) -> String {
        var text = raw
        text = text.replacingOccurrences(
            of: #":\s*0-100"#,
            with: ": 75",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #",(\s*[}\]])"#,
            with: "$1",
            options: .regularExpression
        )
        return text
    }

    /// Extrait des lignes ITEM / tirets si le modèle n'a pas suivi le format exact.
    private static func parseFromItemLines(in raw: String) -> MealSuggestionContent? {
        var name = ""
        var score = 70
        var scoreSummary = ""
        var items: [MealSuggestionItem] = []

        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let upper = trimmed.uppercased()

            if upper.hasPrefix("MEAL_NAME:") || upper.hasPrefix("NOM:") {
                name = value(after: ":", in: trimmed)
            } else if upper.hasPrefix("SCORE:") && !upper.hasPrefix("SCORE_WHY") && !upper.hasPrefix("SCORE WHY") {
                score = Int(value(after: ":", in: trimmed).filter(\.isNumber)) ?? score
            } else if upper.hasPrefix("SCORE_WHY:") || upper.hasPrefix("SCORE WHY:") {
                scoreSummary = value(after: ":", in: trimmed)
            } else if upper.hasPrefix("ITEM_") || upper.hasPrefix("INGREDIENT_") {
                if let item = parseItemLine(trimmed) {
                    items.append(item)
                }
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                let body = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let item = parseLooseItem(body) {
                    items.append(item)
                }
            }
        }

        if name.isEmpty, let firstItem = items.first?.name {
            name = firstItem
        }
        guard !name.isEmpty, !items.isEmpty else { return nil }

        return MealSuggestionContent(
            name: name,
            mealType: "Repas",
            protocolScore: min(100, max(0, score)),
            scoreSummary: scoreSummary,
            items: items,
            prepMinutes: 0,
            prepSummary: "",
            coachTip: "",
            tags: ["scan photo"],
            subScores: nil,
            imageAssetName: nil,
            showsScore: true
        )
    }

    private static func parseItemLine(_ line: String) -> MealSuggestionItem? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let body = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        return parseLooseItem(body)
    }

    private static func parseLooseItem(_ body: String) -> MealSuggestionItem? {
        let parts = body.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let itemName = parts.first, !itemName.isEmpty else { return nil }
        return MealSuggestionItem(
            name: itemName,
            quantity: parts.count > 1 ? parts[1] : "—",
            role: parts.count > 2 ? parts[2] : "Autre"
        )
    }

    private static func value(after separator: Character, in line: String) -> String {
        guard let index = line.firstIndex(of: separator) else { return line }
        return String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespaces)
    }

    private static func parseLenientJSONObject(from raw: String) -> MealSuggestionContent? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              let data = String(raw[start...end]).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        guard let name = stringValue(object["name"]), !name.isEmpty else { return nil }

        var items: [MealSuggestionItem] = []
        if let itemsRaw = object["items"] as? [[String: Any]] {
            items = itemsRaw.compactMap { itemObject in
                guard let itemName = stringValue(itemObject["name"]), !itemName.isEmpty else { return nil }
                return MealSuggestionItem(
                    name: itemName,
                    quantity: stringValue(itemObject["quantity"]) ?? "—",
                    role: stringValue(itemObject["role"]) ?? "Autre"
                )
            }
        } else if let strings = object["items"] as? [String] {
            items = strings.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return MealSuggestionItem(name: trimmed, quantity: "—", role: "Autre")
            }
        }

        guard !items.isEmpty else { return nil }

        let protocolScore = intValue(object["protocolScore"]) ?? 50
        return MealSuggestionContent(
            name: name,
            mealType: stringValue(object["mealType"]) ?? "Repas",
            protocolScore: min(100, max(0, protocolScore)),
            scoreSummary: stringValue(object["scoreSummary"]) ?? "",
            items: items,
            prepMinutes: intValue(object["prepMinutes"]) ?? 0,
            prepSummary: stringValue(object["prepSummary"]) ?? "",
            coachTip: stringValue(object["coachTip"]) ?? "",
            tags: ["scan photo"],
            subScores: nil,
            imageAssetName: nil,
            showsScore: true
        )
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let int = value as? Int { return String(int) }
        if let double = value as? Double { return String(format: "%.0f", double) }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double.rounded()) }
        if let string = value as? String { return Int(string.filter(\.isNumber)) }
        return nil
    }

    private static func sanitize(_ meal: MealSuggestionContent, slot: MealTimeSlot) -> MealSuggestionContent {
        var cleaned = meal
        cleaned.imageAssetName = nil
        cleaned.showsScore = true
        cleaned.mealType = slot.rawValue
        cleaned.items = cleaned.items.filter { !$0.isBeverageIngredient }
        cleaned.tags = Array(cleaned.tags.prefix(2))
        if !cleaned.tags.contains("scan photo") {
            cleaned.tags.insert("scan photo", at: 0)
        }
        return cleaned
    }

    @MainActor
    private static func clampOptimizedToScanBasis(
        _ optimized: MealSuggestionContent,
        scanned: MealSuggestionContent
    ) -> MealSuggestionContent {
        let scannedTokens = ingredientTokens(from: scanned)
        let optimizedNames = optimized.items.map { normalizeToken($0.name) }

        let novelCount = optimizedNames.filter { name in
            !scannedTokens.contains(where: { name.contains($0) || $0.contains(name) })
        }.count

        guard novelCount > 2 else { return optimized }

        var fallback = scanned
        fallback.name = AppCopy.t(
            "Version debloat — \(scanned.name)",
            en: "Debloat version — \(scanned.name)"
        )
        fallback.coachTip = optimized.coachTip.isEmpty
            ? AppCopy.t(
                "Retire ou remplace les éléments les plus sodés/lactés visibles sur ta photo.",
                en: "Remove or swap the saltiest / dairy items visible in your photo."
            )
            : optimized.coachTip
        fallback.scoreSummary = optimized.scoreSummary.isEmpty
            ? AppCopy.t(
                "Optimisation légère basée sur ton scan.",
                en: "Light optimization based on your scan."
            )
            : optimized.scoreSummary
        fallback.protocolScore = min(100, scanned.protocolScore + 8)
        fallback.showsScore = true
        fallback.imageAssetName = nil
        fallback.tags = ["scan photo", "optimisé"]
        return fallback
    }

    private static func looksLikeCatalogLeak(_ meal: MealSuggestionContent) -> Bool {
        let name = meal.name.lowercased()
        for catalog in ProcessDebloatMealLibrary.allCatalogMeals {
            if name == catalog.name.lowercased() { return true }
        }
        return meal.items.count >= 5
    }

    private static func ingredientTokens(from meal: MealSuggestionContent) -> [String] {
        meal.items.flatMap { item -> [String] in
            let normalized = normalizeToken(item.name)
            return normalized.split(separator: " ").map(String.init).filter { $0.count > 3 } + [normalized]
        }
    }

    private static func normalizeToken(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Détection repas absent

private extension MealSuggestionContent {
    var isNoFoodDetected: Bool {
        let lowered = name.lowercased()
        if lowered.contains("aucun repas") || lowered.contains("pas de repas") { return true }
        if items.count == 1 {
            let item = items[0].name.lowercased()
            if item.contains("sans aliment") || item.contains("non identifiable") { return true }
        }
        return false
    }
}

// MARK: - Normalisation photo

private extension UIImage {
    func mealScanNormalized(maxPixel: CGFloat) -> UIImage {
        let upright = mealScanFixedOrientation()
        let maxSide = max(upright.size.width, upright.size.height)
        guard maxSide > maxPixel, maxSide > 0 else { return upright }

        let scale = maxPixel / maxSide
        let newSize = CGSize(width: upright.size.width * scale, height: upright.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            upright.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func mealScanFixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
