import Foundation

/// Parcours onboarding **réel** (écrans visibles), dans l’ordre utilisateur.
/// Source unique pour PostHog — ne plus utiliser `OnboardingStep.semanticOrder`.
enum OnboardingFunnelScreen: String, CaseIterable, Sendable {
    case gender
    case age
    case height
    case weight
    case firstName
    case faceLeverage
    case chatIntroSwollenFace
    case chatIntroCauses
    case chatIntroNext
    case chatGlowUpResults
    case chatDebloatDriver
    case chatHydration
    case chatJunkFood
    case chatSleepHours
    case chatCardio
    case chatProfileSummary
    case dashboardPreview
    case faceScanCapture
    case faceScanAnalyzing
    case faceScanResults
    case programCreation
    case programCreationHealth
    case programCreationHealthKitPopup
    case programCreationProfile
    case programCreationTriedDebloat
    case programCreationPlan
    case programCreationSuccess
    case weightEstimation
    case biometricAuth
    case transformation
    case referralCode
    case dreamFaceCommit
    case paywall
    case purchaseStarted
    case purchaseCompleted
    case appleSignIn

    var id: String { rawValue }

    var funnelIndex: Int {
        Self.allCases.firstIndex(of: self) ?? -1
    }

    var phase: String {
        switch self {
        case .gender, .age, .height, .weight, .firstName, .faceLeverage:
            return "profile"
        case .chatIntroSwollenFace, .chatIntroCauses, .chatIntroNext, .chatGlowUpResults,
             .chatDebloatDriver, .chatHydration, .chatJunkFood,
             .chatSleepHours, .chatCardio, .chatProfileSummary:
            return "chat"
        case .dashboardPreview, .faceScanCapture, .faceScanAnalyzing, .faceScanResults:
            return "scan"
        case .programCreation, .programCreationHealth, .programCreationHealthKitPopup,
             .programCreationProfile, .programCreationTriedDebloat,
             .programCreationPlan, .programCreationSuccess, .weightEstimation:
            return "program"
        case .biometricAuth, .transformation, .referralCode, .dreamFaceCommit:
            return "commitment"
        case .paywall, .purchaseStarted, .purchaseCompleted, .appleSignIn:
            return "paywall"
        }
    }

    var labelFR: String {
        switch self {
        case .gender: return "Genre"
        case .age: return "Âge"
        case .height: return "Taille"
        case .weight: return "Poids"
        case .firstName: return "Prénom"
        case .faceLeverage: return "Levier visage"
        case .chatIntroSwollenFace: return "Chat · visage gonflé"
        case .chatIntroCauses: return "Chat · causes"
        case .chatIntroNext: return "Chat · ensuite"
        case .chatGlowUpResults: return "Chat · glow-up"
        case .chatDebloatDriver: return "Chat · gonflé au réveil"
        case .chatHydration: return "Chat · hydratation"
        case .chatJunkFood: return "Chat · malbouffe"
        case .chatSleepHours: return "Chat · sommeil"
        case .chatCardio: return "Chat · cardio"
        case .chatProfileSummary: return "Chat · dashboard prêt"
        case .dashboardPreview: return "Dashboard"
        case .faceScanCapture: return "Scan · capture"
        case .faceScanAnalyzing: return "Scan · analyse"
        case .faceScanResults: return "Scan · résultats"
        case .programCreation: return "Création programme"
        case .programCreationHealth: return "Programme · santé"
        case .programCreationHealthKitPopup: return "Programme · HealthKit"
        case .programCreationProfile: return "Programme · profil"
        case .programCreationTriedDebloat: return "Programme · déjà tenté"
        case .programCreationPlan: return "Programme · plan"
        case .programCreationSuccess: return "Programme · prêt"
        case .weightEstimation: return "Estimation"
        case .biometricAuth: return "Face ID / Touch ID"
        case .transformation: return "Transformation"
        case .referralCode: return "Code créateur"
        case .dreamFaceCommit: return "Engagement visage"
        case .paywall: return "Paywall"
        case .purchaseStarted: return "Apple Pay ouvert"
        case .purchaseCompleted: return "Payé"
        case .appleSignIn: return "Connexion Apple"
        }
    }

