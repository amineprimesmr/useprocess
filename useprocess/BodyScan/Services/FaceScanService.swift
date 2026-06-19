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

        let dayScore = FaceWellnessScore.dayScore(from: markers)
        let sleepHours = health.todaySnapshot.sleep.sleepDuration > 0
            ? health.todaySnapshot.sleep.sleepDuration
            : nil
        let hrv = health.todaySnapshot.vitals.hrv > 0
            ? health.todaySnapshot.vitals.hrv
            : nil

        var result = FaceScanResult(
            id: scanId,
            userId: userId,
            markers: markers,
            snapshotFilename: snapshotFilename,
            videoFilename: payload.videoFilename,
            source: .daily,
            sleepHoursAtScan: sleepHours,
            hrvAtScan: hrv,
            faceDayScore: dayScore
        )

        OnboardingFaceMarkersStore.save(markers: markers, mesh: payload.mesh)
        FaceScanHistoryStore.shared.push(result)

        if ClaudeConfiguration.isConfigured,
           ProcessPrivacyConsentStore.shared.canSendFacePhotoToAI {
            if let enhanced = await CoachEngine.analyzeFaceScan(
                result: result,
                profile: profile,
                history: FaceScanHistoryStore.shared.recentResults(limit: 14)
            ) {
                result = enhanced
                FaceScanHistoryStore.shared.update(result)
            }
        }

        await health.performFullSync()
        await FaceScanReminderService.scheduleNextReminder(after: result.createdAt)

        return result
    }
}
