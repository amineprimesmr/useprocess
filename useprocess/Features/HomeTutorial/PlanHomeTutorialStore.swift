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

    private init() {
        reload()
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

    /// Carousel nutrition : repas visibles à partir de l'étape repas.
    var showsMealCardsInCarousel: Bool {
        guard isActive else { return true }
        switch currentStep {
        case .hydration: return false
        default: return true
        }
    }

    /// Titre « Repas debloat » — masqué tant qu'on est sur l'étape eau seule.
    var showsNutritionSectionTitle: Bool {
        guard isActive else { return true }
        return currentStep != .hydration
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

    func schedulePresentationIfNeeded(planAvailable: Bool) {
        presentationTask?.cancel()
        guard planAvailable, !hasCompleted, !isActive else { return }
        guard ProcessEveningCheckInPresenter.shared.presentation == nil else { return }

        presentationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled, !hasCompleted else { return }
            guard WelcomePlanStore.shared.plan != nil else { return }
            guard ProcessEveningCheckInPresenter.shared.presentation == nil else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                currentStepIndex = 0
                isActive = true
                applyTab(for: currentStep)
            }
            HapticManager.shared.impact(.light)
            if currentStep.focusesHydrationCarousel {
                CoachPlanNavigationBridge.shared.focusHydrationOnHome()
            }
        }
    }

    func cancelScheduledPresentation() {
        presentationTask?.cancel()
        presentationTask = nil
    }

    func shouldDisplay(section: PlanHomeSectionKind) -> Bool {
        guard isActive else { return true }
        if currentStep.isTabStep { return true }

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
        case .training: 4
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
            currentStepIndex += 1
            applyTab(for: currentStep)
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

#if DEBUG
    func debugReset() {
        hasCompleted = false
        isActive = false
        currentStepIndex = 0
        let key = UserScopedStorage.key(storageKeyBase)
        UserDefaults.standard.removeObject(forKey: key)
    }

    func debugRestart() {
        debugReset()
        guard WelcomePlanStore.shared.plan != nil else { return }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            currentStepIndex = 0
            isActive = true
            requestedMainSection = .plan
        }
        HapticManager.shared.impact(.medium)
        if currentStep.focusesHydrationCarousel {
            CoachPlanNavigationBridge.shared.focusHydrationOnHome()
        }
    }
#endif
}
