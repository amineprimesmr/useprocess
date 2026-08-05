import Foundation

/// Contenu éducatif debloat — nutrition, entraînement, sommeil, visage.
/// Basé sur OMS (Na/K), littérature rétention hydrique et recommandations Process.
enum HealthDebloatGuide {

    enum Pillar: String, CaseIterable, Identifiable {
        case nutrition
        case training
        case sleep
        case face
        case continuousHabits

        var id: String { rawValue }

        @MainActor
        var title: String {
            switch self {
            case .nutrition: return AppCopy.t("Nutrition", en: "Nutrition")
            case .training: return AppCopy.t("Cardio et Circuit", en: "Cardio & Circuit")
            case .sleep: return AppCopy.t("Sommeil", en: "Sleep")
            case .face: return AppCopy.t("Visage", en: "Face")
            case .continuousHabits: return AppCopy.t("24/7", en: "24/7")
            }
        }

        var icon: String {
            switch self {
            case .nutrition: return "leaf.fill"
            case .training: return "figure.run"
            case .sleep: return "bed.double.fill"
            case .face: return "face.smiling"
            case .continuousHabits: return "infinity"
            }
        }

        @MainActor
        var tagline: String {
            switch self {
            case .nutrition:
                return AppCopy.t(
                    "L’équilibre sodium · potassium et l’hydratation — le cœur du debloat.",
                    en: "Sodium–potassium balance and hydration — the core of debloat."
                )
            case .training:
                return AppCopy.t(
                    "Circulation, drainage lymphatique et dépense quotidienne.",
                    en: "Circulation, lymphatic drainage, and daily expenditure."
                )
            case .sleep:
                return AppCopy.t(
                    "Qualité, position et timing — ce qui se joue la nuit.",
                    en: "Quality, position, and timing — what happens overnight."
                )
            case .face:
                return AppCopy.t(
                    "Scan, froid et massage — mesurer et relancer la circulation.",
                    en: "Scan, cold, and massage — measure and restart circulation."
                )
            case .continuousHabits:
                return AppCopy.t(
                    "Mewing, posture et respiration — la base orthotropics en continu.",
                    en: "Mewing, posture, and breathing — continuous orthotropics basics."
                )
            }
        }
    }

    struct Topic: Identifiable {
        let id: String
        let title: String
        let summary: String
        let body: String
        let bullets: [String]
        let accent: TopicAccent
        /// Pilier d’origine — affiché en label discret, pas un onglet.
        let pillar: Pillar
    }

    /// Tous les leviers debloat, ordonnés par impact physiologique (Process).
    struct RankedTopic: Identifiable {
        let rank: Int
        let topic: Topic

        var id: String { topic.id }
    }

    @MainActor
    static var pageIntro: String {
        AppCopy.t(
            """
            Un visage gonflé le matin, ce n’est pas toujours de la graisse — souvent c’est de l’eau retenue. \
            Ce guide regroupe tout ce qui compte, du plus impactant au complémentaire. \
            La régularité sur les premiers points change le visage plus vite que les « hacks ».
            """,
            en: """
            A puffy face in the morning isn’t always fat — often it’s retained water. \
            This guide covers what matters, from highest impact to complementary. \
            Consistency on the first points changes the face faster than “hacks”.
            """
        )
    }

    enum TopicAccent {
        case sodiumPotassium
        case hydration
        case triggers
        case action
        case myth
    }

    // MARK: - Nutrition (focus debloat visage)

