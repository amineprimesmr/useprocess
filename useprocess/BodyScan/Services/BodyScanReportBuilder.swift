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

        sections.append("## Synthèse posture")
        sections.append("Score global : **\(metrics.overallScore)/100** (confiance \(Int(confidence * 100)) %)")
        sections.append("")
        sections.append("Détail :")
        sections.append("- Épaules : \(metrics.shoulderAlignmentScore)/100")
        sections.append("- Bassin : \(metrics.hipAlignmentScore)/100")
        sections.append("- Colonne / tête : \(metrics.spineAlignmentScore)/100")
        sections.append("- Genoux : \(metrics.kneeAlignmentScore)/100")
        sections.append("- Symétrie : \(metrics.leftRightSymmetryScore)/100")

        if !asymmetries.isEmpty {
            sections.append("")
            sections.append("## Asymétries détectées")
            asymmetries.forEach { sections.append("- \($0)") }
        } else {
            sections.append("")
            sections.append("## Asymétries")
            sections.append("Aucune asymétrie majeure détectée sur ce scan.")
        }

        sections.append("")
        sections.append("## Priorités musculaires")
        priorities.forEach { item in
            sections.append("\(item.priority). **\(item.name)** — \(item.reason)")
        }

        if let face {
            sections.append("")
            sections.append("## Marqueurs visage (bien-être)")
            sections.append("- Clarté perçue : \(face.skinClarityScore)/100")
            sections.append("- Fatigue perçue : \(face.underEyeFatigueScore)/100")
            sections.append("- Rétention / gonflement : \(face.puffinessScore)/100")
            sections.append("- Tension mâchoire : \(face.jawTensionScore)/100")
            if !face.notes.isEmpty {
                face.notes.forEach { sections.append("- \($0)") }
            }
        }

        if !lifestyleInsights.isEmpty {
            sections.append("")
            sections.append("## Corrélations lifestyle")
            lifestyleInsights.forEach { sections.append("- \($0)") }
        }

        sections.append("")
        sections.append("## Recommandations")
        sections.append(recommendations(for: metrics, priorities: priorities))

        return sections.joined(separator: "\n")
    }

    private static func recommendations(for metrics: PostureMetrics, priorities: [MusclePriority]) -> String {
        var tips: [String] = []

        if metrics.spineAlignmentScore < 72 {
            tips.append("Renforcement chaîne postérieure + face pulls 3×/sem.")
        }
        if metrics.hipAlignmentScore < 70 {
            tips.append("Renforcement fessiers (pont, clamshell) 3×/semaine.")
        }
        if metrics.kneeAlignmentScore < 70 {
            tips.append("Travail d'alignement : squat au mur, montées de genoux lentes.")
        }
        if metrics.leftRightSymmetryScore < 68 {
            tips.append("Travail unilatéral (lunges, row à un bras) pour rééquilibrer.")
        }
        if tips.isEmpty {
            tips.append("Scan de référence enregistré — refais un scan hebdomadaire pour suivre ta progression.")
        }
        if let top = priorities.first {
            tips.append("Focus prioritaire cette semaine : **\(top.name)**.")
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
                insights.append("Fatigue perçue au visage — vérifie ton sommeil (7–9 h) et ta hydratation.")
            }
            if face.puffinessScore > 60 {
                insights.append("Gonflement léger — sel, alcool, cycle hormonal ou manque de sommeil possibles.")
            }
            if face.jawTensionScore > 60 {
                insights.append("Tension mandibulaire — respiration, stress chronique ou bruxisme nocturne possibles.")
            }
        }

        if let profile {
            if let hours = profile.sleepProfile?.averageSleepHours, hours > 0, hours < 6.5 {
                insights.append("Sommeil court déclaré — impact fréquent sur posture et récupération.")
            }
            if let quality = profile.nutritionProfile?.nutritionQuality,
               quality == .poor || quality == .average || quality == .veryPoor {
                insights.append("Qualité alimentaire moyenne — inflammation et rétention d'eau possibles.")
            }
        }

        if insights.isEmpty {
            insights.append("Continue à croiser scan, sommeil et nutrition pour affiner ton tableau de bord.")
        }

        return insights
    }
}
