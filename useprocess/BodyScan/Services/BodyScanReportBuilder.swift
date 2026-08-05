import Foundation

enum BodyScanReportBuilder {

    static func build(
        metrics: PostureMetrics,
        asymmetries: [String],
        priorities: [MusclePriority],
        face: FaceWellnessMarkers?,
        lifestyleInsights: [String],
        confidence: Double
    ) -> String {
        var sections: [String] = []

        sections.append(AppCopy.tSync("## Synthèse posture", en: "## Posture summary"))
        sections.append(AppCopy.tSync(
            "Score global : **\(metrics.overallScore)/100** (confiance \(Int(confidence * 100)) %)",
            en: "Overall score: **\(metrics.overallScore)/100** (confidence \(Int(confidence * 100))%)"
        ))
        sections.append("")
        sections.append(AppCopy.tSync("Détail :", en: "Detail:"))
        sections.append(AppCopy.tSync(
            "- Épaules : \(metrics.shoulderAlignmentScore)/100",
            en: "- Shoulders: \(metrics.shoulderAlignmentScore)/100"
        ))
        sections.append(AppCopy.tSync(
            "- Bassin : \(metrics.hipAlignmentScore)/100",
            en: "- Hips: \(metrics.hipAlignmentScore)/100"
        ))
        sections.append(AppCopy.tSync(
            "- Colonne / tête : \(metrics.spineAlignmentScore)/100",
            en: "- Spine / head: \(metrics.spineAlignmentScore)/100"
        ))
        sections.append(AppCopy.tSync(
            "- Genoux : \(metrics.kneeAlignmentScore)/100",
            en: "- Knees: \(metrics.kneeAlignmentScore)/100"
        ))
        sections.append(AppCopy.tSync(
            "- Symétrie : \(metrics.leftRightSymmetryScore)/100",
            en: "- Symmetry: \(metrics.leftRightSymmetryScore)/100"
        ))

        if !asymmetries.isEmpty {
            sections.append("")
            sections.append(AppCopy.tSync("## Asymétries détectées", en: "## Detected asymmetries"))
            asymmetries.forEach { sections.append("- \($0)") }
        } else {
            sections.append("")
            sections.append(AppCopy.tSync("## Asymétries", en: "## Asymmetries"))
            sections.append(AppCopy.tSync(
                "Aucune asymétrie majeure détectée sur ce scan.",
                en: "No major asymmetry detected on this scan."
            ))
        }

        sections.append("")
        sections.append(AppCopy.tSync("## Priorités musculaires", en: "## Muscle priorities"))
        priorities.forEach { item in
            sections.append("\(item.priority). **\(item.name)** — \(item.reason)")
        }

        if let face {
            sections.append("")
            sections.append(AppCopy.tSync("## Marqueurs visage (bien-être)", en: "## Face markers (wellness)"))
            sections.append(AppCopy.tSync(
                "- Clarté perçue : \(face.skinClarityScore)/100",
                en: "- Perceived clarity: \(face.skinClarityScore)/100"
            ))
            sections.append(AppCopy.tSync(
                "- Fatigue perçue : \(face.underEyeFatigueScore)/100",
                en: "- Perceived fatigue: \(face.underEyeFatigueScore)/100"
            ))
            sections.append(AppCopy.tSync(
                "- Rétention / gonflement : \(face.puffinessScore)/100",
                en: "- Retention / puffiness: \(face.puffinessScore)/100"
            ))
            sections.append(AppCopy.tSync(
                "- Tension mâchoire : \(face.jawTensionScore)/100",
                en: "- Jaw tension: \(face.jawTensionScore)/100"
            ))
            if !face.notes.isEmpty {
                face.notes.forEach { sections.append("- \($0)") }
            }
        }

        if !lifestyleInsights.isEmpty {
            sections.append("")
            sections.append(AppCopy.tSync("## Corrélations lifestyle", en: "## Lifestyle correlations"))
            lifestyleInsights.forEach { sections.append("- \($0)") }
        }

        sections.append("")
        sections.append(AppCopy.tSync("## Recommandations", en: "## Recommendations"))
        sections.append(recommendations(for: metrics, priorities: priorities))

        return sections.joined(separator: "\n")
    }