    @MainActor
    static var nutritionTopics: [Topic] {
        [
        Topic(
            id: "mechanism",
            title: AppCopy.t("Ce qui se passe vraiment", en: "What’s really happening"),
            summary: AppCopy.t(
                "L’eau suit le sodium. Le potassium aide à l’évacuer.",
                en: "Water follows sodium. Potassium helps flush it out."
            ),
            body: AppCopy.t(
                """
                Tes cellules régulent leur volume avec deux minéraux : le sodium (sel) et le potassium. \
                Quand tu consommes beaucoup de sodium — surtout d’un coup, le soir — ton corps retient \
                de l’eau pour diluer l’excès. Résultat : visage plus plein au réveil.

                Le potassium joue le rôle inverse : il aide les reins à excréter le sodium excédentaire. \
                Problème courant : régimes riches en plats transformés (beaucoup de sel, peu de potassium) \
                = rétention hydrique favorisée.
                """,
                en: """
                Your cells regulate volume with two minerals: sodium (salt) and potassium. \
                When you eat a lot of sodium — especially at once, in the evening — your body retains \
                water to dilute the excess. Result: a fuller face on waking.

                Potassium does the opposite: it helps kidneys excrete excess sodium. \
                Common issue: diets heavy in processed food (lots of salt, little potassium) \
                = more water retention.
                """
            ),
            bullets: [
                AppCopy.t("Gonflement ≠ graisse faciale dans la majorité des cas quotidiens", en: "Puffiness ≠ facial fat in most day-to-day cases"),
                AppCopy.t("L’effet se voit surtout 6 à 12 h après un repas très salé ou alcoolisé", en: "The effect shows mainly 6–12 h after a very salty or alcohol-heavy meal"),
                AppCopy.t("Corriger l’équilibre alimentaire agit plus vite qu’un « hack » cosmétique", en: "Fixing food balance works faster than a cosmetic “hack”")
            ],
            accent: .sodiumPotassium,
            pillar: .nutrition
        ),
        Topic(
            id: "sodium-potassium",
            title: AppCopy.t("Balance sodium · potassium", en: "Sodium–potassium balance"),
            summary: AppCopy.t(
                "Viser moins de sel caché, plus de végétaux et légumineuses.",
                en: "Aim for less hidden salt, more plants and legumes."
            ),
            body: AppCopy.t(
                """
                L’OMS recommande aux adultes moins de 2 000 mg de sodium par jour (≈ 5 g de sel) \
                et au moins 3 500 mg de potassium via les aliments. En pratique, beaucoup dépassent \
                largement le sodium (souvent 3 000–3 400 mg) tout en mangeant peu de potassium.

                L’objectif n’est pas de « zéro sel » — c’est d’équilibrer : moins de sodium ajouté \
                et caché, plus de sources naturelles de potassium à chaque repas.
                """,
                en: """
                WHO recommends adults under 2,000 mg of sodium per day (≈ 5 g of salt) \
                and at least 3,500 mg of potassium from food. In practice, many exceed \
                sodium (often 3,000–3,400 mg) while eating little potassium.

                The goal isn’t “zero salt” — it’s balance: less added and hidden sodium, \
                more natural potassium sources at every meal.
                """
            ),
            bullets: [
                AppCopy.t("Sources K+ : épinards, pomme de terre, avocat, haricots, banane, saumon", en: "K+ sources: spinach, potato, avocado, beans, banana, salmon"),
                AppCopy.t("Pièges Na+ : charcuterie, plats préparés, sauces (soja, nuggets), restauration rapide", en: "Na+ traps: deli meats, prepared meals, sauces (soy, nuggets), fast food"),
                AppCopy.t("Lis les étiquettes : le sel se cache aussi dans le pain, les soupes, les fromages", en: "Read labels: salt also hides in bread, soups, and cheese")
            ],
            accent: .sodiumPotassium,
            pillar: .nutrition
        ),
        Topic(
            id: "hydration",
            title: AppCopy.t("Hydratation — le paradoxe", en: "Hydration — the paradox"),
            summary: AppCopy.t(
                "Boire régulièrement évite que le corps retienne par défaut.",
                en: "Drinking regularly stops the body from retaining by default."
            ),
            body: AppCopy.t(
                """
                Manquer d’eau pousse paradoxalement le corps à retenir les fluides. \
                Une hydratation régulière sur la journée aide les reins à filtrer le sodium \
                et limite le gonflement.

                Répartis ta consommation : un gros verre au réveil, puis des prises régulières \
                avant d’avoir soif. Évite de compenser uniquement le soir — trop tard pour \
                limiter le gonflement du lendemain matin.
                """,
                en: """
                Low water intake paradoxically pushes the body to retain fluids. \
                Steady hydration across the day helps kidneys filter sodium \
                and limits puffiness.

                Spread intake: a large glass on waking, then regular sips \
                before you’re thirsty. Don’t only catch up at night — too late to \
                limit next-morning puffiness.
                """
            ),
            bullets: [
                AppCopy.t("Cible Process : \(ProcessDailyTargets.hydrationLabel) répartis sur la journée", en: "Process target: \(ProcessDailyTargets.hydrationLabel) spread across the day"),
                ProcessHydrationGuide.morningLine,
                AppCopy.t("Limite alcool et excès de caféine — ils déshydratent puis favorisent la rétention", en: "Limit alcohol and excess caffeine — they dehydrate then favor retention")
            ],
            accent: .hydration,
            pillar: .nutrition
        ),
        Topic(
            id: "triggers",
            title: AppCopy.t("Ce qui gonfle le plus le visage", en: "What puffs the face most"),
            summary: AppCopy.t(
                "Timing et qualité comptent autant que la quantité.",
                en: "Timing and quality matter as much as quantity."
            ),
            body: AppCopy.t(
                """
                Certains aliments et habitudes amplifient la rétention, surtout en fin de journée :

                • Repas très salés le soir → gonflement visible au réveil
                • Alcool → déshydratation puis rebond inflammatoire et rétention
                • Dîner riche en glucides raffinés → chaque gramme de glycogène retient ~3–4 g d’eau
                • Ultra-transformés → sodium élevé + faible potassium + inflammation

                Le même repas à midi aura souvent moins d’impact qu’à 21 h, car tu as la journée \
                pour bouger, transpirer et éliminer.
                """,
                en: """
                Some foods and habits amplify retention, especially late in the day:

                • Very salty evening meals → visible puffiness on waking
                • Alcohol → dehydration then inflammatory rebound and retention
                • Dinner high in refined carbs → each gram of glycogen holds ~3–4 g of water
                • Ultra-processed foods → high sodium + low potassium + inflammation

                The same meal at noon often hits less than at 9 pm, because you have the day \
                to move, sweat, and clear it.
                """
            ),
            bullets: [
                AppCopy.t("Priorise un dîner plus léger en sel, plus riche en légumes", en: "Prioritize a lower-salt dinner with more vegetables"),
                AppCopy.t("Favorise glucides complexes le jour, pas un gros plat de pâtes/blé blanc tard", en: "Favor complex carbs earlier — not a big late pasta/white-flour meal"),
                AppCopy.t("MSG et sauces industrielles = sodium concentré — même effet que le sel de table", en: "MSG and industrial sauces = concentrated sodium — same effect as table salt")
            ],
            accent: .triggers,
            pillar: .nutrition
        ),
        Topic(
            id: "daily-plan",
            title: AppCopy.t("Ton plan concret (Process)", en: "Your concrete plan (Process)"),
            summary: AppCopy.t(
                "Simple, répétable — c’est la régularité qui change le visage.",
                en: "Simple, repeatable — consistency is what changes the face."
            ),
            body: AppCopy.t(
                """
                Pas besoin de régime extrême. Une routine alimentaire stable bat une semaine parfaite \
                suivie de trois jours de relâchement.
                """,
                en: """
                No need for an extreme diet. A stable food routine beats one perfect week \
                followed by three days off the rails.
                """
            ),
            bullets: [
                AppCopy.t("\(ProcessDailyTargets.hydrationLitersPerDay) L d’eau · \(ProcessHydrationGuide.rankedWaters.first?.name ?? "eau") ou équivalent", en: "\(ProcessDailyTargets.hydrationLitersPerDay) L of water · \(ProcessHydrationGuide.rankedWaters.first?.name ?? "water") or equivalent"),
                AppCopy.t("Légumes ou fruit à chaque repas (potassium + fibres anti-inflammatoires)", en: "Veggies or fruit at every meal (potassium + anti-inflammatory fiber)"),
                AppCopy.t("Repas du soir : protéine + légumes, sel modéré — pas de festin salé tard", en: "Evening meal: protein + veggies, moderate salt — no late salty feast"),
                AppCopy.t("Caféine coupée à \(ProcessDailyTargets.caffeineCutoffHour) h pour protéger le sommeil (lié au gonflement matinal)", en: "Cut caffeine by \(ProcessDailyTargets.caffeineCutoffHour):00 to protect sleep (linked to morning puffiness)"),
                AppCopy.t("\(ProcessDailyTargets.chewsPerBite) mâchées par bouchée — digestion lente = moins de ballonnements", en: "\(ProcessDailyTargets.chewsPerBite) chews per bite — slow digestion = less bloating")
            ],
            accent: .action,
            pillar: .nutrition
        ),
        Topic(
            id: "myths",
            title: AppCopy.t("Mythes à éviter", en: "Myths to avoid"),
            summary: AppCopy.t(
                "Ce qui ne résout pas le problème à la source.",
                en: "What doesn’t solve the problem at the source."
            ),
            body: AppCopy.t(
                """
                Le « cortisol face » viral exagère l’effet du stress quotidien. \
                Un gonflement visible vient surtout de sel, alcool, sommeil et position — \
                pas d’un pic de cortisol passager.

                Couper tout le sel ou prendre des diurétiques / potassium en complément sans suivi \
                médical peut empirer l’équilibre électrolytique et la rétention.
                """,
                en: """
                Viral “cortisol face” hype overstates everyday stress. \
                Visible puffiness mostly comes from salt, alcohol, sleep, and position — \
                not a short cortisol spike.

                Cutting all salt or taking diuretics / potassium supplements without medical \
                follow-up can worsen electrolyte balance and retention.
                """
            ),
            bullets: [
                AppCopy.t("Gua sha, glace, massage : utiles en complément, pas en remplacement de l’alimentation", en: "Gua sha, ice, massage: useful add-ons, not a food replacement"),
                AppCopy.t("La graisse faciale ne disparaît pas en 48 h — elle suit la perte de masse grasse globale", en: "Facial fat doesn’t vanish in 48 h — it follows overall fat loss"),
                AppCopy.t("Gonflement persistant, unilatéral ou brutal → consulter (thyroïde, rein, allergie…)", en: "Persistent, one-sided, or sudden puffiness → see a clinician (thyroid, kidney, allergy…)")
            ],
            accent: .myth,
            pillar: .nutrition
        )
        ]
    }

