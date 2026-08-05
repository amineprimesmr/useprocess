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
        analysisStatus = AppCopy.t("Analyse du repas…", en: "Analyzing meal…")

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
            fail(AppCopy.t(
                "Complète ton plan pour analyser un repas.",
                en: "Finish your plan to analyze a meal."
            ))
            return
        }

        guard ClaudeConfiguration.isConfigured else {
            fail(AppCopy.t(
                "Coach IA indisponible — configure l'API Claude.",
                en: "AI coach unavailable — configure the Claude API."
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
            analysisStatus = AppCopy.t(
                "Identification des aliments visibles…",
                en: "Identifying visible foods…"
            )
            let meal = try await MealPhotoScanAnalysisService.analyzePhoto(
                image: image,
                slot: selectedSlot,
                profile: profile
            )
            scannedMeal = meal
            selectedResultTab = .scanned

            if needsOptimization(for: meal) {
                phase = .optimizing
                analysisStatus = AppCopy.t(
                    "Optimisation debloat de ton repas…",
                    en: "Debloat-optimizing your meal…"
                )
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
            fail(error.localizedDescription ?? AppCopy.t(
                "Autorise l'analyse IA dans les réglages.",
                en: "Allow AI analysis in Settings."
            ))
        } catch let error as MealHubError {
            fail(message(for: error))
        } catch let error as ClaudeAPIError {
            fail(claudeMessage(for: error))
        } catch let error as CoachRemoteError {
            fail(error.localizedDescription ?? AppCopy.t(
                "Coach indisponible. Réessaie.",
                en: "Coach unavailable. Try again."
            ))
        } catch {
            fail(AppCopy.t(
                "Connexion ou analyse indisponible. Réessaie dans un instant.",
                en: "Connection or analysis unavailable. Try again in a moment."
            ))
        }
    }

    private func claudeMessage(for error: ClaudeAPIError) -> String {
        switch error {
        case .missingAPIKey:
            return AppCopy.t(
                "Coach IA indisponible — configure l'API Claude.",
                en: "AI coach unavailable — configure the Claude API."
            )
        case .invalidResponse:
            return AppCopy.t("Réponse IA vide. Réessaie.", en: "Empty AI response. Try again.")
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
        ProcessAnalytics.trackMealScanFailed(error: message)
        HapticManager.shared.notification(.warning)
    }

    func selectResultTab(_ tab: ResultTab) {
        guard tab == .scanned || optimizedMeal != nil else { return }
        selectedResultTab = tab
        HapticManager.shared.selection()
    }
}
