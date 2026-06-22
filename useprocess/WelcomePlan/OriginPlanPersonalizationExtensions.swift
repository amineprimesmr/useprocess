import Foundation

extension FaceOriginPlan {
    var resolvedDailyTargets: OriginPersonalizedDailyTargets {
        personalizedTargets ?? .default
    }

    /// Regénère le contenu du plan en conservant id, userId, createdAt et la progression.
    func mergingUpgrade(
        from fresh: FaceOriginPlan,
        progress: OriginPlanProgress,
        calendarStartedAt: Date?
    ) -> FaceOriginPlan {
        var calendar = fresh.calendar
        calendar.startedAt = calendarStartedAt ?? calendar.startedAt
        return FaceOriginPlan(
            id: id,
            userId: userId,
            createdAt: createdAt,
            lastUpdated: Date(),
            headline: fresh.headline,
            executiveSummary: fresh.executiveSummary,
            philosophyNote: fresh.philosophyNote,
            primaryFaceGoal: fresh.primaryFaceGoal,
            pillarScores: fresh.pillarScores,
            dailyHabits: fresh.dailyHabits,
            weeklyRhythm: fresh.weeklyRhythm,
            phaseRoadmap: fresh.phaseRoadmap,
            nutritionProtocol: fresh.nutritionProtocol,
            sleepProtocol: fresh.sleepProtocol,
            trainingProtocol: fresh.trainingProtocol,
            postureProtocol: fresh.postureProtocol,
            faceProtocol: fresh.faceProtocol,
            mindsetNotes: fresh.mindsetNotes,
            totalWeeks: fresh.totalWeeks,
            durationMinWeeks: fresh.durationMinWeeks,
            durationMaxWeeks: fresh.durationMaxWeeks,
            calendar: calendar,
            progress: progress,
            lifestyleExtras: fresh.lifestyleExtras,
            assessmentSnapshot: fresh.assessmentSnapshot,
            successCriteria: fresh.successCriteria,
            personalizedTargets: fresh.personalizedTargets
        )
    }
}

extension OriginPlanPresenter {
    static func assessmentSummary(for plan: FaceOriginPlan) -> String? {
        guard let snapshot = plan.assessmentSnapshot else { return nil }
        var parts: [String] = [snapshot.archetype.label]
        if let bf = snapshot.estimatedBodyFatPercent {
            parts.append(String(format: "~%.0f %% MG", bf))
        }
        if snapshot.bodyFatGap >= 2 {
            parts.append("écart cible \(Int(snapshot.bodyFatGap.rounded())) pts")
        }
        return parts.joined(separator: " · ")
    }
}
