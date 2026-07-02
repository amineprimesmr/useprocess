import Foundation

// MARK: - Modèle séance catalogue

struct TrainingProgramSessionTemplate: Identifiable, Equatable {
    var id: TrainingSessionID { catalogEntry.id }
    let catalogEntry: TrainingSessionCatalogEntry
    let warmup: [String]
    let exercises: [OriginExercise]
    let cooldown: [String]

    var sessionName: String { catalogEntry.sessionName }
}

// MARK: - Catalogue programme (source unique pour calendrier + « Voir tout »)

enum TrainingProgramCatalog {

    static let standardGymCooldown: [String] = [
        "Marche lente — 3 min"
    ]

    static let femaleCooldown: [String] = [
        "Étirement fessiers — 2 min"
    ]

    static let sprintOptionLine = "Sprints — 8 répétitions de 15 s, repos 1 min 30 entre chaque"

    static func gymSessions() -> [TrainingProgramSessionTemplate] {
        [
            session(
                id: .pushGym,
                warmup: [
                    "Vélo — 5 min, effort léger",
                    "Mobilité épaules — 5 min"
                ],
                exercises: [
                    exercise("Développé haltères", sets: 4, reps: "8–10", group: "Épaules"),
                    exercise("Élévations latérales", sets: 3, reps: "12–15", group: "Deltoïdes"),
                    exercise("Face pulls", sets: 3, reps: "15–20", group: "Posture"),
                    exercise("Shrugs", sets: 3, reps: "12–15", group: "Trapèzes")
                ],
                cooldown: standardGymCooldown
            ),
            session(
                id: .pullGym,
                warmup: [
                    "Rameur — 5 min, effort léger",
                    "Mobilité épaules et thorax — 5 min"
                ],
                exercises: [
                    exercise("Tractions pronation", sets: 4, reps: "6–10", group: "Dos"),
                    exercise("Rowing haltère", sets: 3, reps: "8–12", group: "Dos"),
                    exercise("Face pulls", sets: 3, reps: "15", group: "Posture"),
                    exercise("Curl marteau", sets: 2, reps: "12", group: "Biceps")
                ],
                cooldown: standardGymCooldown
            ),
            session(
                id: .legsGym,
                warmup: [
                    "Tapis incliné — 5 min marche modérée, effort léger",
                    "Mobilité hanches et chevilles — 5 min"
                ],
                exercises: [
                    exercise("Squat barre", sets: 4, reps: "8–10", group: "Jambes"),
                    exercise("Romanian deadlift", sets: 3, reps: "8–10", group: "Fessiers"),
                    exercise("Hip thrust", sets: 3, reps: "10–12", group: "Fessiers"),
                    exercise("Mollets debout", sets: 3, reps: "15", group: "Mollets")
                ],
                cooldown: standardGymCooldown
            )
        ]
    }

    static func homeSessions() -> [TrainingProgramSessionTemplate] {
        [
            session(
                id: .pushHome,
                warmup: [
                    "Montées de genoux sur place — 5 min, effort léger",
                    "Mobilité épaules — 5 min"
                ],
                exercises: [
                    exercise("Pompes inclinées", sets: 4, reps: "10–15", group: "Pecs"),
                    exercise("Pike push-ups", sets: 3, reps: "8–12", group: "Épaules"),
                    exercise("Élévations bouteilles", sets: 3, reps: "15", group: "Deltoïdes"),
                    exercise("Face pulls élastique", sets: 3, reps: "15", group: "Posture")
                ],
                cooldown: standardGymCooldown
            ),
            session(
                id: .pullHome,
                warmup: [
                    "Jumping jacks lents — 5 min, effort léger",
                    "Mobilité dos et épaules — 5 min"
                ],
                exercises: [
                    exercise("Row élastique", sets: 4, reps: "8–12", group: "Dos"),
                    exercise("Reverse fly élastique", sets: 3, reps: "15", group: "Posture"),
                    exercise("Superman hold", sets: 3, reps: "30 s", group: "Dos"),
                    exercise("Planche", sets: 3, reps: "45 s", group: "Core")
                ],
                cooldown: standardGymCooldown
            ),
            session(
                id: .legsHome,
                warmup: [
                    "Marche sur place, pas amplifiés — 5 min, effort léger",
                    "Activation fessiers — 5 min"
                ],
                exercises: [
                    exercise("Goblet squat", sets: 4, reps: "12–15", group: "Jambes"),
                    exercise("Fentes", sets: 3, reps: "10/jambe", group: "Jambes"),
                    exercise("Hip thrust au sol", sets: 3, reps: "15", group: "Fessiers"),
                    exercise("Mollets marche", sets: 3, reps: "20", group: "Mollets")
                ],
                cooldown: standardGymCooldown
            )
        ]
    }