    // MARK: - Autres piliers (résumés actionnables)

    @MainActor
    static var trainingTopics: [Topic] {
        [
        Topic(
            id: "steps",
            title: AppCopy.t("Pas quotidiens", en: "Daily steps"),
            summary: AppCopy.t(
                "\(ProcessDailyTargets.dailySteps.formatted()) pas — circulation et drainage.",
                en: "\(ProcessDailyTargets.dailySteps.formatted()) steps — circulation and drainage."
            ),
            body: AppCopy.t(
                "La marche active la circulation veineuse et lymphatique. Une journée sédentaire favorise la stagnation des fluides, y compris au visage.",
                en: "Walking activates venous and lymphatic circulation. A sedentary day favors fluid stagnation, including in the face."
            ),
            bullets: [
                AppCopy.t("Objectif Process : \(ProcessDailyTargets.dailySteps.formatted()) pas/jour", en: "Process goal: \(ProcessDailyTargets.dailySteps.formatted()) steps/day"),
                AppCopy.t("\(ProcessDailyTargets.outdoorWalkSessionsPerWeek) sorties marche extérieure / semaine", en: "\(ProcessDailyTargets.outdoorWalkSessionsPerWeek) outdoor walks / week"),
                AppCopy.t("\(ProcessDailyTargets.restDaysPerWeek) jours de repos actif / semaine", en: "\(ProcessDailyTargets.restDaysPerWeek) active rest days / week")
            ],
            accent: .action,
            pillar: .training
        ),
        Topic(
            id: "lymph",
            title: AppCopy.t("Massage lymphatique", en: "Lymphatic massage"),
            summary: AppCopy.t(
                "\(ProcessDailyTargets.lymphFaceMassageMinutes) min — relance le drainage, pas la graisse.",
                en: "\(ProcessDailyTargets.lymphFaceMassageMinutes) min — boosts drainage, not fat loss."
            ),
            body: AppCopy.t(
                "Le massage facial aide le liquide interstitiel à circuler vers les ganglions. C’est un outil complémentaire, pas une solution seule.",
                en: "Facial massage helps interstitial fluid move toward lymph nodes. It’s a complementary tool, not a standalone fix."
            ),
            bullets: [
                AppCopy.t("\(ProcessDailyTargets.lymphFaceMassageMinutes) minute le matin, mouvements vers les oreilles puis le cou", en: "\(ProcessDailyTargets.lymphFaceMassageMinutes) minute in the morning, strokes toward the ears then neck"),
                AppCopy.t("Combine avec le scan et la douche froide pour un effet immédiat visible", en: "Combine with the scan and a cold rinse for a visible immediate effect")
            ],
            accent: .action,
            pillar: .training
        )
        ]
    }