    private static func recommendations(for metrics: PostureMetrics, priorities: [MusclePriority]) -> String {
        var tips: [String] = []

        if metrics.spineAlignmentScore < 72 {
            tips.append(AppCopy.tSync(
                "Renforcement chaîne postérieure + face pulls 3×/sem.",
                en: "Strengthen posterior chain + face pulls 3×/wk."
            ))
        }
        if metrics.hipAlignmentScore < 70 {
            tips.append(AppCopy.tSync(
                "Renforcement fessiers (pont, clamshell) 3×/semaine.",
                en: "Glute strengthening (bridge, clamshell) 3×/week."
            ))
        }
        if metrics.kneeAlignmentScore < 70 {
            tips.append(AppCopy.tSync(
                "Travail d'alignement : squat au mur, montées de genoux lentes.",
                en: "Alignment work: wall squat, slow knee raises."
            ))
        }
        if metrics.leftRightSymmetryScore < 68 {
            tips.append(AppCopy.tSync(
                "Travail unilatéral (lunges, row à un bras) pour rééquilibrer.",
                en: "Unilateral work (lunges, single-arm row) to rebalance."
            ))
        }
        if tips.isEmpty {
            tips.append(AppCopy.tSync(
                "Scan de référence enregistré — refais un scan hebdomadaire pour suivre ta progression.",
                en: "Baseline scan saved — rescan weekly to track progress."
            ))
        }
        if let top = priorities.first {
            tips.append(AppCopy.tSync(
                "Focus prioritaire cette semaine : **\(top.name)**.",
                en: "Priority focus this week: **\(top.name)**."
            ))
        }

        return tips.map { "- \($0)" }.joined(separator: "\n")
    }

    static func lifestyleInsights(
        face: FaceWellnessMarkers?,
        profile: UnifiedUserProfile?
    ) -> [String] {
        var insights: [String] = []

        if let face {
            if face.underEyeFatigueScore > 62 {
                insights.append(AppCopy.tSync(
                    "Fatigue perçue au visage — vérifie ton sommeil (7–9 h) et ta hydratation.",
                    en: "Perceived face fatigue — check sleep (7–9 h) and hydration."
                ))
            }
            if face.puffinessScore > 60 {
                insights.append(AppCopy.tSync(
                    "Gonflement léger — sel, alcool, cycle hormonal ou manque de sommeil possibles.",
                    en: "Mild puffiness — salt, alcohol, hormonal cycle, or poor sleep possible."
                ))
            }
            if face.jawTensionScore > 60 {
                insights.append(AppCopy.tSync(
                    "Tension mandibulaire — respiration, stress chronique ou bruxisme nocturne possibles.",
                    en: "Jaw tension — breathing, chronic stress, or night bruxism possible."
                ))
            }
        }

        if let profile {
            if let hours = profile.sleepProfile?.averageSleepHours, hours > 0, hours < 6.5 {
                insights.append(AppCopy.tSync(
                    "Sommeil court déclaré — impact fréquent sur posture et récupération.",
                    en: "Short sleep reported — frequent impact on posture and recovery."
                ))
            }
            if let quality = profile.nutritionProfile?.nutritionQuality,
               quality == .poor || quality == .average || quality == .veryPoor {
                insights.append(AppCopy.tSync(
                    "Qualité alimentaire moyenne — inflammation et rétention d'eau possibles.",
                    en: "Average diet quality — inflammation and water retention possible."
                ))
            }
        }

        if insights.isEmpty {
            insights.append(AppCopy.tSync(
                "Continue à croiser scan, sommeil et nutrition pour affiner ton tableau de bord.",
                en: "Keep correlating scan, sleep, and nutrition to refine your dashboard."
            ))
        }

        return insights
    }
}
