import Foundation

/// Intelligence sommeil latéral + posture langue — script #13.
/// Source unique routine nocturne (fusion script #9 mewing sleep + #13 côté).
enum SideSleepIntelligenceGuide {

    static let coachingPrinciplesBlock = """
    SOMMEIL LATÉRAL — SCRIPT #13 (langue = moteur du visage la nuit) :
    - Langue sur palais = support maxillaire → visage vers le haut/avant (mâchoire, rides, dents)
    - Dormir sur le dos = gravité 8 h/j — langue tombe → visage recule, fascia palais dense
    - Ligne frontale superficielle (langue → pieds) : langue basse restreint crâne + posture cranienne
    - Habitudes myofonction → parafonction : déglutition faible, mastication molle, tout âge
    - Sommeil **côté** = position fœtale — airways ouvertes, langue sur palais (tribus / ancestral)
    - Avant coucher : spot T + sourire max + 3 déglutitions — maintenir suction
    - Tape zyg joues + menton — fascias, asymétrie, lip seal nocturne
    - Côté : coussin entre cuisses + main sous tête
    - Respiration vers l'arrière dans le visage (pas vers le crâne) — fascia thoracique + cervicale
    - Apnée / asthme / mâchoire récessée souvent liés au dos + langue basse — réversible sans chirurgie
    """

    /// Routine nocturne complète — fusion #9 + #13 sans doublons.
    static func unifiedEveningRoutine(
        answers: [String: WelcomePlanAnswer],
        full: Bool
    ) -> [String] {
        if full {
            return [
                AppCopy.tSync(
                    "Spot T + sourire max + 3 déglutitions — maintenir langue sur palais",
                    en: "Spot T + max smile + 3 swallows — keep tongue on palate"
                ),
                AppCopy.tSync(
                    "Tape zyg sur joues + menton — lip seal, asymétrie, fascias",
                    en: "Zyg tape on cheeks + chin — lip seal, asymmetry, fascia"
                ),
                AppCopy.tSync(
                    "Respiration vers l'arrière dans le visage (pas vers le crâne) — thorax + nuque",
                    en: "Breathe back into the face (not into the skull) — thorax + neck"
                ),
                AppCopy.tSync(
                    "Dormir sur le côté — coussin entre cuisses + main sous tête (pas le dos ~8 h/j)",
                    en: "Sleep on your side — pillow between thighs + hand under head (not on your back ~8 h/day)"
                )
            ]
        }
        return [
            AppCopy.tSync(
                "Dormir sur le côté — langue sur palais ; dos = visage recule avec gravité",
                en: "Sleep on your side — tongue on palate; back sleeping = face slides back with gravity"
            ),
            AppCopy.tSync(
                "Spot T + 3 déglutitions avant coucher si pas encore automatique",
                en: "Spot T + 3 swallows before bed if not automatic yet"
            )
        ]
    }

    /// Lignes courtes pour la checklist journal (max 4).
    static func checklistEveningTasks(
        answers: [String: WelcomePlanAnswer],
        sleepProtocol: OriginSleepProtocol
    ) -> [String] {
        let full = needsFullSideSleepProtocol(answers: answers)
        let fromProtocol = sleepProtocol.eveningRoutine.filter { line in
            isSleepRoutineLine(line)
        }
        if !fromProtocol.isEmpty {
            return Array(fromProtocol.prefix(4))
        }
        return Array(unifiedEveningRoutine(answers: answers, full: full).prefix(4))
    }

    static func enrichSleepProtocol(
        _ sleep: inout OriginSleepProtocol,
        answers: [String: WelcomePlanAnswer]
    ) {
        let routine = unifiedEveningRoutine(
            answers: answers,
            full: needsFullSideSleepProtocol(answers: answers)
        )
        for line in routine {
            let normalized = normalizedSleepLine(line)
            if !sleep.eveningRoutine.contains(where: { normalizedSleepLine($0) == normalized }) {
                sleep.eveningRoutine.append(line)
            }
        }
    }

    static func pillarHints(sideSleepPriority: Bool) -> [String] {
        guard sideSleepPriority else { return [] }
        return [
            AppCopy.tSync(
                "Script #13 : dos 8 h/j = langue basse → visage recule — côté + langue sur palais",
                en: "Script #13: back 8 h/day = low tongue → face slides back — side + tongue on palate"
            ),
            AppCopy.tSync(
                "Ligne frontale superficielle : langue basse restreint crâne et posture cervicale",
                en: "Superficial front line: low tongue restricts skull and cervical posture"
            ),
            AppCopy.tSync(
                "Spot T + 3 swallows + tape zyg joues/menton + côté coussin genoux main sous tête",
                en: "Spot T + 3 swallows + zyg tape cheeks/chin + side pillow knees hand under head"
            ),
            AppCopy.tSync(
                "Respiration vers l'arrière dans le visage avant sommeil — fascia thoracique",
                en: "Breathe back into the face before sleep — thoracic fascia"
            )
        ]
    }

    static func needsFullSideSleepProtocol(answers: [String: WelcomePlanAnswer]) -> Bool {
        let faceIds = answers["face_concerns"]?.choiceIds ?? []
        let jawFocus = faceIds.contains(where: {
            $0 == "weak_jaw" || $0 == "double_chin" || $0 == "asymmetry"
        })
        let sleep = choice("sleep_quality", in: answers) ?? ""
        let badSleep = sleep.contains("Mauvais") || sleep.contains("Très mauvais")

        return jawFocus
            || choice("mouth_breathing", in: answers) == "yes"
            || choice("forward_head", in: answers) == "yes"
            || badSleep
    }

    private static func isSleepRoutineLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("côté")
            || lower.contains("side")
            || lower.contains("spot t")
            || lower.contains("tape zyg")
            || lower.contains("zyg tape")
            || lower.contains("respiration vers")
            || lower.contains("breathe back")
            || lower.contains("déglutition")
            || lower.contains("swallow")
            || lower.contains("langue sur palais")
            || lower.contains("tongue on palate")
    }

    private static func normalizedSleepLine(_ line: String) -> String {
        line
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func choice(_ id: String, in answers: [String: WelcomePlanAnswer]) -> String? {
        answers[id]?.choiceIds.first
    }
}
