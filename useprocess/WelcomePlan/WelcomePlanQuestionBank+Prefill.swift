import Foundation

extension WelcomePlanQuestionBank {

    /// Réponses équilibrées pour générer un protocole complet en un tap (circuits inclus).
    static func prefillAnswers(profile: UnifiedUserProfile?) -> [String: WelcomePlanAnswer] {
        var answers: [String: WelcomePlanAnswer] = [:]

        func put(_ id: String, _ answer: WelcomePlanAnswer) {
            answers[id] = answer
        }

        put("welcome_ready", WelcomePlanAnswer(choiceIds: ["start"]))
        put("face_concerns", WelcomePlanAnswer(choiceIds: ["puffiness", "weak_jaw", "dull_skin"]))
        put("body_fat_feel", WelcomePlanAnswer(choiceIds: ["normal"]))
        put("sleep_quality", WelcomePlanAnswer(choiceIds: [OnboardingSleepQuality.good.rawValue]))
        put("bedtime", WelcomePlanAnswer(timeValue: "23:00"))
        put("wake_time", WelcomePlanAnswer(timeValue: "08:30"))
        put("screen_before_bed", WelcomePlanAnswer(choiceIds: ["no"]))
        put("morning_sunlight", WelcomePlanAnswer(choiceIds: ["sometimes"]))
        put("caffeine_afternoon", WelcomePlanAnswer(choiceIds: ["no"]))
        put("alcohol_frequency", WelcomePlanAnswer(choiceIds: ["rare"]))
        put("fatigue_frequency", WelcomePlanAnswer(choiceIds: [FatigueFrequency.sometimes.rawValue]))
        put("nutrition_quality", WelcomePlanAnswer(choiceIds: [NutritionQuality.average.rawValue]))
        put("processed_food", WelcomePlanAnswer(choiceIds: ["few_week"]))
        put("animal_protein", WelcomePlanAnswer(choiceIds: ["eggs", "fish", "poultry"]))
        put("hydration_level", WelcomePlanAnswer(choiceIds: [HydrationLevel.average.rawValue]))
        put("current_meals_count", WelcomePlanAnswer(choiceIds: ["3"]))
        put("target_meals_count", WelcomePlanAnswer(choiceIds: ["3"]))
        put("desk_job", WelcomePlanAnswer(choiceIds: ["yes"]))
        put("forward_head", WelcomePlanAnswer(choiceIds: ["yes"]))
        put("mouth_breathing", WelcomePlanAnswer(choiceIds: ["no"]))
        put("training_experience", WelcomePlanAnswer(choiceIds: [ExperienceLevel.intermediaire.rawValue]))
        put("sessions_per_week", WelcomePlanAnswer(choiceIds: ["3"]))
        put("training_location", WelcomePlanAnswer(choiceIds: [TrainingLocation.home.rawValue]))
        put("injuries", WelcomePlanAnswer(choiceIds: ["none"]))
        put("consistency_history", WelcomePlanAnswer(choiceIds: ["months"]))
        put("biggest_barrier", WelcomePlanAnswer(choiceIds: ["time"]))
        put("commit_plan", WelcomePlanAnswer(choiceIds: ["yes"]))
        put("optional_face_scan", WelcomePlanAnswer(choiceIds: ["later"]))

        if let weight = profile?.weight, weight > 0 {
            // Profil déjà renseigné en onboarding — rien à injecter de plus pour l'instant.
            _ = weight
        }

        let active = activeQuestions(answers: answers)
        return active.reduce(into: [:]) { partial, question in
            if let answer = answers[question.id] {
                partial[question.id] = answer
            }
        }
    }
}