    static func femaleSessions() -> [TrainingProgramSessionTemplate] {
        [
            session(
                id: .femaleGlutes,
                warmup: [
                    "Marche sur place — 5 min, effort léger",
                    "Activation fessiers — 5 min"
                ],
                exercises: [
                    exercise("Hip thrust", sets: 4, reps: "10–12", group: "Fessiers"),
                    exercise("Fentes marchées", sets: 3, reps: "10/jambe", group: "Jambes"),
                    exercise("Abduction hanche", sets: 3, reps: "15", group: "Fessiers"),
                    exercise("Planche", sets: 3, reps: "45 s", group: "Core")
                ],
                cooldown: femaleCooldown
            ),
            session(
                id: .femaleUpper,
                warmup: [
                    "Vélo — 5 min, effort léger",
                    "Mobilité épaules — 5 min"
                ],
                exercises: [
                    exercise("Tirage vertical", sets: 3, reps: "10–12", group: "Dos"),
                    exercise("Push-ups inclinés", sets: 3, reps: "8–12", group: "Pecs"),
                    exercise("Face pulls", sets: 3, reps: "15", group: "Posture"),
                    exercise("Dead bug", sets: 3, reps: "10/côté", group: "Core")
                ],
                cooldown: femaleCooldown
            )
        ]
    }

    static func restSession() -> TrainingProgramSessionTemplate {
        session(id: .restDay, warmup: [], exercises: [], cooldown: [])
    }

    static func allSessionTemplates() -> [TrainingProgramSessionTemplate] {
        gymSessions() + homeSessions() + femaleSessions() + [restSession()]
    }

    /// Blocs cardio / mobilité uniques utilisés dans le programme.
    static func sharedCardioMobilityBlocks() -> [String] {
        var lines: [String] = []
        for template in gymSessions() + homeSessions() + femaleSessions() {
            for line in template.warmup + template.cooldown {
                if !lines.contains(line) {
                    lines.append(line)
                }
            }
        }
        if !lines.contains(sprintOptionLine) {
            lines.append(sprintOptionLine)
        }
        return lines
    }

    static func warmupForSessionIndex(
        _ sessionIndex: Int,
        weekday: Int,
        useFemale: Bool,
        useHome: Bool = false
    ) -> [String] {
        let sessions = useFemale ? femaleSessions() : (useHome ? homeSessions() : gymSessions())
        let idx = sessionIndex % sessions.count
        return sprintWarmupIfNeeded(weekday: weekday, base: sessions[idx].warmup)
    }

    static func cooldownForSession(useFemale: Bool) -> [String] {
        useFemale ? femaleCooldown : standardGymCooldown
    }

    static func exerciseLists(useHome: Bool) -> [[OriginExercise]] {
        let sessions = useHome ? homeSessions() : gymSessions()
        return sessions.map(\.exercises)
    }

    static func sessionNames(useHome: Bool) -> [String] {
        let sessions = useHome ? homeSessions() : gymSessions()
        return sessions.map(\.sessionName)
    }

    static func femaleExerciseLists() -> [[OriginExercise]] {
        femaleSessions().map(\.exercises)
    }

    static func femaleSessionNames() -> [String] {
        femaleSessions().map(\.sessionName)
    }

    static func matchesToday(_ template: TrainingProgramSessionTemplate, day: OriginProgramDay) -> Bool {
        if template.id == .restDay {
            return day.training == nil
        }
        guard let training = day.training else { return false }
        return TrainingSessionCatalog.entry(matchingSessionName: training.sessionName)?.id == template.id
    }

    // MARK: - Private

    private static func session(
        id: TrainingSessionID,
        warmup: [String],
        exercises: [OriginExercise],
        cooldown: [String]
    ) -> TrainingProgramSessionTemplate {
        TrainingProgramSessionTemplate(
            catalogEntry: TrainingSessionCatalog.entry(for: id),
            warmup: warmup,
            exercises: exercises,
            cooldown: cooldown
        )
    }

    static func exercise(_ name: String, sets: Int, reps: String, group: String) -> OriginExercise {
        OriginExercise(
            id: stableExerciseID(name),
            name: name,
            sets: sets,
            reps: reps,
            restSeconds: 90,
            coachingCue: "Contrôle > ego",
            muscleGroup: group
        )
    }

    private static func stableExerciseID(_ name: String) -> String {
        let slug = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "catalog.exercise.\(slug)"
    }

    private static func sprintWarmupIfNeeded(weekday: Int, base: [String]) -> [String] {
        var warmup = base
        if weekday == 2 {
            warmup.append(sprintOptionLine)
        }
        return warmup
    }
}
