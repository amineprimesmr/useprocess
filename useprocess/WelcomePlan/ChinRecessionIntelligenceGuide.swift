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

    static var chinJawRoutine: [String] {
        [
            AppCopy.tSync(
                "Neck curls — 3×10–12, buste sur lit/canapé tête dans le vide, super-hyoïdiens (sous-mâchoire)",
                en: "Neck curls — 3×10–12, torso on bed/couch head hanging, suprahyoids (under jaw)"
            ),
            AppCopy.tSync(
                "Souffle / expiration forcée — digastrique, peau sous mâchoire (type AeroPit si dispo)",
                en: "Forced breath / exhale — digastric, skin under jaw (AeroPit-style if available)"
            ),
            AppCopy.tSync(
                "Mastication masseter — mordre puis rouler mâchoire inférieure vers l'avant lentement",
                en: "Masseter chew — bite then slowly roll lower jaw forward"
            ),
            AppCopy.tSync(
                "Pression langue spot T — ~30 min/j (tongue chewing ou pression sur papille incisive)",
                en: "Tongue pressure spot T — ~30 min/day (tongue chewing or pressure on incisive papilla)"
            ),
            AppCopy.tSync(
                "Tape mentalis en X sur menton chaque nuit — désactive mentalis (STTO) + tape zyg",
                en: "Mentalis tape in an X on chin each night — deactivate mentalis (STTO) + zyg tape"
            )
        ]
    }

    static var lightChinRoutine: [String] {
        [
            AppCopy.tSync(
                "Suction mew + mastication lente sur aliments durs",
                en: "Suction mew + slow chewing on hard foods"
            ),
            AppCopy.tSync(
                "Tape mentalis nocturne si bruxisme ou menton fendu",
                en: "Night mentalis tape if bruxism or cleft chin"
            )
        ]
    }

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

        let souffle = AppCopy.tSync(
            "Souffle digastrique — expiration forcée 2×10 (sous-mâchoire, maison)",
            en: "Digastric breath — forced exhale 2×10 (under jaw, at home)"
        )
        if !blocks.contains(where: {
            $0.localizedCaseInsensitiveContains("digastrique")
                || $0.localizedCaseInsensitiveContains("digastric")
                || $0.localizedCaseInsensitiveContains("Souffle")
                || $0.localizedCaseInsensitiveContains("Forced breath")
        }) {
            blocks.append(souffle)
        }
    }

    static func pillarHints(chinRecessedLikely: Bool) -> [String] {
        var hints: [String] = []
        if chinRecessedLikely {
            hints.append(AppCopy.tSync(
                "Script #12 : menton récessif = mastication + mentalis + hyoïde — pas génétique",
                en: "Script #12: recessed chin = chewing + mentalis + hyoid — not genetics"
            ))
            hints.append(AppCopy.tSync(
                "Neck curls + souffle digastrique + tape mentalis X + mastication masseter",
                en: "Neck curls + digastric breath + mentalis X tape + masseter chewing"
            ))
            hints.append(AppCopy.tSync(
                "Spot T 30 min/j — maxillaire antérieur tire mandibule",
                en: "Spot T 30 min/day — anterior maxilla pulls mandible"
            ))
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