    @MainActor
    static var sleepTopics: [Topic] {
        [
        Topic(
            id: "duration",
            title: AppCopy.t("Durée et régularité", en: "Duration and consistency"),
            summary: AppCopy.t(
                "\(ProcessDailyTargets.sleepHours) h — le sommeil régule l’eau et le sel.",
                en: "\(ProcessDailyTargets.sleepHours) h — sleep regulates water and salt."
            ),
            body: AppCopy.t(
                "Un sommeil court ou irrégulier perturbe la régulation hydrique et favorise le gonflement matinal. Vise une plage horaire stable ± \(ProcessDailyTargets.sleepScheduleMarginMinutes) min.",
                en: "Short or irregular sleep disrupts fluid regulation and favors morning puffiness. Aim for a stable window ± \(ProcessDailyTargets.sleepScheduleMarginMinutes) min."
            ),
            bullets: [
                AppCopy.t("Cible : \(ProcessDailyTargets.sleepHours) h par nuit", en: "Target: \(ProcessDailyTargets.sleepHours) h per night"),
                AppCopy.t("Horaires de coucher/réveil réguliers, même le week-end", en: "Consistent bedtime/wake times, even on weekends")
            ],
            accent: .action,
            pillar: .sleep
        ),
        Topic(
            id: "position",
            title: AppCopy.t("Position et environnement", en: "Position and environment"),
            summary: AppCopy.t(
                "Dos, tête surélevée, chambre fraîche.",
                en: "On your back, head slightly elevated, cool room."
            ),
            body: AppCopy.t(
                "Dormir sur le ventre ou le côté favorise l’accumulation de fluides vers le visage. Une chambre autour de \(ProcessDailyTargets.bedroomTempCelsius) °C améliore la qualité du sommeil profond.",
                en: "Sleeping on your stomach or side favors fluid pooling toward the face. A room around \(ProcessDailyTargets.bedroomTempCelsius) °C improves deep-sleep quality."
            ),
            bullets: [
                AppCopy.t("Sur le dos, oreiller légèrement plus haut", en: "On your back, pillow slightly higher"),
                AppCopy.t("Couvre-feu écrans \(ProcessDailyTargets.screenCurfewMinutes) min avant le coucher", en: "Screen curfew \(ProcessDailyTargets.screenCurfewMinutes) min before bed"),
                AppCopy.t("Température chambre ~\(ProcessDailyTargets.bedroomTempCelsius) °C", en: "Room temp ~\(ProcessDailyTargets.bedroomTempCelsius) °C")
            ],
            accent: .action,
            pillar: .sleep
        )
        ]
    }

