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
                firstName: OnboardingViewModel.isRealUserFirstName(viewModel.firstName) ? viewModel.firstName : "",
                birthDate: Calendar.current.date(byAdding: .year, value: -viewModel.selectedAge, to: Date()) ?? Date(),
                gender: viewModel.selectedGender ?? .male,
                height: viewModel.selectedHeight,
                weight: OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight) ? viewModel.selectedWeight : 0,
                idealWeight: OnboardingViewModel.isPlausibleWeight(viewModel.idealWeightValue) ? viewModel.idealWeightValue : nil
            )

            // ✅ CRITIQUE: Ajouter les sports au nouveau profil
            newProfile.sports = sportsArray
            newProfile.onboardingPrimaryFocus = viewModel.onboardingPrimaryFocus
            newProfile.onboardingDebloatDrivers = viewModel.onboardingDebloatDrivers.sorted {
                $0.rawValue < $1.rawValue
            }
            newProfile.onboardingRoutineChallenges = viewModel.onboardingRoutineChallenges.sorted {
                $0.rawValue < $1.rawValue
            }

            try await profileService.saveProfile(newProfile)

            // ✨ Code parrainage / créateur (étape onboarding ou fallback paywall)
            if let referralCode = Self.resolvedAcquisitionCode(from: viewModel), !referralCode.isEmpty {
                await AcquisitionCodeService.registerIfPresent(
                    code: referralCode,
                    referredUserId: userId,
                    displayName: newProfile.firstName.isEmpty ? newProfile.username : newProfile.firstName
                )
                ProcessReferralAttribution.clearPending()
                ProcessAffiliateAttribution.clearPending()
            }
        } else {
            // Mettre à jour le profil existant
            guard var currentProfile = profileService.currentProfile else {
                return
            }

            // ✅ CRITIQUE: Synchroniser toutes les données
            if OnboardingViewModel.isRealUserFirstName(viewModel.firstName) {
                currentProfile.firstName = viewModel.firstName
            }

            // ✅ CRITIQUE: Utiliser updateAge pour garantir la cohérence âge/birthDate
            if viewModel.selectedAge > 0 && viewModel.selectedAge <= 120 {
                currentProfile.updateAge(viewModel.selectedAge)
            }

            currentProfile.gender = viewModel.selectedGender ?? currentProfile.gender
            currentProfile.height = viewModel.selectedHeight > 0 ? viewModel.selectedHeight : currentProfile.height

            // ✅ CRITIQUE: Toujours mettre à jour le poids si > 0 (même si déjà présent)
            if OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight) {
                currentProfile.weight = viewModel.selectedWeight
            }

            currentProfile.idealWeight = OnboardingViewModel.isPlausibleWeight(viewModel.idealWeightValue) ? viewModel.idealWeightValue : currentProfile.idealWeight

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
                case "0-2", "1-2":
                    currentProfile.activityLevel = .low
                case "3-5", "3-4":
                    currentProfile.activityLevel = .moderate
                case "6+", "5+":
                    currentProfile.activityLevel = .high
                default:
                    break
                }
            }
            currentProfile.sessionsPerWeek = viewModel.selectedSessionsPerWeek
            currentProfile.sessionDuration = viewModel.selectedSessionDuration
            currentProfile.trainingLocation = viewModel.selectedTrainingLocation
            currentProfile.availableEquipment = Array(viewModel.selectedEquipment)
            currentProfile.onboardingPrimaryFocus = viewModel.onboardingPrimaryFocus
            currentProfile.onboardingDebloatDrivers = viewModel.onboardingDebloatDrivers.sorted {
                $0.rawValue < $1.rawValue
            }
            currentProfile.onboardingRoutineChallenges = viewModel.onboardingRoutineChallenges.sorted {
                $0.rawValue < $1.rawValue
            }

            // ✅ CRITIQUE: Mettre à jour lastUpdated avant sauvegarde
            currentProfile.updateLastUpdated()

            // ✅ CRITIQUE: Logger AVANT sauvegarde

            try await profileService.saveProfile(currentProfile)

            if let referralCode = Self.resolvedAcquisitionCode(from: viewModel), !referralCode.isEmpty,
               let userId = AuthUser.current?.uid {
                await AcquisitionCodeService.registerIfPresent(
                    code: referralCode,
                    referredUserId: userId,
                    displayName: currentProfile.firstName.isEmpty ? currentProfile.username : currentProfile.firstName
                )
                ProcessReferralAttribution.clearPending()
                ProcessAffiliateAttribution.clearPending()
            }

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

    private static func resolvedAcquisitionCode(from viewModel: OnboardingViewModel) -> String? {
        if let code = viewModel.referralCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            return code
        }
        return ProcessReferralAttribution.pendingCode ?? ProcessAffiliateAttribution.pendingCode
    }
}