    var labelEN: String {
        switch self {
        case .gender: return "Gender"
        case .age: return "Age"
        case .height: return "Height"
        case .weight: return "Weight"
        case .firstName: return "First name"
        case .faceLeverage: return "Face leverage"
        case .chatIntroSwollenFace: return "Chat · puffy face"
        case .chatIntroCauses: return "Chat · causes"
        case .chatIntroNext: return "Chat · next"
        case .chatGlowUpResults: return "Chat · glow-up"
        case .chatDebloatDriver: return "Chat · puffy on wake"
        case .chatHydration: return "Chat · hydration"
        case .chatJunkFood: return "Chat · junk food"
        case .chatSleepHours: return "Chat · sleep"
        case .chatCardio: return "Chat · cardio"
        case .chatProfileSummary: return "Chat · dashboard ready"
        case .dashboardPreview: return "Dashboard"
        case .faceScanCapture: return "Scan · capture"
        case .faceScanAnalyzing: return "Scan · analyzing"
        case .faceScanResults: return "Scan · results"
        case .programCreation: return "Program creation"
        case .programCreationHealth: return "Program · health"
        case .programCreationHealthKitPopup: return "Program · HealthKit"
        case .programCreationProfile: return "Program · profile"
        case .programCreationTriedDebloat: return "Program · already tried"
        case .programCreationPlan: return "Program · plan"
        case .programCreationSuccess: return "Program · ready"
        case .weightEstimation: return "Estimate"
        case .biometricAuth: return "Face ID / Touch ID"
        case .transformation: return "Transformation"
        case .referralCode: return "Creator code"
        case .dreamFaceCommit: return "Face commitment"
        case .paywall: return "Paywall"
        case .purchaseStarted: return "Apple Pay opened"
        case .purchaseCompleted: return "Paid"
        case .appleSignIn: return "Sign in with Apple"
        }
    }

    static func from(step: OnboardingStep) -> OnboardingFunnelScreen? {
        switch step {
        case .genderSelection: return .gender
        case .ageSelection: return .age
        case .height: return .height
        case .weight: return .weight
        case .firstNameInput: return .firstName
        case .faceLeverageIntro: return .faceLeverage
        case .weightMotivation: return nil
        case .dashboardPreview: return .dashboardPreview
        case .programCreation: return .programCreation
        case .weightEstimation: return .weightEstimation
        case .biometricAuth: return .biometricAuth
        case .transformationPreview: return .transformation
        case .referralCode: return .referralCode
        case .dreamFaceCommit: return .dreamFaceCommit
        case .payment: return .paywall
        case .appleSignIn: return .appleSignIn
        default: return nil
        }
    }

    static func from(chatQuestionID: String) -> OnboardingFunnelScreen? {
        switch chatQuestionID {
        case "intro_swollen_face": return .chatIntroSwollenFace
        case "intro_causes": return .chatIntroCauses
        case "intro_next": return .chatIntroNext
        case "debloat_driver": return .chatDebloatDriver
        case "hydration_level": return .chatHydration
        case "junk_food": return .chatJunkFood
        case "sleep_hours": return .chatSleepHours
        case "cardio_frequency": return .chatCardio
        case "profile_summary", "face_scan_offer": return .chatProfileSummary
        default: return nil
        }
    }

    static func from(mossPage: ProcessAnalytics.MossPage) -> OnboardingFunnelScreen? {
        switch mossPage {
        case .introSwollenFace: return .chatIntroSwollenFace
        case .introCauses: return .chatIntroCauses
        case .introNext: return .chatIntroNext
        case .glowUpResults: return .chatGlowUpResults
        case .debloatDriver: return .chatDebloatDriver
        case .hydrationLevel: return .chatHydration
        case .junkFood: return .chatJunkFood
        case .sleepHours: return .chatSleepHours
        case .cardioFrequency: return .chatCardio
        case .profileSummary, .faceScanOffer: return .chatProfileSummary
        case .faceScanCapture: return .faceScanCapture
        case .faceScanAnalyzing: return .faceScanAnalyzing
        case .faceScanResults: return .faceScanResults
        case .programCreationPhaseHealth: return .programCreationHealth
        case .programCreationPopupHealthKit: return .programCreationHealthKitPopup
        case .programCreationPhaseProfile: return .programCreationProfile
        case .programCreationPopupTriedDebloat: return .programCreationTriedDebloat
        case .programCreationPhasePlan: return .programCreationPlan
        case .programCreationSuccess: return .programCreationSuccess
        }
    }
}
