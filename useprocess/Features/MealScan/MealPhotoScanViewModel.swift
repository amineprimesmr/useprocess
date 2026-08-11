import SwiftUI
import UIKit

@MainActor
@Observable
final class MealPhotoScanViewModel {
    enum Phase: Equatable {
        case camera
        case analyzing
        case result
    }

    enum ResultTab: CaseIterable {
        case scanned
        case optimized

        @MainActor
        var title: String {
            switch self {
            case .scanned: return AppCopy.t("Scanné", en: "Scanned")
            case .optimized: return AppCopy.t("Optimisé", en: "Optimized")
            }
        }
    }

    private(set) var phase: Phase = .camera
    private(set) var capturedImage: UIImage?
    private(set) var scannedMeal: MealSuggestionContent?
    private(set) var optimizedMeal: MealSuggestionContent?
    private(set) var selectedResultTab: ResultTab = .scanned
    private(set) var errorMessage: String?
    private(set) var analysisStatus = AppCopy.t("Analyse du repas…", en: "Analyzing meal…")
    /// Optimisation debloat en arrière-plan (résultat scan déjà affiché).
    private(set) var isOptimizingInBackground = false

    var selectedSlot: MealTimeSlot = .lunch

    var scannedAssessment: MealDebloatAssessment? {
        scannedMeal.map { MealNutritionCatalog.debloatAssessment(for: $0) }
    }

    var optimizedAssessment: MealDebloatAssessment? {
        optimizedMeal.map { MealNutritionCatalog.debloatAssessment(for: $0) }
    }

    var needsOptimization: Bool {
        guard let assessment = scannedAssessment else { return false }
        return assessment.score < 76 || !assessment.balance.isDebloatOptimized
    }

    var activeMeal: MealSuggestionContent? {
        switch selectedResultTab {
        case .scanned: return scannedMeal
        case .optimized: return optimizedMeal ?? scannedMeal
        }
    }

    var activeAssessment: MealDebloatAssessment? {
        switch selectedResultTab {
        case .scanned: return scannedAssessment
        case .optimized: return optimizedAssessment ?? scannedAssessment
        }
    }

    func configureSlot(plan: FaceOriginPlan?) {
        guard let plan else { return }
        let slots = plan.configuredMealSlots
        selectedSlot = PlanMealSlotLabel.preferredSlot(in: slots, planType: plan.nutritionPlanType)
    }

    func handleCapturedImage(_ image: UIImage, plan: FaceOriginPlan?, profile: UnifiedUserProfile?) {
        capturedImage = image
        errorMessage = nil
        optimizedMeal = nil
        isOptimizingInBackground = false
        phase = .analyzing
        analysisStatus = AppCopy.t("Identification des aliments…", en: "Identifying foods…")

        Task {
            await analyze(image: image, plan: plan, profile: profile)
        }
    }

    func retryCamera() {
        capturedImage = nil
        scannedMeal = nil
        optimizedMeal = nil
        errorMessage = nil
        isOptimizingInBackground = false
        selectedResultTab = .scanned
        phase = .camera
    }

    func validateActiveMeal(plan: FaceOriginPlan, day: OriginProgramDay) -> MealSuggestionContent? {
        guard let meal = activeMeal else { return nil }
        let store = WelcomePlanStore.shared
        store.saveDraftMeal(dayId: day.id, meal: meal, slot: selectedSlot)
        store.saveValidatedMeal(dayId: day.id, meal: meal, slot: selectedSlot)
        return meal
    }

    // MARK: - Édition locale (sans nouvel appel réseau)

    /// Indices des aliments éditables dans `activeMeal.items` (hors boissons).
    var editableFoodItemIndices: [Int] {
        guard let meal = activeMeal else { return [] }
        return meal.items.indices.filter { !meal.items[$0].isBeverageIngredient }
    }

