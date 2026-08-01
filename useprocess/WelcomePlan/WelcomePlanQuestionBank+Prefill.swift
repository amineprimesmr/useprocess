import Foundation

extension WelcomePlanQuestionBank {

    /// Réponses équilibrées pour générer un protocole complet en un tap (circuits inclus).
    static func prefillAnswers(profile: UnifiedUserProfile?) -> [String: WelcomePlanAnswer] {
        prefillAnswersFromOnboarding(profile: profile)
    }

    /// Valeurs par défaut pour les clés legacy encore lues par le générateur.
    static func prefillAnswersFromOnboarding(profile: UnifiedUserProfile?) -> [String: WelcomePlanAnswer] {
        var answers: [String: WelcomePlanAnswer] = [:]

        func put(_ id: String, _ answer: WelcomePlanAnswer) {
            answers[id] = answer
        }

        put("welcome_ready", WelcomePlanAnswer(choiceIds: ["start"]))
        put("face_concerns", WelcomePlanAnswer(choiceIds: faceConcerns(from: profile)))
        put("body_fat_feel", WelcomePlanAnswer(choiceIds: [bodyFatFeelChoice(from: profile)]))
        put("sleep_quality", WelcomePlanAnswer(choiceIds: [profile?.sleepProfile?.sleepQuality?.rawValue ?? OnboardingSleepQuality.good.rawValue]))
        put("bedtime", WelcomePlanAnswer(timeValue: profile?.sleepProfile?.bedtimePreference ?? "23:00"))
        put("wake_time", WelcomePlanAnswer(timeValue: profile?.sleepProfile?.wakeTimePreference ?? "07:30"))
        put("evening_meal_time", WelcomePlanAnswer(timeValue: "20:00"))
        put("screen_before_bed", WelcomePlanAnswer(choiceIds: ["no"]))
        put("stimulant_habits", WelcomePlanAnswer(choiceIds: ["none"]))
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
        put("mouth_breathing", WelcomePlanAnswer(choiceIds: ["mixed"]))
        put("training_experience", WelcomePlanAnswer(choiceIds: [profile?.experienceLevel?.rawValue ?? ExperienceLevel.intermediaire.rawValue]))
        put("sessions_per_week", WelcomePlanAnswer(choiceIds: [sessionsPerWeekChoice(from: profile)]))
        put("primary_sport", WelcomePlanAnswer(choiceIds: ["weights"]))
        put("training_location", WelcomePlanAnswer(choiceIds: [profile?.trainingLocation?.rawValue ?? TrainingLocation.home.rawValue]))
        put("injuries", WelcomePlanAnswer(choiceIds: ["none"]))
        put("consistency_history", WelcomePlanAnswer(choiceIds: ["months"]))
        put("biggest_barrier", WelcomePlanAnswer(choiceIds: ["time"]))
        put("commit_plan", WelcomePlanAnswer(choiceIds: ["yes"]))
        put("optional_face_scan", WelcomePlanAnswer(choiceIds: ["later"]))

        let active = activeQuestions(answers: answers)
        return active.reduce(into: [:]) { partial, question in
            if let answer = answers[question.id] {
                partial[question.id] = answer
            }
        }
    }

    /// Fusionne les réponses utilisateur avec les défauts legacy pour la génération du plan.
    static func mergedAnswersForGeneration(
        userAnswers: [String: WelcomePlanAnswer],
        profile: UnifiedUserProfile?
    ) -> [String: WelcomePlanAnswer] {
        var merged = prefillAnswersFromOnboarding(profile: profile)

        for (key, value) in userAnswers {
            merged[key] = value
        }

        if let stimulants = userAnswers["stimulant_habits"]?.choiceIds {
            if stimulants.contains("none") {
                merged["alcohol_frequency"] = WelcomePlanAnswer(choiceIds: ["never"])
                merged["caffeine_afternoon"] = WelcomePlanAnswer(choiceIds: ["no"])
            } else {
                merged["alcohol_frequency"] = WelcomePlanAnswer(
                    choiceIds: [stimulants.contains("alcohol") ? "weekly" : "rare"]
                )
                let hasCaffeine = stimulants.contains("coffee") || stimulants.contains("energy")
                merged["caffeine_afternoon"] = WelcomePlanAnswer(choiceIds: [hasCaffeine ? "yes" : "no"])
            }
        }

        if let mouth = userAnswers["mouth_breathing"]?.choiceIds.first {
            switch mouth {
            case "mouth":
                merged["mouth_breathing"] = WelcomePlanAnswer(choiceIds: ["yes"])
            case "nose":
                merged["mouth_breathing"] = WelcomePlanAnswer(choiceIds: ["no"])
            default:
                merged["mouth_breathing"] = WelcomePlanAnswer(choiceIds: ["yes"])
            }
        }

        if let sport = userAnswers["primary_sport"]?.choiceIds.first {
            let location: String
            switch sport {
            case "weights", "cardio":
                location = TrainingLocation.gym.rawValue
            case "running", "team":
                location = TrainingLocation.outdoor.rawValue
            case "swimming":
                location = TrainingLocation.mixed.rawValue
            default:
                location = profile?.trainingLocation?.rawValue ?? TrainingLocation.home.rawValue
            }
            merged["training_location"] = WelcomePlanAnswer(choiceIds: [location])
        }

        if let meals = userAnswers["current_meals_count"]?.choiceIds.first {
            let target = meals == "5plus" ? "3" : meals
            merged["target_meals_count"] = WelcomePlanAnswer(choiceIds: [target])
        }

        merged["welcome_ready"] = WelcomePlanAnswer(choiceIds: ["start"])
        merged["commit_plan"] = WelcomePlanAnswer(choiceIds: ["yes"])
        merged["optional_face_scan"] = WelcomePlanAnswer(choiceIds: ["later"])

        return merged
    }

    private static var hasOnboardingFaceScan: Bool {
        OnboardingFaceMarkersStore.load() != nil
    }

    private static func faceConcerns(from profile: UnifiedUserProfile?) -> [String] {
        var concerns = Set<String>()

        switch profile?.onboardingPrimaryFocus {
        case .face, .weight, .health, .energy:
            if let focus = profile?.onboardingPrimaryFocus {
                concerns.formUnion(focus.faceConcernChoiceIds)
            }
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
        if sessions >= 5 { return "5plus" }
        return String(min(max(sessions, 1), 4))
    }

    private static func bodyFatFeelChoice(from profile: UnifiedUserProfile?) -> String {
        let bmi = OriginUserAssessment.computeBMI(height: profile?.height, weight: profile?.weight)
        return PlanDurationPersonalizer.inferredBodyFatFeel(profile: profile, bmi: bmi) ?? "normal"
    }
}
