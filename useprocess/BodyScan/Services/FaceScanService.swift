import Foundation
import UIKit

@MainActor
enum FaceScanService {

    static func recordScan(
        payload: FaceScanCapturePayload,
        markers: FaceWellnessMarkers,
        profile: UnifiedUserProfile?
    ) async -> FaceScanResult {
        let userId = profile?.userId ?? UserScopedStorage.currentUserId() ?? "local-user"
        let scanId = payload.scanId
        let health = HealthManager.shared

        var snapshotFilename: String?
        if let snapshot = payload.snapshot {
            snapshotFilename = FaceScanImageStore.save(image: snapshot, scanId: scanId)
        }

        let absoluteDayScore = FaceWellnessScore.dayScore(from: markers)
        let relativeAssessment = FaceWellnessScore.relativeAssessment(
            current: markers,
            history: FaceScanHistoryStore.shared.history,
            yawCoverage: payload.yawCoverage
        )
        let sleepHours = health.todaySnapshot.sleep.sleepDuration > 0
            ? health.todaySnapshot.sleep.sleepDuration
            : nil
        let hrv = health.todaySnapshot.vitals.hrv > 0
            ? health.todaySnapshot.vitals.hrv
            : nil

        let scanSource: FaceScanSource = AppSession.shared.hasCompletedOnboarding ? .daily : .onboarding

        var result = FaceScanResult(
            id: scanId,
            userId: userId,
            markers: markers,
            snapshotFilename: snapshotFilename,
            videoFilename: payload.videoFilename,
            source: scanSource,
            sleepHoursAtScan: sleepHours,
            hrvAtScan: hrv,
            faceDayScore: absoluteDayScore,
            relativeFaceDayScore: relativeAssessment.score,
            scanConfidence: relativeAssessment.confidence,
            baselineSampleCount: relativeAssessment.baselineSampleCount,
            relativeSignals: relativeAssessment.signals
        )
        result = FaceScanImageStore.reconcileMediaMetadata(for: result)

        OnboardingFaceMarkersStore.save(
            markers: markers,
            mesh: payload.mesh,
            scanId: scanId,
            snapshotFilename: result.snapshotFilename,
            videoFilename: result.videoFilename,
            capturedAt: result.createdAt
        )
        FaceScanHistoryStore.shared.push(result)

        if var plan = WelcomePlanStore.shared.plan {
            PlanRecalibrationService.applyBaselineScan(to: &plan, markers: markers)
            _ = PlanRecalibrationService.recalibrate(plan: &plan, latestScan: result)
            WelcomePlanStore.shared.savePlan(plan, structureChanged: true)
        }

        enqueuePostScanEnhancements(for: result, profile: profile)

        return result
    }

    /// Travail réseau / IA — ne bloque pas l’écran d’analyse ni les résultats WHOOP.
    private static func enqueuePostScanEnhancements(
        for result: FaceScanResult,
        profile: UnifiedUserProfile?
    ) {
        Task { @MainActor in
            var enhanced = result

            if ClaudeConfiguration.isConfigured,
               ProcessPrivacyConsentStore.shared.canSendFacePhotoToAI,
               let aiResult = await CoachEngine.analyzeFaceScan(
                   result: enhanced,
                   profile: profile,
                   history: FaceScanHistoryStore.shared.recentResults(limit: 14)
               ) {
                enhanced = aiResult
                FaceScanHistoryStore.shared.update(enhanced)
            }

            await HealthManager.shared.performFullSync()
            await FaceScanReminderService.scheduleNextReminder(after: enhanced.createdAt)
            FaceScanCoachInsightService.pregenerate(for: enhanced, profile: profile)
        }
    }
}
