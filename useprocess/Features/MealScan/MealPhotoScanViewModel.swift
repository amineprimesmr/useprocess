import SwiftUI
import UIKit

@MainActor
@Observable
final class MealPhotoScanViewModel {
    enum Phase: Equatable {
        case camera
        case analyzing
        case optimizing
        case result
    }

    enum ResultTab: String, CaseIterable {
        case scanned = "Scanné"
        case optimized = "Optimisé"
    }

    private(set) var phase: Phase = .camera
    private(set) var capturedImage: UIImage?
    private(set) var scannedMeal: MealSuggestionContent?
    private(set) var optimizedMeal: MealSuggestionContent?
    private(set) var selectedResultTab: ResultTab = .scanned
    private(set) var errorMessage: String?
    private(set) var analysisStatus = "Analyse du repas…"

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
        phase = .analyzing
        analysisStatus = "Analyse du repas…"

        Task {
            await analyze(image: image, plan: plan, profile: profile)
        }
    }

    func retryCamera() {
        capturedImage = nil
        scannedMeal = nil
        optimizedMeal = nil
        errorMessage = nil
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

    // MARK: - Private

    private func analyze(image: UIImage, plan: FaceOriginPlan?, profile: UnifiedUserProfile?) async {
        guard let plan else {
            fail("Complète ton plan pour analyser un repas.")
            return
        }

        guard ClaudeConfiguration.isConfigured else {
            fail("Coach IA indisponible — configure l'API Claude.")
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
            fail("Aucun jour de programme disponible.")
            return
        }

        do {
            analysisStatus = "Identification des aliments visibles…"
            let meal = try await MealPhotoScanAnalysisService.analyzePhoto(
                image: image,
                slot: selectedSlot,
                profile: profile
            )
            scannedMeal = meal
            selectedResultTab = .scanned

            if needsOptimization(for: meal) {
                phase = .optimizing
                analysisStatus = "Optimisation debloat de ton repas…"
                let assessment = MealNutritionCatalog.debloatAssessment(for: meal)
                do {
                    let optimized = try await MealPhotoScanAnalysisService.optimizeScannedMeal(
                        meal,
                        assessment: assessment,
                        slot: selectedSlot,
                        profile: profile
                    )
                    optimizedMeal = optimized
                    selectedResultTab = .optimized
                } catch {
                    optimizedMeal = nil
                    selectedResultTab = .scanned
                }
            }

            phase = .result
            ProcessAnalytics.trackMealScanCompleted(
                slot: selectedSlot.rawValue,
                optimized: optimizedMeal != nil
            )
            HapticManager.shared.notification(.success)
        } catch let error as ProcessPrivacyConsentError {
            fail(error.localizedDescription ?? "Autorise l'analyse IA dans les réglages.")
        } catch let error as MealHubError {
            fail(message(for: error))
        } catch let error as ClaudeAPIError {
            fail(claudeMessage(for: error))
        } catch let error as CoachRemoteError {
            fail(error.localizedDescription ?? "Coach indisponible. Réessaie.")
        } catch {
            fail("Connexion ou analyse indisponible. Réessaie dans un instant.")
        }
    }

    private func claudeMessage(for error: ClaudeAPIError) -> String {
        switch error {
        case .missingAPIKey:
            return "Coach IA indisponible — configure l'API Claude."
        case .invalidResponse:
            return "Réponse IA vide. Réessaie."
        case .httpError(let status, _):
            if status == 429 { return "Trop de requêtes — attends quelques secondes." }
            return "Erreur réseau (\(status)). Réessaie."
        case .network:
            return "Connexion instable. Réessaie."
        }
    }

    private func message(for error: MealHubError) -> String {
        switch error {
        case .noFoodVisible:
            return "Aucun repas visible — cadre ton assiette ou ton plat."
        case .photoRequired:
            return "Photo illisible. Réessaie."
        case .invalidResponse:
            return "Analyse interrompue. Réessaie."
        case .noAlternatives:
            return "Analyse interrompue. Réessaie."
        }
    }

    private func needsOptimization(for meal: MealSuggestionContent) -> Bool {
        let assessment = MealNutritionCatalog.debloatAssessment(for: meal)
        return assessment.score < 76 || !assessment.balance.isDebloatOptimized
    }

    private func fail(_ message: String) {
        errorMessage = message
        phase = .camera
        ProcessAnalytics.trackMealScanFailed(error: message)
        HapticManager.shared.notification(.warning)
    }

    func selectResultTab(_ tab: ResultTab) {
        guard tab == .scanned || optimizedMeal != nil else { return }
        selectedResultTab = tab
        HapticManager.shared.selection()
    }
}
