//
//  OnboardingStep.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import Foundation

enum OnboardingStep: Int, CaseIterable {
    case videoIntroduction = 0              // Welcome + connexion Apple / démo
    case genderSelection = 1
    case ageSelection = 2
    case height = 3                         // ✨ Taille (nouvelle page séparée)
    case weight = 67                         // ✨ Poids (nouvelle page séparée)
    case heightWeight = 68                   // ✨ Ancienne page combinée (dépréciée, gardée pour compatibilité)
    case bodyScan = 63                      // Conservé compat sauvegarde — scan corps dans l'app, saut auto
    case firstNameInput = 4
    case personalizedWelcome = 5             // ✨ Page de bienvenue personnalisée après prénom
    case processResultsDurability = 6       // ✨ Process génère des résultats durables (graphique performance)
    case primaryGoal = 7                    // As-tu un objectif de poids ? (Oui/Non)

    // Questions spécifiques selon l'objectif poids
    case weightGoal = 8                    // Conservé compat sauvegarde — perdre/prendre supprimé, saut auto
    case weightGoalIncompatible = 9        // ✨ Objectif incompatible avec IMC (blocage)
    case idealWeight = 10                   // Poids idéal (si objectif poids = Oui)
    case weightMotivation = 11                // ✨ Page de motivation après poids idéal
    case hasSportActivity = 12              // ✨ Pratiques-tu une activité sportive ? (Oui/Non)
    case sportSelection = 13                // Si primaryGoal = cardio / récupération / énergie (boostPerformance…)
    case sportClub = 14                     // Conservé compat sauvegarde — en club supprimé, saut auto
    case experienceLevel = 15               // Conservé compat sauvegarde — niveau supprimé, saut auto
    /// Conservé pour compatibilité sauvegarde — écran supprimé.
    case yearsOfExperience = 16

    // Questions générales (TOUS les utilisateurs passent par là)
    case deadlineSelection = 17              // ✨ Sélection de deadline (si poids non sélectionné)
    case eventDetails = 18                    // ✨ Détails de l'événement (date, type, etc.) - après deadlineSelection si "Oui"
    case goalProjection = 19                  // ✨ Projection dynamique avec courbe (après deadline)
    case goalPace = 20                        // ✨ Vitesse d'atteinte d'objectif poids (si objectif poids sélectionné)
    case potentialPace = 21                   // ✨ Vitesse d'atteinte de 100% du potentiel (si objectif poids NON sélectionné)
    case weightEstimation = 22                // ✨ Estimation de la date d'atteinte du poids idéal
    case trainingFrequency = 23                // ✨ Fréquence d'entraînement (pour tous)

    // Nutrition (TOUS les utilisateurs passent par là)
    case nutritionQuality = 24                // ✨ Qualité de l'alimentation actuelle
    /// Conservé pour compatibilité sauvegarde — écrans supprimés, saut automatique.
    case nutritionScanFeature = 25
    /// Conservé pour compatibilité sauvegarde — écrans supprimés, saut automatique.
    case hasDietaryRestrictions = 26
    /// Conservé pour compatibilité sauvegarde — écrans supprimés, saut automatique.
    case whichRestrictions = 27
    case nutritionObstacles = 28              // ✨ Obstacles à une bonne nutrition
    case weightManagementExperience = 29      // ✨ Expérience avec perte/prise de poids (si objectif poids)
    case weightFailureReasons = 30            // ✨ Qu'est-ce qui t'empêche de réussir ? (si triedMultiple ou currentlyTrying)
    case perfectNutritionBelief = 31          // ✨ Croyance en une alimentation parfaite
    case hardestMeal = 32                     // Conservé compat sauvegarde — repas difficile supprimé, saut auto
    case nutritionPotential = 33              // Conservé compat sauvegarde — écran supprimé, saut auto
    case hasSufficientHydration = 34          // ✨ Penses-tu t'hydrater suffisamment ? (Oui/Non)
    case hydrationLevel = 35                  // ✨ Niveau d'hydratation

    // Sommeil (TOUS les utilisateurs passent par là)
    case sleepInfo = 36                       // ✨ Information sur l'importance du sommeil
    case sleepQuality = 37                    // ✨ Qualité perçue du sommeil
    case fatigueFrequency = 38                // ✨ Fréquence de fatigue
    case fatiguePeaks = 39                    // ✨ Pics de fatigue
    case sleepNeed = 40                       // ✨ Découvre ton besoin de sommeil réel

