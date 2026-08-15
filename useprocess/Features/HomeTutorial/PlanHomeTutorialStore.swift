import Foundation
import SwiftUI

/// Tutoriel première visite — sur l'accueil Plan, sections cumulatives.
@MainActor
@Observable
final class PlanHomeTutorialStore {
    static let shared = PlanHomeTutorialStore()

    private(set) var isActive = false
    private(set) var currentStepIndex = 0
    private(set) var hasCompleted = false
    private(set) var requestedMainSection: ProcessMainSection = .plan

    private let storageKeyBase = "plan.home.tutorial.completed"
    private var presentationTask: Task<Void, Never>?
    /// Bloque le tutoriel pendant l’aperçu onboarding (plan éphémère).
    private var isPreviewSuppressed = false

    private init() {
        reload()
    }

    /// Layout accueil contraint uniquement pendant les étapes Plan du tutoriel.
    /// Ne jamais verrouiller l’app si le tutoriel n’est pas réellement actif
    /// (sinon tabs masqués + pas de CTA Continuer = deadlock).
    var constrainsHomeLayout: Bool {
        guard isActive, !isPreviewSuppressed else { return false }
        return !currentStep.isTabStep
    }

    /// Le bilan du soir passe après le tutoriel première visite.
    var shouldDeferEveningCheckIn: Bool {
        isActive || (!hasCompleted && !isPreviewSuppressed)
    }

    var steps: [PlanHomeTutorialStep] {
        PlanHomeTutorialStep.allCases
    }

    var currentStep: PlanHomeTutorialStep {
        steps[min(max(currentStepIndex, 0), steps.count - 1)]
    }

    var homeStepIndices: [Int] {
        steps.enumerated().compactMap { index, step in
            step.isTabStep ? nil : index
        }
    }

    /// Strip nutrition : carte repas visible à partir de l'étape repas.
    var showsMealCardsInCarousel: Bool {
        guard isActive, constrainsHomeLayout else { return true }
        switch currentStep {
        case .hydration: return false
        default: return true
        }
    }

    /// Titre « Alimentation debloat » — visible dès l'étape hydratation avec la carte eau.
    var showsNutritionSectionTitle: Bool {
        true
    }

    /// Scroll vertical Accueil — inutile quand les repas apparaissent à droite de l'eau.
    var shouldScrollVerticallyToFocus: Bool {
        guard isActive, !currentStep.isTabStep else { return false }
        return currentStep != .nutrition
    }

    func reload() {
        let key = UserScopedStorage.key(storageKeyBase)
        hasCompleted = UserDefaults.standard.bool(forKey: key)
        if hasCompleted {
            isActive = false
        }
    }

    func suppressPresentationForPreview(_ suppressed: Bool) {
        isPreviewSuppressed = suppressed
        if suppressed {
            cancelScheduledPresentation()
        }
    }

    /// Lance le tutoriel dès que le plan est prêt (après check-in du soir s'il bloque).
    func schedulePresentationIfNeeded(planAvailable: Bool, preferImmediate: Bool = false) {
        presentationTask?.cancel()
        guard !isPreviewSuppressed, !hasCompleted, !isActive else { return }
        var planReady = planAvailable
        if !planReady {
            ensureWelcomePlanIfNeeded()
            planReady = WelcomePlanStore.shared.plan != nil
        }
        guard planReady else { return }
        guard ProcessEveningCheckInPresenter.shared.presentation == nil else { return }

        if preferImmediate {
            beginPresentationIfPossible(animated: false)
            return
        }

        presentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, !self.isPreviewSuppressed, !self.hasCompleted, !self.isActive else { return }
            self.beginPresentationIfPossible(animated: false)
        }
    }

    /// Active le tutoriel tout de suite — à appeler avant le 1er frame de l’app.
    func activateImmediatelyIfNeeded() {
        ensureWelcomePlanIfNeeded()
        schedulePresentationIfNeeded(planAvailable: WelcomePlanStore.shared.plan != nil, preferImmediate: true)
    }

    func cancelScheduledPresentation() {
        presentationTask?.cancel()
        presentationTask = nil
    }

    private func ensureWelcomePlanIfNeeded() {
        guard WelcomePlanStore.shared.plan == nil else { return }
        WelcomePlanStore.shared.autoCompleteWelcomePlanIfNeeded(
            profile: UnifiedProfileService.shared.currentProfile
        )
    }

    private func beginPresentationIfPossible(animated: Bool = true) {
        guard !isPreviewSuppressed, !hasCompleted, !isActive else { return }
        ensureWelcomePlanIfNeeded()
        guard WelcomePlanStore.shared.plan != nil else { return }
        guard ProcessEveningCheckInPresenter.shared.presentation == nil else { return }

        presentationTask = nil
        let apply = {
            self.currentStepIndex = 0
            self.isActive = true
            self.applyTab(for: self.currentStep)
        }
        if animated {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                apply()
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                apply()
            }
        }
        if currentStep.focusesHydrationCarousel {
            CoachPlanNavigationBridge.shared.focusHydrationOnHome()
        }
    }

    func shouldDisplay(section: PlanHomeSectionKind) -> Bool {
        guard constrainsHomeLayout else { return true }

        guard let through = currentStep.revealThroughSection,
              let throughIndex = PlanHomeTutorialStep.homeRevealOrder.firstIndex(of: through),
              let sectionIndex = PlanHomeTutorialStep.homeRevealOrder.firstIndex(of: section) else {
            return false
        }
        return sectionIndex <= throughIndex
    }

    func isFocused(_ focus: PlanHomeTutorialFocus) -> Bool {
        guard isActive, !currentStep.isTabStep else { return false }
        return currentStep.focus == focus
    }

    func isRevealed(_ focus: PlanHomeTutorialFocus) -> Bool {
        guard isActive, !isFocused(focus) else { return false }
        guard let current = currentStep.focus else { return false }
        return focusOrder(focus) < focusOrder(current)
    }

    private func focusOrder(_ focus: PlanHomeTutorialFocus) -> Int {
        switch focus {
        case .faceScan: 0
        case .hydration: 1
        case .meals: 2
        case .faceRoutine: 3
        }
    }

    func advance() {
        guard isActive else { return }
        HapticManager.shared.impact(.medium)

        if currentStepIndex + 1 >= steps.count {
            complete()
            return
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            self.currentStepIndex += 1
            self.applyTab(for: self.currentStep)
        }

        if currentStep.focusesHydrationCarousel {
            CoachPlanNavigationBridge.shared.focusHydrationOnHome()
        }
    }

    func skip() {
        HapticManager.shared.impact(.light)
        complete()
    }

    func complete() {
        guard !hasCompleted else {
            isActive = false
            return
        }
        hasCompleted = true
        isActive = false
        requestedMainSection = .plan
        persist()
        HapticManager.shared.notification(.success)
    }

    private func applyTab(for step: PlanHomeTutorialStep) {
        requestedMainSection = step.mainTab ?? .plan
    }

    private func persist() {
        let key = UserScopedStorage.key(storageKeyBase)
        UserDefaults.standard.set(true, forKey: key)
    }
}
