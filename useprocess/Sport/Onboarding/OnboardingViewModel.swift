//
//  OnboardingViewModel.swift
//  Process
//
//  ViewModel unifié pour remplacer tous les @State dispersés dans OnboardingView
//

import SwiftUI
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Progression
    @Published var currentStep: Int = 0
    @Published var visitedSteps: [Int] = [] // Historique des étapes visitées pour navigation retour
    @Published var isCompleting: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Informations personnelles
    @Published var selectedGender: Gender? = nil
    @Published var selectedAge: Int = 21
    @Published var selectedHeight: Double = 170 // cm — défaut 1m70
    @Published var selectedWeight: Double = 0 // kg — 0 = pas encore saisi
    @Published var firstName: String = ""
    @Published var idealWeightValue: Double = 0
    
    // MARK: - Objectifs
    @Published var hasWeightGoal: Bool? = nil
    @Published var selectedPrimaryGoals: Set<PrimaryGoal> = []
    @Published var selectedWeightGoal: WeightGoal? = nil
    @Published var selectedGoalPace: GoalPace? = nil

    // MARK: - Sport (chat cardio)
    @Published var hasSportActivity: Bool? = nil
    @Published var selectedTrainingFrequency: String? = nil

    // MARK: - Nutrition / sommeil
    @Published var nutritionProfile = NutritionProfile()
    @Published var sleepProfile = SleepProfile()

    // MARK: - États de validation
    @Published var isGenderSelected: Bool = false
    @Published var isAgeSelected: Bool = false
    @Published var isHeightWeightSelected: Bool = false
    @Published var isFirstNameEntered: Bool = false
    @Published var isPrimaryGoalSelected: Bool = false
    @Published var isWeightGoalSelected: Bool = false
    @Published var isIdealWeightEntered: Bool = false
    @Published var isTrainingFrequencySelected: Bool = false
    @Published var isGoalPaceSelected: Bool = false
    @Published var isWeightEstimationCompleted: Bool = false
    /// Progression 0…1 du remplissage CTA « Continuer » (écran estimations).
    @Published var estimationContinueUnlockProgress: Double = 0
    @Published var isGoalProjectionCompleted: Bool = false
    @Published var isNutritionQualitySelected: Bool = false
    @Published var isWeightManagementExperienceSelected: Bool = false
    @Published var isFaceLeverageIntroCompleted: Bool = false
    @Published var isWeightMotivationCompleted: Bool = false
    @Published var isFaceAnalysisCompleted: Bool = false
    @Published var onboardingFaceMarkers: FaceWellnessMarkers?
    @Published var onboardingFaceMesh: FaceMesh3DData?
    @Published var isProgramCreationCompleted: Bool = false

    // MARK: - Referral / chat
    @Published var referralCode: String? = nil
    @Published var creatorCodeDraft: String = ""
    @Published var creatorCodeIsVerified = false
    @Published var creatorCodeContinueAttempt = 0
    @Published var completedProfileChatQuestionIDs: Set<String> = []
    @Published var onboardingDebloatDrivers: Set<OnboardingDebloatDriver> = []
    
    // MARK: - Initialization
    
    init() {
        OnboardingProgressService.shared.migrateInProgressStorageIfNeeded()

        // Charger la progression sauvegardée
        let savedStep = OnboardingProgressService.shared.loadCurrentStep()
        
        // ✅ CORRECTION: Charger l'historique complet des étapes visitées depuis UserDefaults
        let savedVisitedSteps = OnboardingProgressService.shared.loadVisitedSteps()

        if let cached = OnboardingProgressService.shared.loadAnswers() {
            applyCachedAnswers(cached)
        }
        
        if savedStep > 0 {
            let saved = OnboardingStep.resolved(from: savedStep)
            let resumeStep = saved.unpaidResumeStep.rawValue
            currentStep = resumeStep

            if !savedVisitedSteps.isEmpty {
                visitedSteps = normalizeOnboardingVisitedStack(
                    visitedSteps: savedVisitedSteps,
                    currentStep: resumeStep
                )
            } else {
                visitedSteps = [resumeStep]
            }
        } else {
            currentStep = OnboardingStep.genderSelection.rawValue
            if !savedVisitedSteps.isEmpty {
                visitedSteps = savedVisitedSteps.compactMap { OnboardingStep(rawValue: $0)?.rawValue }
                if visitedSteps.isEmpty {
                    visitedSteps = [OnboardingStep.genderSelection.rawValue]
                }
            } else {
                visitedSteps = [OnboardingStep.genderSelection.rawValue]
            }
        }

        let shouldRestoreFaceScan = isFaceAnalysisCompleted
            || hasReachedFaceScanStep(
                savedStep: OnboardingProgressService.shared.loadCurrentStep(),
                visited: OnboardingProgressService.shared.loadVisitedSteps()
            )
        if let payload = OnboardingFaceMarkersStore.loadPayload(),
           shouldRestoreFaceScan {
            onboardingFaceMarkers = payload.markers
            onboardingFaceMesh = payload.mesh.isValid ? payload.mesh : nil
            isFaceAnalysisCompleted = true
        } else if let markers = OnboardingFaceMarkersStore.load(),
                  shouldRestoreFaceScan {
            onboardingFaceMarkers = markers
            onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
            isFaceAnalysisCompleted = true
        } else if !shouldRestoreFaceScan {
            isFaceAnalysisCompleted = false
        }

        reconcileFirstDashboardPreviewResumeIfNeeded(viewModel: self)

        if hasWeightGoal == nil, selectedPrimaryGoals.contains(.manageWeight) {
            hasWeightGoal = true
        }
        
        // ✅ La synchronisation avec le profil se fait dans OnboardingView.onAppear et onChange
        // car le profil n'est pas encore chargé à ce stade
    }
    
    // MARK: - Synchronization
    
    /// Synchronise le ViewModel avec le profil existant sans écraser les réponses déjà saisies.
    func syncWithExistingProfile(_ profile: UnifiedUserProfile?) {
        guard let profile = profile else { return }

        if Self.isRealUserFirstName(profile.firstName),
           firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !Self.isRealUserFirstName(firstName) {
            firstName = profile.firstName
            isFirstNameEntered = true
        }

        if profile.age > 0, profile.age <= 120, !isAgeSelected {
            selectedAge = profile.age
            isAgeSelected = true
        } else if profile.birthDate != Date(timeIntervalSince1970: 0), !isAgeSelected {
            let calendar = Calendar.current
            if let calculatedAge = calendar.dateComponents([.year], from: profile.birthDate, to: Date()).year,
               calculatedAge > 0, calculatedAge <= 120 {
                selectedAge = calculatedAge
                isAgeSelected = true
            }
        }

        if profile.height > 0, selectedHeight <= 0 {
            selectedHeight = profile.height
        }

        if Self.isPlausibleWeight(profile.weight), selectedWeight <= 0 {
            selectedWeight = profile.weight
        }

        if let ideal = profile.idealWeight, Self.isPlausibleWeight(ideal), !isIdealWeightEntered {
            idealWeightValue = ideal
            isIdealWeightEntered = true
        }

        if profile.gender != .preferNotToSay, !isGenderSelected {
            selectedGender = profile.gender
            isGenderSelected = true
        }
    }
    
    // MARK: - Validation
    
    func isCurrentStepValidated() -> Bool {
        switch OnboardingStep.resolved(from: currentStep) {
        case .genderSelection:
            return isGenderSelected && selectedGender != nil
        case .ageSelection:
            return isAgeSelected && selectedAge > 0 && selectedAge <= 120
        case .height:
            return selectedHeight > 0
        case .weight:
            return Self.isPlausibleWeight(selectedWeight)
        case .firstNameInput:
            return isFirstNameEntered && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .faceLeverageIntro:
            return isFaceLeverageIntroCompleted
        case .weightMotivation:
            return isWeightMotivationCompleted
        case .weightEstimation:
            return isWeightEstimationCompleted
        case .programCreation:
            return isProgramCreationCompleted
        case .referralCode:
            return creatorCodeIsVerified
        default:
            return true
        }
    }
    
    // MARK: - Objectif poids (flux simplifié)

    var hasWeightObjective: Bool { hasWeightGoal == true }

    func refreshBodyCompositionRouting() {
        // Défauts debloat une seule fois — évite une tempête de @Published pendant la nav.
        guard hasWeightGoal != false else { return }
        applyFitProfileDebloatDefaults()
    }

    /// Profil déjà fit — pas d'objectif poids, trajectoire debloat visage.
    func applyFitProfileDebloatDefaults() {
        applyHasWeightGoal(false)
        idealWeightValue = selectedWeight
        isIdealWeightEntered = false
        selectedWeightGoal = nil
        isWeightGoalSelected = false
    }

    func applyHasWeightGoal(_ value: Bool) {
        hasWeightGoal = value
        isPrimaryGoalSelected = true

        if value {
            selectedPrimaryGoals.insert(.manageWeight)
        } else {
            selectedPrimaryGoals.remove(.manageWeight)
            selectedWeightGoal = nil
            isWeightGoalSelected = false
            isIdealWeightEntered = false
        }
    }

    func updateNutritionQuality(_ quality: NutritionQuality?) {
        var profile = nutritionProfile
        profile.nutritionQuality = quality
        nutritionProfile = profile
        isNutritionQualitySelected = quality != nil
    }

    /// Persiste les réponses implicites (valeurs par défaut UI) avant navigation.
    func commitPendingStepAnswers() {
        if nutritionProfile.nutritionQuality == nil {
            updateNutritionQuality(.average)
        }
    }

    func syncInferredWeightGoal() {
        guard hasWeightGoal == true, isIdealWeightEntered else { return }

        if idealWeightValue < selectedWeight {
            selectedWeightGoal = .lose
        } else if idealWeightValue > selectedWeight {
            selectedWeightGoal = .gain
        } else {
            selectedWeightGoal = nil
        }
        isWeightGoalSelected = selectedWeightGoal != nil
    }

    // MARK: - Progress Management
    
    func saveProgress() {
        OnboardingProgressService.shared.saveCurrentStep(persistedResumeStep)
        OnboardingProgressService.shared.saveVisitedSteps(visitedSteps)
        OnboardingProgressService.shared.saveAnswers(makeAnswersSnapshot())
    }

    /// Tant que l’onboarding n’est pas payé, on mémorise le dashboard — pas le paywall.
    private var persistedResumeStep: Int {
        guard !AppSession.shared.hasCompletedOnboarding,
              !SubscriptionService.shared.subscriptionStatus.isActive else {
            return currentStep
        }
        return OnboardingStep.resolved(from: currentStep).unpaidResumeStep.rawValue
    }

    func saveFlowProgress(_ progress: Double) {
        OnboardingProgressService.shared.saveFlowProgress(progress)
    }
    
    func resetProgress() {
        OnboardingProgressService.shared.resetProgress()
        sleepProfile = SleepProfile()
        currentStep = OnboardingStep.genderSelection.rawValue
    }

    func makeAnswersSnapshot() -> OnboardingAnswersSnapshot {
        OnboardingAnswersSnapshot(
            selectedGender: selectedGender,
            selectedAge: selectedAge,
            selectedHeight: selectedHeight,
            selectedWeight: selectedWeight,
            firstName: firstName,
            idealWeightValue: idealWeightValue,
            hasWeightGoal: hasWeightGoal,
            selectedPrimaryGoals: selectedPrimaryGoals.sorted { $0.rawValue < $1.rawValue },
            selectedWeightGoal: selectedWeightGoal,
            selectedGoalPace: selectedGoalPace,
            hasSportActivity: hasSportActivity,
            selectedTrainingFrequency: selectedTrainingFrequency,
            selectedSports: OnboardingDataModel.shared.selectedSports.sorted(),
            nutritionProfile: nutritionProfile,
            sleepProfile: sleepProfile,
            referralCode: referralCode,
            completedProfileChatQuestionIDs: completedProfileChatQuestionIDs.sorted(),
            onboardingDebloatDrivers: onboardingDebloatDrivers.sorted { $0.rawValue < $1.rawValue },
            isGenderSelected: isGenderSelected,
            isAgeSelected: isAgeSelected,
            isHeightWeightSelected: isHeightWeightSelected,
            isFirstNameEntered: isFirstNameEntered,
            isPrimaryGoalSelected: isPrimaryGoalSelected,
            isWeightGoalSelected: isWeightGoalSelected,
            isIdealWeightEntered: isIdealWeightEntered,
            isTrainingFrequencySelected: isTrainingFrequencySelected,
            isGoalPaceSelected: isGoalPaceSelected,
            isNutritionQualitySelected: isNutritionQualitySelected,
            isWeightManagementExperienceSelected: isWeightManagementExperienceSelected,
            isWeightMotivationCompleted: isWeightMotivationCompleted,
            isWeightEstimationCompleted: isWeightEstimationCompleted,
            isGoalProjectionCompleted: isGoalProjectionCompleted,
            isFaceAnalysisCompleted: isFaceAnalysisCompleted,
            isProgramCreationCompleted: isProgramCreationCompleted,
            dashboardPreviewPresentation: dashboardPreviewPresentation.rawValue,
            hasCompletedFirstDashboardPreview: hasCompletedFirstDashboardPreview,
            dashboardScanPersistedState: dashboardScanPersistedState
        )
    }

    func applyCachedAnswers(_ snapshot: OnboardingAnswersSnapshot) {
        if let value = snapshot.selectedGender {
            selectedGender = value
        }
        if let value = snapshot.selectedAge {
            selectedAge = value
        }
        if let value = snapshot.selectedHeight, value > 0 {
            selectedHeight = value
        }
        if let value = snapshot.selectedWeight, Self.isPlausibleWeight(value) {
            selectedWeight = value
        }
        if let value = snapshot.firstName, Self.isRealUserFirstName(value) {
            firstName = value
        }
        if let value = snapshot.idealWeightValue, Self.isPlausibleWeight(value) {
            idealWeightValue = value
        }
        if let value = snapshot.hasWeightGoal {
            hasWeightGoal = value
        }
        if let goals = snapshot.selectedPrimaryGoals {
            selectedPrimaryGoals = Set(goals)
        }
        if let value = snapshot.selectedWeightGoal {
            selectedWeightGoal = value
        }
        if let value = snapshot.selectedGoalPace {
            selectedGoalPace = value
        }
        if let value = snapshot.hasSportActivity {
            hasSportActivity = value
        }
        if let value = snapshot.selectedTrainingFrequency {
            selectedTrainingFrequency = value
        }
        if let sports = snapshot.selectedSports {
            OnboardingDataModel.shared.selectedSports = Set(sports)
        }
        if let value = snapshot.nutritionProfile {
            nutritionProfile = value
        }
        if let value = snapshot.sleepProfile {
            sleepProfile = value
        }
        if let value = snapshot.referralCode {
            referralCode = value
        }
        if let ids = snapshot.completedProfileChatQuestionIDs {
            completedProfileChatQuestionIDs = Set(ids)
        }
        if let values = snapshot.onboardingDebloatDrivers {
            onboardingDebloatDrivers = Set(values)
        } else if let value = snapshot.onboardingDebloatDriver {
            onboardingDebloatDrivers = [value]
        }

        if let value = snapshot.isGenderSelected { isGenderSelected = value }
        if let value = snapshot.isAgeSelected { isAgeSelected = value }
        if let value = snapshot.isHeightWeightSelected { isHeightWeightSelected = value }
        if let value = snapshot.isFirstNameEntered { isFirstNameEntered = value }
        if let value = snapshot.isPrimaryGoalSelected { isPrimaryGoalSelected = value }
        if let value = snapshot.isWeightGoalSelected { isWeightGoalSelected = value }
        if let value = snapshot.isIdealWeightEntered { isIdealWeightEntered = value }
        if let value = snapshot.isTrainingFrequencySelected { isTrainingFrequencySelected = value }
        if let value = snapshot.isGoalPaceSelected { isGoalPaceSelected = value }
        isNutritionQualitySelected = nutritionProfile.nutritionQuality != nil
            || (snapshot.isNutritionQualitySelected ?? false)
        if let value = snapshot.isWeightManagementExperienceSelected {
            isWeightManagementExperienceSelected = value
        }
        if let value = snapshot.isWeightMotivationCompleted {
            isWeightMotivationCompleted = value
        }
        if let value = snapshot.isWeightEstimationCompleted {
            isWeightEstimationCompleted = value
        }
        if let value = snapshot.isGoalProjectionCompleted { isGoalProjectionCompleted = value }
        if let value = snapshot.isFaceAnalysisCompleted {
            isFaceAnalysisCompleted = value
        }
        if let value = snapshot.isProgramCreationCompleted { isProgramCreationCompleted = value }
        if let raw = snapshot.dashboardPreviewPresentation, !raw.isEmpty {
            dashboardPreviewPresentation = .firstScanPending
        }
        if let value = snapshot.hasCompletedFirstDashboardPreview {
            hasCompletedFirstDashboardPreview = value
        }
        if let value = snapshot.dashboardScanPersistedState {
            dashboardScanPersistedState = value
        }
    }

    func markProfileChatQuestionCompleted(_ questionID: String) {
        completedProfileChatQuestionIDs.insert(questionID)
        saveProgress()
    }

    /// Remonte le fil de discussion à partir de `questionID` (inclu).
    func rewindProfileChat(from questionID: String, orderedQuestionIDs: [String]) {
        guard let index = orderedQuestionIDs.firstIndex(of: questionID) else { return }
        let toRemove = Set(orderedQuestionIDs[index...])
        completedProfileChatQuestionIDs.subtract(toRemove)
        saveProgress()
    }

    /// Handler retour discussion — `true` si le back a été consommé dans le chat.
    var profileChatBackHandler: (() -> Bool)?

    /// Barre segmentée header (discussion Moss) — alimentée par `OnboardingProfileChatView`.
    @Published var profileChatHeaderProgress: OnboardingProfileChatCoachHeaderProgress.Snapshot?

    /// Marqueur persistant — toujours le 1er tour dashboard (scan).
    @Published var dashboardPreviewPresentation: OnboardingDashboardPreviewPresentation = .firstScanPending

    /// Premier tour dashboard (carrousel + scan) terminé — ne pas rouvrir à la reprise.
    @Published var hasCompletedFirstDashboardPreview = false

    /// Session scan du 1er dashboard — persistée pour reprise (kill app / retour Réglages).
    @Published var dashboardScanPersistedState: OnboardingDashboardScanPersistedState?

    var hasActiveFirstDashboardScanSession: Bool {
        dashboardScanPersistedState != nil
    }

    func persistDashboardScanState(_ state: OnboardingDashboardScanPersistedState) {
        dashboardScanPersistedState = state
        dashboardPreviewPresentation = .firstScanPending
        saveProgress()
    }

    func clearDashboardScanPersistedState() {
        guard dashboardScanPersistedState != nil else { return }
        dashboardScanPersistedState = nil
        saveProgress()
    }

    /// Après un retour manuel vers le chat : ne pas enchaîner automatiquement vers la création du programme.
    var suppressProfileChatAutoFinish = false

    /// Retour depuis « Création du programme » : rouvrir la page résultats du premier scan.
    var shouldReopenFaceScanResultsAfterBack = false

    /// Scan onboarding plein écran — un seul cover (deux `.fullScreenCover` se ferment tout seuls).
    @Published var presentedOnboardingFaceScan: OnboardingFaceScanPresentation?

    var onOnboardingFaceScanCancel: (() -> Void)?
    var onOnboardingFaceScanSkip: (() -> Void)?
    var onOnboardingFaceScanResult: ((FaceScanResult) -> Void)?
    var onOnboardingFaceScanContinue: (() -> Void)?
    var onOnboardingFaceScanContinueFromDashboard: (() -> Void)?

    func configureDashboardPreviewPresentation(entering step: OnboardingStep, from previous: OnboardingStep?) {
        guard step == .dashboardPreview else { return }
        dashboardPreviewPresentation = .firstScanPending
        saveProgress()
    }

    func recordDashboardFaceScanResult(_ result: FaceScanResult) {
        onboardingFaceMesh = OnboardingFaceMarkersStore.loadMesh()
        onboardingFaceMarkers = result.markers
        isFaceAnalysisCompleted = true
        clearDashboardScanPersistedState()
        markProfileChatQuestionCompleted("profile_summary")
        markProfileChatQuestionCompleted("face_scan_offer")
        saveProgress()
    }

    func skipDashboardFaceScanForLater() {
        onboardingFaceMesh = nil
        onboardingFaceMarkers = nil
        isFaceAnalysisCompleted = true
        clearDashboardScanPersistedState()
        markProfileChatQuestionCompleted("profile_summary")
        markProfileChatQuestionCompleted("face_scan_offer")
        ProcessAnalytics.trackMossAction(
            page: .faceScanCapture,
            action: "skipped_later",
            answerDisplay: OnboardingCopy.t("Faire mon scan plus tard", en: "Do my scan later")
        )
        saveProgress()
    }

    /// Valide le brouillon « code créateur » (referralCode step) avant navigation.
    func commitCreatorCodeDraft() {
        guard creatorCodeIsVerified else {
            clearCreatorCodeStep()
            return
        }

        let normalized = ProcessReferralCode.normalize(creatorCodeDraft)
        guard ProcessReferralCode.isValid(normalized) else {
            clearCreatorCodeStep()
            return
        }

        if ProcessAffiliateLifetimePass.matches(normalized) {
            creatorCodeDraft = normalized
            referralCode = nil
            ProcessAffiliateLifetimePass.unlock()
            Task { @MainActor in
                await SubscriptionService.shared.checkSubscriptionStatus()
                SubscriptionService.shared.activateAffiliateLifetimePass()
            }
            saveProgress()
            return
        }

        referralCode = normalized
        creatorCodeDraft = normalized
        ProcessAcquisitionAttribution.captureReferralCode(normalized)
        ProcessAcquisitionAttribution.captureAffiliateCode(normalized)
        ProcessReferralTrialEligibility.unlock(code: normalized)
        saveProgress()
    }

    func clearCreatorCodeStep() {
        creatorCodeDraft = ""
        creatorCodeIsVerified = false
        creatorCodeContinueAttempt = 0
        referralCode = nil
        ProcessReferralAttribution.clearPending()
        ProcessAffiliateAttribution.clearPending()
        saveProgress()
    }

    func bootstrapCreatorCodeDraftIfNeeded() {
        if !creatorCodeDraft.isEmpty { return }
        if let existing = referralCode, !existing.isEmpty {
            creatorCodeDraft = existing
            return
        }
        if let pending = ProcessReferralAttribution.pendingCode ?? ProcessAffiliateAttribution.pendingCode {
            creatorCodeDraft = pending
        }
    }

    func presentOnboardingFaceScan(initialResult: FaceScanResult? = nil, usesChatCallbacks: Bool = true) {
        if OnboardingStep.resolved(from: currentStep) == .dashboardPreview,
           dashboardPreviewPresentation == .firstScanPending,
           initialResult == nil {
            return
        }
        presentedOnboardingFaceScan = OnboardingFaceScanPresentation(
            initialResult: initialResult,
            usesChatCallbacks: usesChatCallbacks
        )
    }

    func dismissOnboardingFaceScan() {
        presentedOnboardingFaceScan = nil
    }

    /// Données du premier scan disponibles pour réafficher l'analyse.
    func restoredFaceScanResultForNavigation() -> FaceScanResult? {
        if let latest = FaceScanHistoryStore.shared.latestResult {
            return latest
        }

        if let markers = onboardingFaceMarkers ?? OnboardingFaceMarkersStore.load() {
            return FaceScanResult(
                id: "onboarding-restored-scan",
                userId: UserScopedStorage.currentUserId() ?? "local-user",
                markers: markers,
                source: .onboarding
            )
        }

        return nil
    }

    /// Réinitialise les validations bloquantes quand l'utilisateur revient en arrière.
    func prepareForBackNavigation(to targetStep: OnboardingStep) {
        let current = OnboardingStep.resolved(from: currentStep)
        if current.liveOrderIndex >= OnboardingStep.programCreation.liveOrderIndex,
           targetStep.liveOrderIndex <= OnboardingStep.programCreation.liveOrderIndex {
            isProgramCreationCompleted = false
        }

        if targetStep == .weightMotivation {
            isWeightMotivationCompleted = false
            suppressProfileChatAutoFinish = true

            if current == .programCreation,
               isFaceAnalysisCompleted {
                shouldReopenFaceScanResultsAfterBack = true
                return
            }

            if current == .dashboardPreview,
               dashboardPreviewPresentation == .firstScanPending {
                let orderedIDs = OnboardingProfileChatQuestionBank.questions(for: self).map(\.id)
                if completedProfileChatQuestionIDs.contains("profile_summary")
                    || completedProfileChatQuestionIDs.contains("face_scan_offer") {
                    rewindProfileChat(from: "profile_summary", orderedQuestionIDs: orderedIDs)
                }
                return
            }

            let orderedIDs = OnboardingProfileChatQuestionBank.questions(for: self).map(\.id)
            if let lastCompleted = orderedIDs.last(where: { completedProfileChatQuestionIDs.contains($0) }) {
                rewindProfileChat(from: lastCompleted, orderedQuestionIDs: orderedIDs)
            }
        }
    }

    private func hasReachedFaceScanStep(savedStep: Int, visited: [Int]) -> Bool {
        if visited.contains(OnboardingStep.dashboardPreview.rawValue) {
            return true
        }
        return isAfterQuestionnairePhase(OnboardingStep.resolved(from: savedStep))
    }

    static func isRealUserFirstName(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let blocked = ["process", "process ai", "utilisateur", "user", "local-user", "anonymous"]
        return !blocked.contains(normalized.lowercased())
    }

    static func isPlausibleWeight(_ value: Double) -> Bool {
        value >= 35 && value <= 250
    }
}

enum OnboardingDashboardPreviewPresentation: String, Equatable {
    case firstScanPending
}

/// Cover scan onboarding (capture live ou résultats déjà calculés).
struct OnboardingFaceScanPresentation: Identifiable, Equatable {
    let id: String
    let initialResult: FaceScanResult?
    let usesChatCallbacks: Bool

    init(initialResult: FaceScanResult? = nil, usesChatCallbacks: Bool = true) {
        self.initialResult = initialResult
        self.usesChatCallbacks = usesChatCallbacks
        if let initialResult {
            id = "results-\(initialResult.id)"
        } else {
            id = "live-capture"
        }
    }
}
