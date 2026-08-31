//
//  OnboardingStep.swift
//  Process
//
//  Étapes **live** uniquement. Les anciens raw values persistés sont
//  migrés via `resolved(from:)`.
//

import Foundation

enum OnboardingStep: Int, CaseIterable {
    case genderSelection = 1
    case ageSelection = 2
    case height = 3
    case firstNameInput = 4
    case weightMotivation = 11
    case weightEstimation = 22
    case appleSignIn = 52
    case referralCode = 53
    case programCreation = 57
    case biometricAuth = 58
    case payment = 60
    case transformationPreview = 64
    case complete = 66
    case weight = 67
    case dashboardPreview = 69
    case dreamFaceCommit = 70
    case faceLeverageIntro = 71
    case postPaymentWelcome = 72
    case explainerBodyFat = 73
    case explainerWaterRetention = 74
    case explainerLymphDrainage = 75

    /// Parcours réel (écrans visibles), dans l’ordre utilisateur.
    static let liveOrder: [OnboardingStep] = [
        .genderSelection,
        .ageSelection,
        .height,
        .weight,
        .firstNameInput,
        .faceLeverageIntro,
        .weightMotivation,
        .dashboardPreview,
        .programCreation,
        .weightEstimation,
        .biometricAuth,
        .transformationPreview,
        .referralCode,
        .dreamFaceCommit,
        .payment,
        .postPaymentWelcome,
        .explainerBodyFat,
        .explainerWaterRetention,
        .explainerLymphDrainage,
        .appleSignIn,
        .complete
    ]

    var liveOrderIndex: Int {
        Self.liveOrder.firstIndex(of: self) ?? rawValue
    }

    var usesInternalContinueAction: Bool {
        switch self {
        case .weightMotivation, .biometricAuth, .transformationPreview,
             .dashboardPreview, .dreamFaceCommit, .programCreation,
             .payment, .appleSignIn, .faceLeverageIntro,
             .postPaymentWelcome, .explainerBodyFat, .explainerWaterRetention, .explainerLymphDrainage:
            return true
        default:
            return false
        }
    }

    static var maxRawValue: Int {
        allCases.map(\.rawValue).max() ?? 0
    }

    static var validSavedStepUpperBound: Int {
        maxRawValue + 1
    }

    /// Code créateur optionnel uniquement — plus d’étapes fantômes.
    var isTransientSkippedStep: Bool {
        if self == .referralCode {
            return !OnboardingConstants.showsReferralCodeStepInOnboarding
        }
        return false
    }

    /// Reprise sans abonnement : on ne relance pas le paywall.
    var unpaidResumeStep: OnboardingStep {
        switch self {
        case .payment, .appleSignIn, .dreamFaceCommit, .complete,
             .postPaymentWelcome, .explainerBodyFat, .explainerWaterRetention, .explainerLymphDrainage:
            return .dreamFaceCommit
        default:
            return self
        }
    }

    /// Étape live correspondant à une valeur persistée (y compris anciens raw).
    static func resolved(from raw: Int) -> OnboardingStep {
        if let step = Self(rawValue: raw) {
            return step
        }
        return migrateLegacyRawValue(raw)
    }

    private static func migrateLegacyRawValue(_ raw: Int) -> OnboardingStep {
        switch raw {
        case 0:
            return .genderSelection
        case 5, 6, 7, 8, 9, 10:
            return .weightMotivation
        case 12, 13, 14, 15, 16, 17, 18:
            return .dashboardPreview
        case 19, 20, 21, 23:
            return .weightEstimation
        case 24...40, 41:
            return .programCreation
        case 42:
            return .dashboardPreview
        case 43...51, 54, 55, 56:
            return .biometricAuth
        case 59:
            return .dreamFaceCommit
        case 61, 62, 65:
            return .appleSignIn
        case 63:
            return .firstNameInput
        case 68:
            return .weight
        default:
            return .genderSelection
        }
    }
}
