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

        let sleepHours = health.todaySnapshot.sleep.sleepDuration > 0
            ? health.todaySnapshot.sleep.sleepDuration
            : nil
        let hrv = health.todaySnapshot.vitals.hrv > 0
            ? health.todaySnapshot.vitals.hrv
            : nil

        let scanSource: FaceScanSource = AppSession.shared.hasCompletedOnboarding ? .daily : .onboarding
        // Studio créateur : on garde l’analyse réelle ici — le slider ajuste sur l’écran résultats.
        let resolvedMarkers: FaceWellnessMarkers
        if scanSource == .onboarding, !ProcessCreatorModeStore.shared.isUnlocked {
            resolvedMarkers = OnboardingFaceScanMarkerCalibration.calibrate(
                markers,
                sleepHours: sleepHours,
                hrv: hrv
            )
        } else {
            resolvedMarkers = markers
        }

        let absoluteDayScore = FaceWellnessScore.dayScore(from: resolvedMarkers)
        let relativeAssessment = FaceWellnessScore.relativeAssessment(
            current: resolvedMarkers,
            history: FaceScanHistoryStore.shared.history,
            yawCoverage: payload.yawCoverage
        )

        // Snapshot disque avant retour — la carte accueil doit avoir la photo dès Continuer.
        let snapshotFilename = await Task.detached(priority: .utility) {
            payload.snapshot.flatMap {
                FaceScanImageStore.save(image: $0, scanId: payload.scanId)
            }
        }.value

        let result = FaceScanResult(
            id: scanId,
            userId: userId,
            markers: resolvedMarkers,
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

        OnboardingFaceMarkersStore.save(
            markers: resolvedMarkers,
            mesh: payload.mesh,
            scanId: payload.scanId,
            snapshotFilename: result.snapshotFilename,
            videoFilename: result.videoFilename,
            capturedAt: result.createdAt
        )
        FaceScanHistoryStore.shared.push(result)
        ProcessDebloatTrajectoryStore.shared.recordScan(result)

        enqueuePlanRecalibration(for: result, markers: resolvedMarkers)
        enqueuePostScanEnhancements(
            for: result,
            profile: UnifiedProfileService.shared.currentProfile
        )

        return result
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
                // Ne pas écraser un rendu studio déjà validé (slider / cadrage).
                if let current = FaceScanHistoryStore.shared.history.first(where: { $0.id == enhanced.id }) {
                    enhanced = FaceScanResult(
                        id: enhanced.id,
                        userId: enhanced.userId,
                        createdAt: enhanced.createdAt,
                        markers: current.markers,
                        snapshotFilename: current.snapshotFilename ?? enhanced.snapshotFilename,
                        videoFilename: current.videoFilename ?? enhanced.videoFilename,
                        claudeAnalysis: enhanced.claudeAnalysis,
                        aiEnhanced: enhanced.aiEnhanced,
                        coachInsightMessage: enhanced.coachInsightMessage ?? current.coachInsightMessage,
                        coachInsightModel: enhanced.coachInsightModel ?? current.coachInsightModel,
                        source: enhanced.source,
                        sleepHoursAtScan: current.sleepHoursAtScan,
                        hrvAtScan: current.hrvAtScan,
                        faceDayScore: current.faceDayScore,
                        relativeFaceDayScore: current.relativeFaceDayScore,
                        scanConfidence: enhanced.scanConfidence ?? current.scanConfidence,
                        baselineSampleCount: enhanced.baselineSampleCount ?? current.baselineSampleCount,
                        relativeSignals: enhanced.relativeSignals ?? current.relativeSignals,
                        studioFraming: current.studioFraming
                    )
                }
                FaceScanHistoryStore.shared.update(enhanced)
            }

            await HealthManager.shared.performFullSync()
            FaceScanReminderService.cancelReminder()
            FaceScanCoachInsightService.pregenerate(for: enhanced, profile: profile)
        }
    }
}
