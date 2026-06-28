import Foundation

/// Intelligence menton récessif / mâchoire — script #12 (fascias, orthotropics, mentalis, masseter).
enum ChinRecessionIntelligenceGuide {

    static let coachingPrinciplesBlock = """
    MENTON / MÂCHOIRE — SCRIPT #12 (récession = habitudes, pas génétique) :
    - Fascias → posture → muscles → os (orthotropics, mechanotransduction) — pas chirurgie seule
    - Double menton = hyoïde bas + sling musculaire (digastrique, super-hyoïdiens, langue)
    - Neck curls + souffle forcé (digastrique) + suction mew journée
    - Mentalis hyperactif → tape kinésiologie en X sur menton chaque nuit (STTO) + tape zyg
    - Mastication masseter : mordre puis rouler dents inférieures vers l'avant lentement
    - Pression langue spot T / papille incisive ~30 min/j — mandibule suit maxillaire
    - Thumb pull + alimentation + soleil catalysent — adaptation possible après 25 ans
    """

    static let chinJawRoutine: [String] = [
        "Neck curls — 3×10–12, active super-hyoïdiens (sous-mâchoire)",
        "Souffle / expiration forcée — digastrique, peau sous mâchoire (type AeroPit si dispo)",
        "Mastication masseter — mordre puis rouler mâchoire inférieure vers l'avant lentement",
        "Pression langue spot T — ~30 min/j (tongue chewing ou pression sur papille incisive)",
        "Tape mentalis en X sur menton chaque nuit — désactive mentalis (STTO) + tape zyg"
    ]

    static let lightChinRoutine: [String] = [
        "Suction mew + mastication lente sur aliments durs",
        "Tape mentalis nocturne si bruxisme ou menton fendu"
    ]

    static func enrichFaceProtocol(
        _ face: inout OriginFaceProtocol,
        answers: [String: WelcomePlanAnswer]
    ) {
        _ = face
        _ = answers
        // Exercices mâchoire / menton → posture ou 24/7, pas la routine matinale visage.
    }

    static func enrichPostureMobility(_ blocks: inout [String], answers: [String: WelcomePlanAnswer]) {
        guard hasChinConcern(answers: answers) else { return }
        let neckCurl = "Neck curls — 3×10–12 (menton / super-hyoïdiens, script #12)"
        if !blocks.contains(where: { $0.localizedCaseInsensitiveContains("Neck curls") }) {
            blocks.append(neckCurl)
        }
    }

    static func pillarHints(chinRecessedLikely: Bool) -> [String] {
        var hints: [String] = []
        if chinRecessedLikely {
            hints.append("Script #12 : menton récessif = mastication + mentalis + hyoïde — pas génétique")
            hints.append("Neck curls + souffle digastrique + tape mentalis X + mastication masseter")
            hints.append("Spot T 30 min/j — maxillaire antérieur tire mandibule")
        }
        return hints
    }

    static func hasChinConcern(answers: [String: WelcomePlanAnswer]) -> Bool {
        let ids = answers["face_concerns"]?.choiceIds ?? []
        return ids.contains("weak_jaw") || ids.contains("double_chin")
    }

    private static func needsFullChinProtocol(answers: [String: WelcomePlanAnswer]) -> Bool {
        hasChinConcern(answers: answers)
            || choice("forward_head", in: answers) == "yes"
            || choice("mouth_breathing", in: answers) == "yes"
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
