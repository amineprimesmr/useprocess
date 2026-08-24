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

        if profileService.currentProfile == nil {
            var newProfile = UnifiedUserProfile(
                userId: userId,
                firstName: OnboardingViewModel.isRealUserFirstName(viewModel.firstName) ? viewModel.firstName : "",
                birthDate: Calendar.current.date(byAdding: .year, value: -viewModel.selectedAge, to: Date()) ?? Date(),
                gender: viewModel.selectedGender ?? .male,
                height: viewModel.selectedHeight,
                weight: OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight) ? viewModel.selectedWeight : 0,
                idealWeight: OnboardingViewModel.isPlausibleWeight(viewModel.idealWeightValue) ? viewModel.idealWeightValue : nil
            )

            newProfile.sports = Self.resolvedSports()
            newProfile.onboardingDebloatDrivers = viewModel.onboardingDebloatDrivers.sorted {
                $0.rawValue < $1.rawValue
            }
            applyPlanDefaults(to: &newProfile)

            try await profileService.saveProfile(newProfile)

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
            guard var currentProfile = profileService.currentProfile else {
                return
            }

            if OnboardingViewModel.isRealUserFirstName(viewModel.firstName) {
                currentProfile.firstName = viewModel.firstName
            }

            if viewModel.selectedAge > 0 && viewModel.selectedAge <= 120 {
                currentProfile.updateAge(viewModel.selectedAge)
            }

            currentProfile.gender = viewModel.selectedGender ?? currentProfile.gender
            currentProfile.height = viewModel.selectedHeight > 0 ? viewModel.selectedHeight : currentProfile.height

            if OnboardingViewModel.isPlausibleWeight(viewModel.selectedWeight) {
                currentProfile.weight = viewModel.selectedWeight
            }

            currentProfile.idealWeight = OnboardingViewModel.isPlausibleWeight(viewModel.idealWeightValue)
                ? viewModel.idealWeightValue
                : currentProfile.idealWeight

            let sports = Self.resolvedSports()
            if !sports.isEmpty {
                currentProfile.sports = sports
            } else if currentProfile.sports.isEmpty {
                currentProfile.sports = [Self.fallbackSport]
            }

            currentProfile.weightGoal = viewModel.selectedWeightGoal
            currentProfile.goalPace = viewModel.selectedGoalPace
            currentProfile.nutritionProfile = viewModel.nutritionProfile
            currentProfile.sleepProfile = viewModel.sleepProfile
            currentProfile.onboardingDebloatDrivers = viewModel.onboardingDebloatDrivers.sorted {
                $0.rawValue < $1.rawValue
            }

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

            applyPlanDefaults(to: &currentProfile)
            currentProfile.updateLastUpdated()

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

            await profileService.loadProfile()
        }
    }

    /// Sauvegarder toutes les données de l'onboarding dans le profil final
    func saveAllOnboardingData() async throws {
        try await syncProfileWithViewModel()

        guard var profile = profileService.currentProfile else {
            throw OnboardingError.notAuthenticated
        }

        profile.hasCompletedOnboarding = true
        try await profileService.saveProfile(profile)
    }

    private static let fallbackSport = Sport(
        name: "Course à pied",
        category: .cardio,
        frequency: .weekly,
        intensity: .moderate
    )

    private static func resolvedSports() -> [Sport] {
        var sportsToUse = OnboardingDataModel.shared.selectedSports
        if sportsToUse.isEmpty,
           let saved = UserDefaults.standard.array(forKey: "onboarding_selected_sports") as? [String],
           !saved.isEmpty {
            sportsToUse = Set(saved)
            OnboardingDataModel.shared.selectedSports = sportsToUse
        }
        if sportsToUse.isEmpty {
            return [fallbackSport]
        }
        return sportsToUse.map {
            Sport(name: $0, category: .cardio, frequency: .weekly, intensity: .moderate)
        }
    }

    /// Defaults plan — plus d’écrans club / matériel / deadline dans le funnel live.
    private func applyPlanDefaults(to profile: inout UnifiedUserProfile) {
        if profile.goalDeadline == nil {
            profile.goalDeadline = GoalDeadline()
        }
        if profile.sessionsPerWeek == nil || profile.sessionsPerWeek == 0 {
            profile.sessionsPerWeek = 3
        }
        if profile.sessionDuration == nil || profile.sessionDuration == 0 {
            profile.sessionDuration = 60
        }
        if profile.trainingLocation == nil {
            profile.trainingLocation = .mixed
        }
        if profile.availableEquipment == nil {
            profile.availableEquipment = []
        }
    }

    private static func resolvedAcquisitionCode(from viewModel: OnboardingViewModel) -> String? {
        if let code = viewModel.referralCode?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty {
            return code
        }
        return ProcessReferralAttribution.pendingCode ?? ProcessAffiliateAttribution.pendingCode
    }
}