    // Finalisation
    case healthKitPermissions = 41            // ✨ Autoriser l'accès HealthKit
    case faceAnalysis = 42                    // ✨ Analyse faciale (cernes, rétention d'eau, sommeil)
    case planGeneration = 43                  // ✨ Créons ton plan personnalisé
    case sleepDataRecovery = 44                // ✨ Animation récupération données HealthKit
    /// Valeurs conservées pour compatibilité sauvegarde — écrans supprimés, saut automatique.
    case newsStep = 45
    case sleepNeedReveal = 46
    case sleepDebtInfo = 47
    case alarmConfiguration = 48                // Conservé compat sauvegarde — écran supprimé, saut auto
    case sleepWindowReveal = 49                // Conservé compat sauvegarde — écran supprimé, saut auto
    case planReady = 50                        // ✨ Ton programme personnalisé est prêt
    case onboardingInfo = 51                   // ✨ Page d'information (texte + bouton continuer)
    case appleSignIn = 52                   // Conservé compat sauvegarde — auth sur welcome, saut auto
    case referralCode = 53                     // ✨ Entrez le code de parrainage (facultatif)
    case appRating = 54                        // Conservé compat sauvegarde — écran supprimé, saut auto
    case caloriesGoal = 55                     // ✨ Ajouter les calories brûlées à votre objectif quotidien ?
    case carryOverCalories = 56                // ✨ Reportez-vous aux calories supplémentaires au lendemain ?
    case programCreation = 57               // ✨ Création du programme (analyse habitudes, plan 13 semaines)
    case biometricAuth = 58                    // ✨ Authentification biométrique (empreinte digitale)
    case notificationPermission = 59           // ✨ Demande de permission notifications
    case payment = 60
    case processWelcome = 61                   // ✨ Page de bienvenue "Bienvenue dans PROCESS"
    case referralReward = 62                   // ✨ Page de parrainage avec slider de gains
    case featuresUnlock = 65                   // ✨ Page de déblocage progressif des fonctionnalités
    case complete = 66
    // Note: bodyScan = 63 est placé après heightWeight mais avant firstNameInput pour logique de flow

    var usesInternalContinueAction: Bool {
        switch self {
        case .videoIntroduction, .faceAnalysis, .weightMotivation, .sportSelection,
             .healthKitPermissions, .biometricAuth, .notificationPermission,
             .payment, .processWelcome, .referralReward, .featuresUnlock,
             .referralCode, .appleSignIn, .appRating, .sleepDataRecovery,
             .personalizedWelcome, .processResultsDurability,
             .weightGoalIncompatible:
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

    static let semanticOrder: [OnboardingStep] = [
        .videoIntroduction,
        .genderSelection,
        .ageSelection,
        .height,
        .weight,
        .heightWeight,
        .bodyScan,
        .firstNameInput,
        .personalizedWelcome,
        .processResultsDurability,
        .primaryGoal,
        .weightGoal,
        .idealWeight,
        .weightGoalIncompatible,
        .weightMotivation,
        .goalPace,
        .weightEstimation,
        .hasSportActivity,
        .sportSelection,
        .sportClub,
        .experienceLevel,
        .yearsOfExperience,
        .trainingFrequency,
        .deadlineSelection,
        .eventDetails,
        .potentialPace,
        .goalProjection,
        .weightManagementExperience,
        .weightFailureReasons,
        .nutritionQuality,
        .nutritionScanFeature,
        .hasDietaryRestrictions,
        .whichRestrictions,
        .nutritionObstacles,
        .perfectNutritionBelief,
        .hardestMeal,
        .nutritionPotential,
        .hasSufficientHydration,
        .hydrationLevel,
        .sleepInfo,
        .sleepQuality,
        .fatigueFrequency,
        .fatiguePeaks,
        .sleepNeed,
        .faceAnalysis,
        .programCreation,
        .planGeneration,
        .healthKitPermissions,
        .sleepDataRecovery,
        .newsStep,
        .sleepNeedReveal,
        .sleepDebtInfo,
        .alarmConfiguration,
        .sleepWindowReveal,
        .planReady,
        .onboardingInfo,
        .appleSignIn,
        .referralCode,
        .appRating,
        .caloriesGoal,
        .carryOverCalories,
        .biometricAuth,
        .notificationPermission,
        .payment,
        .processWelcome,
        .referralReward,
        .featuresUnlock,
        .complete
    ]

    var semanticOrderIndex: Int {
        Self.semanticOrder.firstIndex(of: self) ?? rawValue
    }

    /// Étapes sautées automatiquement — absentes de l'historique retour.
    var isTransientSkippedStep: Bool {
        switch self {
        case .heightWeight, .bodyScan, .weightGoal, .sportClub, .experienceLevel, .hardestMeal,
             .appleSignIn,
             .yearsOfExperience, .deadlineSelection, .eventDetails,
             .potentialPace, .trainingFrequency, .nutritionScanFeature,
             .hasDietaryRestrictions, .whichRestrictions,
             .nutritionObstacles, .perfectNutritionBelief, .hasSufficientHydration, .hydrationLevel,
             .nutritionPotential,
             .goalPace, .hasSportActivity, .sportSelection,
             .weightManagementExperience, .weightFailureReasons, .nutritionQuality,
             .sleepNeed, .planGeneration,
             .newsStep, .sleepNeedReveal, .sleepDebtInfo, .planReady, .onboardingInfo,
             .alarmConfiguration, .sleepWindowReveal,
             .referralCode, .caloriesGoal, .carryOverCalories, .appRating,
             .processWelcome, .referralReward, .featuresUnlock, .complete,
             .sleepInfo, .sleepQuality, .fatigueFrequency, .fatiguePeaks,
             .personalizedWelcome, .processResultsDurability,
             .sleepDataRecovery, .primaryGoal:
            return true
        default:
            return false
        }
    }
}