    @MainActor
    static var faceTopics: [Topic] {
        [
        Topic(
            id: "scan",
            title: AppCopy.t("Scan quotidien", en: "Daily scan"),
            summary: AppCopy.t(
                "Mesurer pour voir la corrélation avec ton plan personnalisé.",
                en: "Measure to see the correlation with your personalized plan."
            ),
            body: AppCopy.t(
                "Le scan Process te permet de suivre l’évolution et de relier gonflement, sommeil et habitudes. C’est un feedback, pas un diagnostic médical.",
                en: "The Process scan lets you track changes and link puffiness, sleep, and habits. It’s feedback, not a medical diagnosis."
            ),
            bullets: [
                AppCopy.t("\(ProcessDailyTargets.faceScanSeconds) s chaque matin, même lumière", en: "\(ProcessDailyTargets.faceScanSeconds) s every morning, same light"),
                AppCopy.t("Compare avec ton journal (sel, alcool, sommeil) pour comprendre tes déclencheurs", en: "Compare with your journal (salt, alcohol, sleep) to learn your triggers")
            ],
            accent: .action,
            pillar: .face
        ),
        Topic(
            id: "cold",
            title: AppCopy.t("Froid et circulation", en: "Cold and circulation"),
            summary: AppCopy.t(
                "\(ProcessDailyTargets.coldFaceRinseSeconds) s d’eau froide — vasoconstriction temporaire.",
                en: "\(ProcessDailyTargets.coldFaceRinseSeconds) s of cold water — temporary vasoconstriction."
            ),
            body: AppCopy.t(
                "Le froid resserre les vaisseaux superficiels et donne un effet « dégonflé » immédiat. Ça ne remplace pas la nutrition, mais c’est un bon levier matinal.",
                en: "Cold tightens superficial vessels and gives an immediate “de-puffed” look. It doesn’t replace nutrition, but it’s a strong morning lever."
            ),
            bullets: [
                AppCopy.t("Rinçage visage \(ProcessDailyTargets.coldFaceRinseSeconds) s après le réveil", en: "Face rinse \(ProcessDailyTargets.coldFaceRinseSeconds) s after waking"),
                AppCopy.t("Circuit lymphatique matinal — sauts, genoux, bras alternés pour activer la lymphe", en: "Morning lymph circuit — jumps, knees, alternating arms to activate lymph")
            ],
            accent: .action,
            pillar: .face
        )
        ]
    }

