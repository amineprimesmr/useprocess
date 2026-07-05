import Foundation

extension WelcomePlanQuestionBank {

    /// Réponses équilibrées pour générer un protocole complet en un tap (circuits inclus).
    static func prefillAnswers(profile: UnifiedUserProfile?) -> [String: WelcomePlanAnswer] {
        prefillAnswersFromOnboarding(profile: profile)
    }

    /// Mappe les réponses onboarding vers un protocole d'aperçu (sans valider le questionnaire).
    static func prefillAnswersFromOnboarding(profile: UnifiedUserProfile?) -> [String: WelcomePlanAnswer] {
        var answers: [String: WelcomePlanAnswer] = [:]

        func put(_ id: String, _ answer: WelcomePlanAnswer) {
            answers[id] = answer
        }

        put("welcome_ready", WelcomePlanAnswer(choiceIds: ["start"]))
        put("face_concerns", WelcomePlanAnswer(choiceIds: faceConcerns(from: profile)))
        put("body_fat_feel", WelcomePlanAnswer(choiceIds: ["normal"]))
        put("sleep_quality", WelcomePlanAnswer(choiceIds: [profile?.sleepProfile?.sleepQuality?.rawValue ?? OnboardingSleepQuality.good.rawValue]))
        put("bedtime", WelcomePlanAnswer(timeValue: profile?.sleepProfile?.bedtimePreference ?? "23:00"))
        put("wake_time", WelcomePlanAnswer(timeValue: profile?.sleepProfile?.wakeTimePreference ?? "08:30"))
        put("screen_before_bed", WelcomePlanAnswer(choiceIds: ["no"]))
        put("morning_sunlight", WelcomePlanAnswer(choiceIds: ["sometimes"]))
        put("caffeine_afternoon", WelcomePlanAnswer(choiceIds: ["no"]))
        put("alcohol_frequency", WelcomePlanAnswer(choiceIds: ["rare"]))
        put("fatigue_frequency", WelcomePlanAnswer(choiceIds: [profile?.sleepProfile?.fatigueFrequency?.rawValue ?? FatigueFrequency.sometimes.rawValue]))
        put("nutrition_quality", WelcomePlanAnswer(choiceIds: [profile?.nutritionProfile?.nutritionQuality?.rawValue ?? NutritionQuality.average.rawValue]))
        put("processed_food", WelcomePlanAnswer(choiceIds: ["few_week"]))
        put("animal_protein", WelcomePlanAnswer(choiceIds: ["eggs", "fish", "poultry"]))
        put("hydration_level", WelcomePlanAnswer(choiceIds: [profile?.nutritionProfile?.hydrationLevel?.rawValue ?? HydrationLevel.average.rawValue]))
        put("current_meals_count", WelcomePlanAnswer(choiceIds: ["3"]))
        put("target_meals_count", WelcomePlanAnswer(choiceIds: ["3"]))
        put("desk_job", WelcomePlanAnswer(choiceIds: ["yes"]))
        put("forward_head", WelcomePlanAnswer(choiceIds: ["yes"]))
        put("mouth_breathing", WelcomePlanAnswer(choiceIds: ["no"]))
        put("training_experience", WelcomePlanAnswer(choiceIds: [profile?.experienceLevel?.rawValue ?? ExperienceLevel.intermediaire.rawValue]))
        put("sessions_per_week", WelcomePlanAnswer(choiceIds: [sessionsPerWeekChoice(from: profile)]))
        put("training_location", WelcomePlanAnswer(choiceIds: [profile?.trainingLocation?.rawValue ?? TrainingLocation.home.rawValue]))
        put("injuries", WelcomePlanAnswer(choiceIds: ["none"]))
        put("consistency_history", WelcomePlanAnswer(choiceIds: ["months"]))
        put("biggest_barrier", WelcomePlanAnswer(choiceIds: ["time"]))
        put("commit_plan", WelcomePlanAnswer(choiceIds: ["yes"]))
        put("optional_face_scan", WelcomePlanAnswer(choiceIds: [hasOnboardingFaceScan ? "later" : "later"]))

        let active = activeQuestions(answers: answers)
        return active.reduce(into: [:]) { partial, question in
            if let answer = answers[question.id] {
                partial[question.id] = answer
            }
        }
    }

    private static var hasOnboardingFaceScan: Bool {
        OnboardingFaceMarkersStore.load() != nil
    }

    private static func faceConcerns(from profile: UnifiedUserProfile?) -> [String] {
        var concerns = Set<String>()

        switch profile?.onboardingPrimaryFocus {
        case .face:
            concerns.formUnion(["puffiness", "dull_skin"])
        case .weight:
            concerns.insert("double_chin")
        case .energy:
            concerns.insert("dark_circles")
        default:
            break
        }

        for driver in profile?.onboardingDebloatDrivers ?? [] {
            switch driver {
            case .sleep:
                concerns.insert("dark_circles")
            case .nutrition:
                concerns.insert("puffiness")
            case .stress:
                concerns.insert("dull_skin")
            case .sedentary:
                concerns.insert("weak_jaw")
            case .unknown:
                break
            }
        }

        if concerns.isEmpty {
            concerns.formUnion(["puffiness", "weak_jaw", "dull_skin"])
        }
        return Array(concerns)
    }

    private static func sessionsPerWeekChoice(from profile: UnifiedUserProfile?) -> String {
        guard let sessions = profile?.sessionsPerWeek, sessions > 0 else { return "3" }
        return String(min(max(sessions, 1), 6))
    }
}