    func updateFoodItem(atFoodIndex foodIndex: Int, name: String, quantity: String, role: String) {
        let indices = editableFoodItemIndices
        guard indices.indices.contains(foodIndex) else { return }
        let itemIndex = indices[foodIndex]
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        mutateActiveMeal { meal in
            meal.items[itemIndex] = MealSuggestionItem(
                name: trimmedName,
                quantity: Self.normalizedQuantity(quantity),
                role: role
            )
        }
    }

    func removeFoodItem(atFoodIndex foodIndex: Int) {
        let indices = editableFoodItemIndices
        guard indices.indices.contains(foodIndex) else { return }
        // Garde au moins 1 aliment.
        guard indices.count > 1 else { return }
        let itemIndex = indices[foodIndex]

        mutateActiveMeal { meal in
            meal.items.remove(at: itemIndex)
        }
    }

    func addFoodItem(name: String, quantity: String, role: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        mutateActiveMeal { meal in
            meal.items.append(
                MealSuggestionItem(
                    name: trimmedName,
                    quantity: Self.normalizedQuantity(quantity),
                    role: role
                )
            )
        }
    }

    private static func normalizedQuantity(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func mutateActiveMeal(_ update: (inout MealSuggestionContent) -> Void) {
        switch selectedResultTab {
        case .scanned:
            guard var meal = scannedMeal else { return }
            update(&meal)
            refreshScore(&meal)
            scannedMeal = meal
            // Le scan de base a changé → l’optimisé n’est plus fiable.
            optimizedMeal = nil
            isOptimizingInBackground = false
        case .optimized:
            guard var meal = optimizedMeal else { return }
            update(&meal)
            refreshScore(&meal)
            optimizedMeal = meal
        }
        HapticManager.shared.selection()
    }

    private func refreshScore(_ meal: inout MealSuggestionContent) {
        let synced = MealNutritionCatalog.syncedScore(for: meal)
        meal.protocolScore = synced.protocolScore
        meal.scoreSummary = synced.scoreSummary
        meal.showsScore = synced.showsScore
        if !meal.tags.contains("corrigé") {
            meal.tags.append("corrigé")
        }
    }

    // MARK: - Private

    private func analyze(image: UIImage, plan: FaceOriginPlan?, profile: UnifiedUserProfile?) async {
        guard let plan else {
            fail(AppCopy.t(
                "Complète ton plan pour analyser un repas.",
                en: "Finish your plan to analyze a meal."
            ))
            return
        }

        guard ClaudeConfiguration.isConfigured else {
            fail(AppCopy.t(
                "Analyse indisponible — configure le coach.",
                en: "Analysis unavailable — configure the coach."
            ))
            return
        }

        guard ProcessPrivacyConsentStore.shared.canUseThirdPartyAI else {
            ProcessPrivacyConsentStore.shared.presentThirdPartyAIConsentIfNeeded { [weak self] in
                Task { @MainActor in
                    await self?.analyze(image: image, plan: plan, profile: profile)
                }
            }
            phase = .camera
            return
        }

        guard OriginPlanPresenter.programDay(in: plan) != nil
            || OriginPlanPresenter.todayDay(in: plan) != nil else {
            fail(AppCopy.t(
                "Aucun jour de programme disponible.",
                en: "No program day available."
            ))
            return
        }

        do {
            var meal = try await MealPhotoScanAnalysisService.analyzePhoto(
                image: image,
                slot: selectedSlot,
                profile: profile
            )
            meal = MealNutritionCatalog.syncedScore(for: meal)
            scannedMeal = meal
            selectedResultTab = .scanned
            // Affiche le scan tout de suite — l’optimisation ne bloque plus l’écran.
            phase = .result
            HapticManager.shared.notification(.success)
            ProcessAnalytics.trackMealScanCompleted(
                slot: selectedSlot.rawValue,
                optimized: false
            )

            if needsOptimization(for: meal) {
                await runBackgroundOptimize(meal: meal, profile: profile)
            }
        } catch let error as ProcessPrivacyConsentError {
            fail(error.localizedDescription ?? AppCopy.t(
                "Autorise l'analyse dans les réglages.",
                en: "Allow analysis in Settings."
            ))
        } catch let error as MealHubError {
            fail(message(for: error))
        } catch let error as ClaudeAPIError {
            fail(claudeMessage(for: error))
        } catch let error as CoachRemoteError {
            fail(error.localizedDescription ?? AppCopy.t(
                "Analyse indisponible. Réessaie.",
                en: "Analysis unavailable. Try again."
            ))
        } catch {
            fail(AppCopy.t(
                "Connexion ou analyse indisponible. Réessaie dans un instant.",
                en: "Connection or analysis unavailable. Try again in a moment."
            ))
        }
    }

    private func runBackgroundOptimize(meal: MealSuggestionContent, profile: UnifiedUserProfile?) async {
        isOptimizingInBackground = true
        defer { isOptimizingInBackground = false }

        let assessment = MealNutritionCatalog.debloatAssessment(for: meal)
        do {
            let optimized = try await MealPhotoScanAnalysisService.optimizeScannedMeal(
                meal,
                assessment: assessment,
                slot: selectedSlot,
                profile: profile
            )
            guard phase == .result, scannedMeal?.name == meal.name else { return }
            optimizedMeal = MealNutritionCatalog.syncedScore(for: optimized)
            selectedResultTab = .optimized
            ProcessAnalytics.trackMealScanCompleted(
                slot: selectedSlot.rawValue,
                optimized: true
            )
            HapticManager.shared.selection()
        } catch {
            optimizedMeal = nil
        }
    }

    private func claudeMessage(for error: ClaudeAPIError) -> String {
        switch error {
        case .missingAPIKey:
            return AppCopy.t(
                "Analyse indisponible — configure le coach.",
                en: "Analysis unavailable — configure the coach."
            )
        case .invalidResponse:
            return AppCopy.t("Réponse vide. Réessaie.", en: "Empty response. Try again.")
        case .httpError(let status, _):
            if status == 429 {
                return AppCopy.t(
                    "Trop de requêtes — attends quelques secondes.",
                    en: "Too many requests — wait a few seconds."
                )
            }
            return AppCopy.t("Erreur réseau (\(status)). Réessaie.", en: "Network error (\(status)). Try again.")
        case .network:
            return AppCopy.t("Connexion instable. Réessaie.", en: "Unstable connection. Try again.")
        }
    }

    private func message(for error: MealHubError) -> String {
        switch error {
        case .noFoodVisible:
            return AppCopy.t(
                "Aucun repas visible — cadre ton assiette ou ton plat.",
                en: "No meal visible — frame your plate or dish."
            )
        case .photoRequired:
            return AppCopy.t("Photo illisible. Réessaie.", en: "Unreadable photo. Try again.")
        case .invalidResponse:
            return AppCopy.t("Analyse interrompue. Réessaie.", en: "Analysis interrupted. Try again.")
        case .noAlternatives:
            return AppCopy.t("Analyse interrompue. Réessaie.", en: "Analysis interrupted. Try again.")
        }
    }

    private func needsOptimization(for meal: MealSuggestionContent) -> Bool {
        let assessment = MealNutritionCatalog.debloatAssessment(for: meal)
        return assessment.score < 76 || !assessment.balance.isDebloatOptimized
    }

    private func fail(_ message: String) {
        errorMessage = message
        phase = .camera
        isOptimizingInBackground = false
        ProcessAnalytics.trackMealScanFailed(error: message)
        HapticManager.shared.notification(.warning)
    }

    func selectResultTab(_ tab: ResultTab) {
        guard tab == .scanned || optimizedMeal != nil else { return }
        selectedResultTab = tab
        HapticManager.shared.selection()
    }
}
