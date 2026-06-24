import Foundation

/// Recalibration du plan selon scans visage et progrès.
enum PlanRecalibrationService {

    @MainActor
    static func recalibrateIfNeeded(plan: inout FaceOriginPlan) -> [String] {
        guard let latest = FaceScanHistoryStore.shared.latestResult else { return [] }
        return recalibrate(plan: &plan, latestScan: latest)
    }

    @MainActor
    static func recalibrate(plan: inout FaceOriginPlan, latestScan: FaceScanResult) -> [String] {
        var messages: [String] = []
        let markers = latestScan.markers

        guard let criteria = plan.successCriteria.nilIfEmpty else { return [] }

        for criterion in criteria {
            guard let key = criterion.metricKey,
                  let baseline = criterion.baselineValue,
                  let target = criterion.targetValue else { continue }

            let current: Int?
            switch key {
            case "puffinessScore": current = markers.puffinessScore
            case "skinClarityScore": current = markers.skinClarityScore
            case "underEyeFatigueScore": current = markers.underEyeFatigueScore
            default: current = nil
            }

            guard let current else { continue }

            if current <= target {
                messages.append("Objectif atteint : \(criterion.label)")
            } else if current < baseline {
                let delta = baseline - current
                messages.append("\(criterion.label) : −\(delta) pts vs baseline")
            }
        }

        if checkEarlyCompletion(plan: plan, latestScan: latestScan) {
            messages.append("Critères principaux atteints — tu peux passer en maintenance")
            plan.mindsetNotes.insert("Protocole express validé — maintiens 80 % des bases.", at: 0)
            plan.lastUpdated = Date()
        }

        plan.successCriteria = criteria
        return messages
    }

    static func checkEarlyCompletion(plan: FaceOriginPlan, latestScan: FaceScanResult) -> Bool {
        guard let snapshot = plan.assessmentSnapshot else { return false }
        guard snapshot.archetype == .habitReset || snapshot.archetype == .maintenancePolish else { return false }

        let markers = latestScan.markers
        var met = 0
        var checked = 0

        for criterion in plan.successCriteria {
            guard let key = criterion.metricKey,
                  let target = criterion.targetValue,
                  let baseline = criterion.baselineValue else { continue }
            checked += 1
            let current: Int
            switch key {
            case "puffinessScore": current = markers.puffinessScore
            case "skinClarityScore": current = markers.skinClarityScore
            case "underEyeFatigueScore": current = markers.underEyeFatigueScore
            default: continue
            }
            if current <= target || current <= baseline - 10 {
                met += 1
            }
        }

        return checked > 0 && met >= checked
    }

    @MainActor
    static func applyBaselineScan(to plan: inout FaceOriginPlan, markers: FaceWellnessMarkers) {
        guard plan.successCriteria.contains(where: { $0.metricKey == "baselineScan" }) else { return }

        plan.successCriteria = plan.successCriteria.map { criterion in
            guard criterion.metricKey == "baselineScan" else { return criterion }
            return OriginSuccessCriterion(
                id: criterion.id,
                label: "Gonflement visage",
                detail: "Réduire puffiness vs baseline (\(markers.puffinessScore))",
                metricKey: "puffinessScore",
                targetValue: max(20, markers.puffinessScore - 15),
                baselineValue: markers.puffinessScore
            )
        }

        if !plan.successCriteria.contains(where: { $0.metricKey == "skinClarityScore" }) {
            plan.successCriteria.append(
                OriginSuccessCriterion(
                    label: "Teint / peau",
                    detail: "Améliorer skinClarity vs baseline",
                    metricKey: "skinClarityScore",
                    targetValue: max(15, markers.skinClarityScore - 12),
                    baselineValue: markers.skinClarityScore
                )
            )
        }

        plan.lastUpdated = Date()
    }
}

private extension Array {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
