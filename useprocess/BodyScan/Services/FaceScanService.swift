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

        let result = FaceScanResult(
            id: scanId,
            userId: userId,
            markers: markers,
            snapshotFilename: nil,
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

        enqueueScanPersistence(
            result: result,
            payload: payload,
            markers: markers
        )

        return result
    }

    private static func enqueueScanPersistence(
        result: FaceScanResult,
        payload: FaceScanCapturePayload,
        markers: FaceWellnessMarkers
    ) {
        Task.detached(priority: .utility) {
            let snapshotFilename = payload.snapshot.flatMap {
                FaceScanImageStore.save(image: $0, scanId: payload.scanId)
            }

            await MainActor.run {
                var persisted = result
                if let snapshotFilename {
                    persisted.snapshotFilename = snapshotFilename
                }

                OnboardingFaceMarkersStore.save(
                    markers: markers,
                    mesh: payload.mesh,
                    scanId: payload.scanId,
                    snapshotFilename: persisted.snapshotFilename,
                    videoFilename: persisted.videoFilename,
                    capturedAt: persisted.createdAt
                )
                FaceScanHistoryStore.shared.push(persisted)
                ProcessDebloatTrajectoryStore.shared.recordScan(persisted)

                enqueuePlanRecalibration(for: persisted, markers: markers)
                enqueuePostScanEnhancements(
                    for: persisted,
                    profile: UnifiedProfileService.shared.currentProfile
                )
            }
        }
    }

    private static func enqueuePlanRecalibration(for result: FaceScanResult, markers: FaceWellnessMarkers) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            if var plan = WelcomePlanStore.shared.plan {
                PlanRecalibrationService.applyBaselineScan(to: &plan, markers: markers)
                _ = PlanRecalibrationService.recalibrate(plan: &plan, latestScan: result)
                WelcomePlanStore.shared.savePlan(plan, structureChanged: true)
                ProcessPlanProgressStore.shared.evaluateAfterScan(plan: plan, latestScan: result)
            }
        }
    }

    /// Travail réseau / IA — ne bloque pas l’écran d’analyse ni les résultats WHOOP.
    private static func enqueuePostScanEnhancements(
        for result: FaceScanResult,
        profile: UnifiedUserProfile?
    ) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
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
            FaceScanReminderService.cancelReminder()
            FaceScanCoachInsightService.pregenerate(for: enhanced, profile: profile)
        }
    }
}
