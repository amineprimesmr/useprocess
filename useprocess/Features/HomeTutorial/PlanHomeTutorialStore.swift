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
    /// Étapes dont le CTA « Continuer » est réellement monté à l’écran.
    private var focusesShowingCTA: Set<PlanHomeTutorialFocus> = []
    private var chromeWatchdogTask: Task<Void, Never>?
    /// L'accueil Plan est-il monté dans la hiérarchie ?
    private var isHomeSurfaceMounted = false

    private init() {
        migrateLegacyCompletionIfNeeded()
        reload()
    }

    /// Layout accueil contraint uniquement pendant les étapes Plan du tutoriel.
    /// Ne jamais verrouiller l’app si le tutoriel n’est pas réellement actif
    /// (sinon tabs masqués + pas de CTA Continuer = deadlock).
    var constrainsHomeLayout: Bool {
        guard isActive, !isPreviewSuppressed else { return false }
        // Sans plan, l'accueil affiche `noPlanCard` : aucune carte ciblée, donc
        // aucun CTA. Ne jamais amputer l'accueil dans ce cas.
        guard WelcomePlanStore.shared.plan != nil else { return false }
        return !currentStep.isTabStep
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

    // MARK: - Persistance

    /// Le flag est écrit **et** relu sur toutes les clés plausibles : l'uid Firebase
    /// n'est pas encore restauré au cold start, et `UserScopedStorage.key` retombe
    /// alors sur « anonymous » alors que le plan, lui, retombe sur « local-user ».
    /// Lire une seule clé faisait repasser `hasCompleted` à false et reverrouillait
    /// l'accueil à chaque lancement.
    private var storageKeys: [String] {
        var keys = [UserScopedStorage.globalKey(storageKeyBase)]
        let primary = UserScopedStorage.currentUserId() ?? "local-user"
        for uid in UserScopedStorage.likelyUserIds(primary: primary) {
            keys.append(UserScopedStorage.key(storageKeyBase, userId: uid))
        }
        return keys
    }

    private func loadCompleted() -> Bool {
        storageKeys.contains { UserDefaults.standard.bool(forKey: $0) }
    }

    private func persist() {
        for key in storageKeys {
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    /// Mise à jour depuis une version antérieure : le flag a pu être écrit sous
    /// n'importe quel identifiant (« anonymous », « local-user », un uid Firebase
    /// précédent). Un seul balayage, une seule fois, pour ne jamais rejouer le
    /// tutoriel à quelqu'un qui l'a déjà fait.
    private func migrateLegacyCompletionIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = UserScopedStorage.globalKey("plan.home.tutorial.completed.migrated.v1")
        guard !defaults.bool(forKey: migrationKey) else { return }

        let suffix = "." + storageKeyBase
        let alreadyCompleted = defaults.dictionaryRepresentation().keys.contains {
            $0.hasSuffix(suffix) && defaults.bool(forKey: $0)
        }
        if alreadyCompleted {
            defaults.set(true, forKey: UserScopedStorage.globalKey(storageKeyBase))
        }
        defaults.set(true, forKey: migrationKey)
    }

    func reload() {
        // Jamais de retour arrière : une fois terminé, terminé.
        guard !hasCompleted else {
            isActive = false
            cancelScheduledPresentation()
            return
        }
        hasCompleted = loadCompleted()
        if hasCompleted {
            isActive = false
            cancelScheduledPresentation()
        }
    }

    /// Suppression de compte : seul endroit qui a le droit de réarmer le tutoriel.
    func resetForAccountWipe() {
        cancelScheduledPresentation()
        chromeWatchdogTask?.cancel()
        chromeWatchdogTask = nil
        focusesShowingCTA.removeAll()
        hasCompleted = false
        isActive = false
        currentStepIndex = 0
        requestedMainSection = .plan
    }

    func suppressPresentationForPreview(_ suppressed: Bool) {
        isPreviewSuppressed = suppressed
        if suppressed {
            cancelScheduledPresentation()
        }
    }

    /// Lance le tutoriel dès que le plan est prêt.
    func schedulePresentationIfNeeded(planAvailable: Bool, preferImmediate: Bool = false) {
        presentationTask?.cancel()
        guard !isPreviewSuppressed, !hasCompleted, !isActive else { return }
        var planReady = planAvailable
        if !planReady {
            ensureWelcomePlanIfNeeded()
            planReady = WelcomePlanStore.shared.plan != nil
        }
        guard planReady else { return }

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

        presentationTask = nil
        focusesShowingCTA.removeAll()
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
        startChromeWatchdog()
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

    // MARK: - Chien de garde

    /// Le CTA « Continuer » vit **dans** la carte ciblée : si cette carte ne se monte
    /// pas (plan absent, jour hors plan ou à venir, section masquée par l'utilisateur,
    /// carousel vide), l'accueil restait sans tab bar et sans aucun bouton de sortie.
    func noteFocusCTAVisible(_ focus: PlanHomeTutorialFocus) {
        focusesShowingCTA.insert(focus)
    }

    func noteFocusCTAHidden(_ focus: PlanHomeTutorialFocus) {
        focusesShowingCTA.remove(focus)
        // Le CTA de l'étape en cours vient de disparaître (jour qui bascule,
        // plan rechargé, section masquée) : on relance la surveillance.
        guard isActive, currentStep.focus == focus else { return }
        startChromeWatchdog()
    }

    /// L'accueil Plan est monté — sans ce signal, le chien de garde aurait tué le
    /// tutoriel d'un nouvel utilisateur avant même que l'accueil s'affiche.
    func noteHomeSurfaceMounted(_ mounted: Bool) {
        isHomeSurfaceMounted = mounted
    }

    private func startChromeWatchdog() {
        chromeWatchdogTask?.cancel()
        chromeWatchdogTask = nil
        guard isActive, let focus = currentStep.focus else { return }
        let stepIndex = currentStepIndex
        chromeWatchdogTask = Task { @MainActor in
            // Jusqu'à ~30 s : on laisse le temps à l'accueil d'apparaître avant de conclure.
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled,
                      self.isActive,
                      self.currentStepIndex == stepIndex,
                      self.currentStep.focus == focus else { return }
                // Accueil pas encore à l'écran : on ne conclut rien.
                guard self.isHomeSurfaceMounted else { continue }
                // CTA bien présent : rien à faire (relancé si jamais il disparaît).
                guard !self.focusesShowingCTA.contains(focus) else { return }
                // Accueil monté mais aucun CTA pour cette étape : on libère l'app.
                self.complete()
                return
            }
        }
    }

    // MARK: - Navigation

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
        startChromeWatchdog()
    }

    func skip() {
        HapticManager.shared.impact(.light)
        complete()
    }

    func complete() {
        cancelScheduledPresentation()
        chromeWatchdogTask?.cancel()
        chromeWatchdogTask = nil
        focusesShowingCTA.removeAll()

        let wasActive = isActive
        hasCompleted = true
        isActive = false
        requestedMainSection = .plan
        // Toujours réécrire : la 1re écriture a pu partir sur une clé « anonymous »
        // avant que l'uid soit restauré.
        persist()
        if wasActive {
            HapticManager.shared.notification(.success)
        }
    }

    private func applyTab(for step: PlanHomeTutorialStep) {
        requestedMainSection = step.mainTab ?? .plan
    }
}