    @MainActor
    static var continuousHabitsTopic: Topic {
        let habitLines = ProcessContinuousHabits.all.map { habit in
            "\(habit.title) — \(habit.detail)"
        }
        return Topic(
            id: "continuous-habits",
            title: AppCopy.t("Habitudes 24/7", en: "24/7 habits"),
            summary: AppCopy.t(
                "Mewing, posture, respiration — pas des exercices à timer.",
                en: "Mewing, posture, breathing — not timed exercises."
            ),
            body: AppCopy.t(
                """
                Ces habitudes ne se cochent pas dans le journal : elles s'appliquent en continu, toute la journée. \
                C'est la couche fondation (scripts mewing #9 et posture #7) — sans elle, le debloat reste fragile.

                Priorité : mewing (langue + bouche fermée + air par le nez), lèvres closes, puis posture et sommeil.
                """,
                en: """
                These habits aren’t journal checkboxes: they apply continuously all day. \
                They’re the foundation layer (mewing #9 and posture #7 scripts) — without them, debloat stays fragile.

                Priority: mewing (tongue + mouth closed + nose breathing), lips sealed, then posture and sleep.
                """
            ),
            bullets: habitLines,
            accent: .action,
            pillar: .continuousHabits
        )
    }

    /// Ordre d’impact debloat — nutrition & sommeil d’abord, routines visage en complément.
    @MainActor
    static var rankedTopics: [RankedTopic] {
        let ordered: [Topic] = [
            nutritionTopics[0],  // mécanisme
            nutritionTopics[1],  // Na/K
            nutritionTopics[2],  // hydratation
            nutritionTopics[3],  // triggers
            sleepTopics[0],      // durée sommeil
            sleepTopics[1],      // position
            continuousHabitsTopic,
            nutritionTopics[4],  // plan concret
            trainingTopics[0],   // pas
            faceTopics[1],       // froid (routine matinale)
            faceTopics[0],       // scan
            trainingTopics[1],   // lymph
            nutritionTopics[5]  // mythes
        ]
        return ordered.enumerated().map { index, topic in
            RankedTopic(rank: index + 1, topic: topic)
        }
    }

    @MainActor
    static func topics(for pillar: Pillar) -> [Topic] {
        switch pillar {
        case .nutrition: return nutritionTopics
        case .training: return trainingTopics
        case .sleep: return sleepTopics
        case .face: return faceTopics
        case .continuousHabits: return [continuousHabitsTopic]
        }
    }

    @MainActor
    static var nutritionSources: [(label: String, url: String)] {
        [
            (AppCopy.t("OMS — sel et potassium", en: "WHO — salt and potassium"), "https://www.who.int/news/item/31-01-2013-who-issues-new-guidance-on-dietary-salt-and-potassium"),
            (AppCopy.t("Healthline — alimentation et visage", en: "Healthline — food and face"), "https://www.healthline.com/health/food-nutrition/face-bloating-morning"),
            (AppCopy.t("NCBI — apport en potassium", en: "NCBI — potassium intake"), "https://www.ncbi.nlm.nih.gov/books/NBK132453/")
        ]
    }
}
