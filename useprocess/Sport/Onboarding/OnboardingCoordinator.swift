//
//  OnboardingCoordinator.swift
//  Process
//
//  Coordonnateur pour gérer la sauvegarde et la synchronisation des données
//

import Foundation

@MainActor
class OnboardingCoordinator {
    let viewModel: OnboardingViewModel
    let profileService: UnifiedProfileService

    init(viewModel: OnboardingViewModel, profileService: UnifiedProfileService) {
        self.viewModel = viewModel
        self.profileService = profileService
    }

    // MARK: - Profile Creation & Synchronization

    /// Créer ou mettre à jour le profil avec les données de l'onboarding
    func syncProfileWithViewModel() async throws {
        guard let userId = AuthUser.current?.uid else {
            return
        }

        // Si le profil n'existe pas encore, le créer
        if profileService.currentProfile == nil {
            let onboardingData = OnboardingDataModel.shared
            var sportsToUse = onboardingData.selectedSports
            if sportsToUse.isEmpty, let saved = UserDefaults.standard.array(forKey: "onboarding_selected_sports") as? [String], !saved.isEmpty {
                sportsToUse = Set(saved)
            }
            let sportsArray: [Sport]
            if sportsToUse.isEmpty {
                sportsArray = [Sport(name: "Course à pied", category: .cardio, frequency: .weekly, intensity: .moderate)]
            } else {
                sportsArray = sportsToUse.map { Sport(name: $0, category: .cardio, frequency: .weekly, intensity: .moderate) }
            }

            var newProfile = UnifiedUserProfile(
                userId: userId,
                firstName: viewModel.firstName.isEmpty ? "" : viewModel.firstName,
                birthDate: Calendar.current.date(byAdding: .year, value: -viewModel.selectedAge, to: Date()) ?? Date(),
                gender: viewModel.selectedGender ?? .male,
                height: viewModel.selectedHeight,
                weight: viewModel.selectedWeight,
                idealWeight: viewModel.idealWeightValue > 0 ? viewModel.idealWeightValue : nil
            )

            // ✅ CRITIQUE: Ajouter les sports au nouveau profil
            newProfile.sports = sportsArray

            try await profileService.saveProfile(newProfile)

            // ✨ Vérifier si un code de parrainage a été utilisé
            if let referralCode = viewModel.referralCode, !referralCode.isEmpty {
                do {
                    try await ReferralService.shared.registerReferral(
                        referralCode: referralCode,
                        referredUserId: userId
                    )
                } catch {
                    // Ne pas bloquer l'onboarding en cas d'erreur
                }
            }
        } else {
            // Mettre à jour le profil existant
            guard var currentProfile = profileService.currentProfile else {
                return
            }

            // ✅ CRITIQUE: Synchroniser toutes les données
            currentProfile.firstName = viewModel.firstName.isEmpty ? currentProfile.firstName : viewModel.firstName

            // ✅ CRITIQUE: Utiliser updateAge pour garantir la cohérence âge/birthDate
            if viewModel.selectedAge > 0 && viewModel.selectedAge <= 120 {
                currentProfile.updateAge(viewModel.selectedAge)
            }

            currentProfile.gender = viewModel.selectedGender ?? currentProfile.gender
            currentProfile.height = viewModel.selectedHeight > 0 ? viewModel.selectedHeight : currentProfile.height

            // ✅ CRITIQUE: Toujours mettre à jour le poids si > 0 (même si déjà présent)
            if viewModel.selectedWeight > 0 {
                currentProfile.weight = viewModel.selectedWeight
            }

            currentProfile.idealWeight = viewModel.idealWeightValue > 0 ? viewModel.idealWeightValue : currentProfile.idealWeight

            // ✅ CRITIQUE: Synchroniser les sports depuis onboardingData (ou persistance UserDefaults)
            let onboardingData = OnboardingDataModel.shared
            var sportsToUse = onboardingData.selectedSports
            if sportsToUse.isEmpty, let saved = UserDefaults.standard.array(forKey: "onboarding_selected_sports") as? [String], !saved.isEmpty {
                sportsToUse = Set(saved)
                onboardingData.selectedSports = sportsToUse
            }
            if !sportsToUse.isEmpty {
                let sportsArray = sportsToUse.map { sportName in
                    Sport(
                        name: sportName,
                        category: .cardio,
                        frequency: .weekly,
                        intensity: .moderate
                    )
                }
                currentProfile.sports = sportsArray
            } else if let existingSports = profileService.currentProfile?.sports, !existingSports.isEmpty {
            } else {
                // ✅ Fallback: au moins un sport pour que le Plan ne plante pas (validation "au moins un sport")
                currentProfile.sports = [Sport(name: "Course à pied", category: .cardio, frequency: .weekly, intensity: .moderate)]
            }

            // Données du plan
            currentProfile.weightGoal = viewModel.selectedWeightGoal
            currentProfile.goalDeadline = viewModel.goalDeadline
            currentProfile.goalPace = viewModel.selectedGoalPace
            currentProfile.nutritionProfile = viewModel.nutritionProfile
            // ✅ FINALISATION: SleepProfile vient maintenant du ViewModel
            currentProfile.sleepProfile = viewModel.sleepProfile
            currentProfile.experienceLevel = viewModel.selectedExperienceLevel
            currentProfile.yearsOfExperience = viewModel.selectedYearsOfExperience > 0 ? viewModel.selectedYearsOfExperience : nil
            // selectedTrainingFrequency n'existe pas dans UnifiedUserProfile, utiliser activityLevel à la place
            if let frequency = viewModel.selectedTrainingFrequency {
                switch frequency {
                case "0-2":
                    currentProfile.activityLevel = .low
                case "3-5":
                    currentProfile.activityLevel = .moderate
                case "6+":
                    currentProfile.activityLevel = .high
                default:
                    break
                }
            }
            currentProfile.sessionsPerWeek = viewModel.selectedSessionsPerWeek
            currentProfile.sessionDuration = viewModel.selectedSessionDuration
            currentProfile.trainingLocation = viewModel.selectedTrainingLocation
            currentProfile.availableEquipment = Array(viewModel.selectedEquipment)

            // ✅ CRITIQUE: Mettre à jour lastUpdated avant sauvegarde
            currentProfile.updateLastUpdated()

            // ✅ CRITIQUE: Logger AVANT sauvegarde

            try await profileService.saveProfile(currentProfile)

            // ✅ CRITIQUE: Recharger le profil immédiatement après sauvegarde pour vérifier
            await profileService.loadProfile()

            // ✅ CRITIQUE: Vérifier que les données sont bien chargées
            if let reloadedProfile = profileService.currentProfile {

                // Vérifier la cohérence
                if reloadedProfile.weight != currentProfile.weight {
                }
                if reloadedProfile.sports.count != currentProfile.sports.count {
                }
            } else {
            }
        }
    }

    /// Sauvegarder toutes les données de l'onboarding dans le profil final
    func saveAllOnboardingData() async throws {
        try await syncProfileWithViewModel()

        // Marquer l'onboarding comme terminé
        guard var profile = profileService.currentProfile else {
            throw OnboardingError.notAuthenticated
        }

        profile.hasCompletedOnboarding = true
        try await profileService.saveProfile(profile)
    }
}
