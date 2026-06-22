import Foundation

/// Contenu éducatif debloat — nutrition, entraînement, sommeil, visage.
/// Basé sur OMS (Na/K), littérature rétention hydrique et recommandations Process.
enum HealthDebloatGuide {

    enum Pillar: String, CaseIterable, Identifiable {
        case nutrition
        case training
        case sleep
        case face

        var id: String { rawValue }

        var title: String {
            switch self {
            case .nutrition: return "Nutrition"
            case .training: return "Entraînement"
            case .sleep: return "Sommeil"
            case .face: return "Visage"
            }
        }

        var icon: String {
            switch self {
            case .nutrition: return "leaf.fill"
            case .training: return "figure.run"
            case .sleep: return "bed.double.fill"
            case .face: return "face.smiling"
            }
        }

        var tagline: String {
            switch self {
            case .nutrition:
                return "L’équilibre sodium · potassium et l’hydratation — le cœur du debloat."
            case .training:
                return "Circulation, drainage lymphatique et dépense quotidienne."
            case .sleep:
                return "Qualité, position et timing — ce qui se joue la nuit."
            case .face:
                return "Scan, froid et massage — mesurer et relancer la circulation."
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
    }

    enum TopicAccent {
        case sodiumPotassium
        case hydration
        case triggers
        case action
        case myth
    }

    // MARK: - Nutrition (focus debloat visage)

    static let nutritionIntro = """
    Un visage gonflé le matin, ce n’est pas toujours de la graisse. \
    Souvent, c’est de l’eau retenue dans les tissus — surtout autour des yeux et des joues. \
    La bonne nouvelle : ce type de gonflement réagit vite à ce que tu manges et bois, \
    surtout la veille et le soir.
    """

    static let nutritionTopics: [Topic] = [
        Topic(
            id: "mechanism",
            title: "Ce qui se passe vraiment",
            summary: "L’eau suit le sodium. Le potassium aide à l’évacuer.",
            body: """
            Tes cellules régulent leur volume avec deux minéraux : le sodium (sel) et le potassium. \
            Quand tu consommes beaucoup de sodium — surtout d’un coup, le soir — ton corps retient \
            de l’eau pour diluer l’excès. Résultat : visage plus plein au réveil.

            Le potassium joue le rôle inverse : il aide les reins à excréter le sodium excédentaire. \
            Problème courant : régimes riches en plats transformés (beaucoup de sel, peu de potassium) \
            = rétention hydrique favorisée.
            """,
            bullets: [
                "Gonflement ≠ graisse faciale dans la majorité des cas quotidiens",
                "L’effet se voit surtout 6 à 12 h après un repas très salé ou alcoolisé",
                "Corriger l’équilibre alimentaire agit plus vite qu’un « hack » cosmétique"
            ],
            accent: .sodiumPotassium
        ),
        Topic(
            id: "sodium-potassium",
            title: "Balance sodium · potassium",
            summary: "Viser moins de sel caché, plus de végétaux et légumineuses.",
            body: """
            L’OMS recommande aux adultes moins de 2 000 mg de sodium par jour (≈ 5 g de sel) \
            et au moins 3 500 mg de potassium via les aliments. En pratique, beaucoup dépassent \
            largement le sodium (souvent 3 000–3 400 mg) tout en mangeant peu de potassium.

            L’objectif n’est pas de « zéro sel » — c’est d’équilibrer : moins de sodium ajouté \
            et caché, plus de sources naturelles de potassium à chaque repas.
            """,
            bullets: [
                "Sources K+ : épinards, pomme de terre, avocat, haricots, banane, saumon",
                "Pièges Na+ : charcuterie, plats préparés, sauces (soja, nuggets), restauration rapide",
                "Lis les étiquettes : le sel se cache aussi dans le pain, les soupes, les fromages"
            ],
            accent: .sodiumPotassium
        ),
        Topic(
            id: "hydration",
            title: "Hydratation — le paradoxe",
            summary: "Boire régulièrement évite que le corps retienne par défaut.",
            body: """
            Manquer d’eau pousse paradoxalement le corps à retenir les fluides. \
            Une hydratation régulière sur la journée aide les reins à filtrer le sodium \
            et limite le gonflement.

            Répartis ta consommation : un gros verre au réveil, puis des prises régulières \
            avant d’avoir soif. Évite de compenser uniquement le soir — trop tard pour \
            limiter le gonflement du lendemain matin.
            """,
            bullets: [
                "Cible Process : \(ProcessDailyTargets.hydrationLabel) répartis sur la journée",
                ProcessHydrationGuide.morningLine,
                "Limite alcool et excès de caféine — ils déshydratent puis favorisent la rétention"
            ],
            accent: .hydration
        ),
        Topic(
            id: "triggers",
            title: "Ce qui gonfle le plus le visage",
            summary: "Timing et qualité comptent autant que la quantité.",
            body: """
            Certains aliments et habitudes amplifient la rétention, surtout en fin de journée :

            • Repas très salés le soir → gonflement visible au réveil
            • Alcool → déshydratation puis rebond inflammatoire et rétention
            • Dîner riche en glucides raffinés → chaque gramme de glycogène retient ~3–4 g d’eau
            • Ultra-transformés → sodium élevé + faible potassium + inflammation

            Le même repas à midi aura souvent moins d’impact qu’à 21 h, car tu as la journée \
            pour bouger, transpirer et éliminer.
            """,
            bullets: [
                "Priorise un dîner plus léger en sel, plus riche en légumes",
                "Favorise glucides complexes le jour, pas un gros plat de pâtes/blé blanc tard",
                "MSG et sauces industrielles = sodium concentré — même effet que le sel de table"
            ],
            accent: .triggers
        ),
        Topic(
            id: "daily-plan",
            title: "Ton plan concret (Process)",
            summary: "Simple, répétable — c’est la régularité qui change le visage.",
            body: """
            Pas besoin de régime extrême. Une routine alimentaire stable bat une semaine parfaite \
            suivie de trois jours de relâchement.
            """,
            bullets: [
                "\(ProcessDailyTargets.hydrationLitersPerDay) L d’eau · \(ProcessHydrationGuide.rankedWaters.first?.name ?? "eau") ou équivalent",
                "Légumes ou fruit à chaque repas (potassium + fibres anti-inflammatoires)",
                "Repas du soir : protéine + légumes, sel modéré — pas de festin salé tard",
                "Caféine coupée à \(ProcessDailyTargets.caffeineCutoffHour) h pour protéger le sommeil (lié au gonflement matinal)",
                "\(ProcessDailyTargets.chewsPerBite) mâchées par bouchée — digestion lente = moins de ballonnements"
            ],
            accent: .action
        ),
        Topic(
            id: "myths",
            title: "Mythes à éviter",
            summary: "Ce qui ne résout pas le problème à la source.",
            body: """
            Le « cortisol face » viral exagère l’effet du stress quotidien. \
            Un gonflement visible vient surtout de sel, alcool, sommeil et position — \
            pas d’un pic de cortisol passager.

            Couper tout le sel ou prendre des diurétiques / potassium en complément sans suivi \
            médical peut empirer l’équilibre électrolytique et la rétention.
            """,
            bullets: [
                "Gua sha, glace, massage : utiles en complément, pas en remplacement de l’alimentation",
                "La graisse faciale ne disparaît pas en 48 h — elle suit la perte de masse grasse globale",
                "Gonflement persistant, unilatéral ou brutal → consulter (thyroïde, rein, allergie…)"
            ],
            accent: .myth
        )
    ]

    // MARK: - Autres piliers (résumés actionnables)

    static let trainingTopics: [Topic] = [
        Topic(
            id: "steps",
            title: "Pas quotidiens",
            summary: "\(ProcessDailyTargets.dailySteps.formatted()) pas — circulation et drainage.",
            body: "La marche active la circulation veineuse et lymphatique. Une journée sédentaire favorise la stagnation des fluides, y compris au visage.",
            bullets: [
                "Objectif Process : \(ProcessDailyTargets.dailySteps.formatted()) pas/jour",
                "\(ProcessDailyTargets.outdoorWalkSessionsPerWeek) sorties marche extérieure / semaine",
                "\(ProcessDailyTargets.restDaysPerWeek) jours de repos actif / semaine"
            ],
            accent: .action
        ),
        Topic(
            id: "lymph",
            title: "Massage lymphatique",
            summary: "\(ProcessDailyTargets.lymphFaceMassageMinutes) min — relance le drainage, pas la graisse.",
            body: "Le massage facial aide le liquide interstitiel à circuler vers les ganglions. C’est un outil complémentaire, pas une solution seule.",
            bullets: [
                "\(ProcessDailyTargets.lymphFaceMassageMinutes) minute le matin, mouvements vers les oreilles puis le cou",
                "Combine avec le scan et la douche froide pour un effet immédiat visible"
            ],
            accent: .action
        )
    ]

    static let sleepTopics: [Topic] = [
        Topic(
            id: "duration",
            title: "Durée et régularité",
            summary: "\(ProcessDailyTargets.sleepHours) h — le sommeil régule l’eau et le sel.",
            body: "Un sommeil court ou irrégulier perturbe la régulation hydrique et favorise le gonflement matinal. Vise une plage horaire stable ± \(ProcessDailyTargets.sleepScheduleMarginMinutes) min.",
            bullets: [
                "Cible : \(ProcessDailyTargets.sleepHours) h par nuit",
                "Horaires de coucher/réveil réguliers, même le week-end"
            ],
            accent: .action
        ),
        Topic(
            id: "position",
            title: "Position et environnement",
            summary: "Dos, tête surélevée, chambre fraîche.",
            body: "Dormir sur le ventre ou le côté favorise l’accumulation de fluides vers le visage. Une chambre autour de \(ProcessDailyTargets.bedroomTempCelsius) °C améliore la qualité du sommeil profond.",
            bullets: [
                "Sur le dos, oreiller légèrement plus haut",
                "Couvre-feu écrans \(ProcessDailyTargets.screenCurfewMinutes) min avant le coucher",
                "Température chambre ~\(ProcessDailyTargets.bedroomTempCelsius) °C"
            ],
            accent: .action
        )
    ]

    static let faceTopics: [Topic] = [
        Topic(
            id: "scan",
            title: "Scan quotidien",
            summary: "Mesurer pour voir la corrélation avec ton protocole.",
            body: "Le scan Process te permet de suivre l’évolution et de relier gonflement, sommeil et habitudes. C’est un feedback, pas un diagnostic médical.",
            bullets: [
                "\(ProcessDailyTargets.faceScanSeconds) s chaque matin, même lumière",
                "Compare avec ton journal (sel, alcool, sommeil) pour comprendre tes déclencheurs"
            ],
            accent: .action
        ),
        Topic(
            id: "cold",
            title: "Froid et circulation",
            summary: "\(ProcessDailyTargets.coldFaceRinseSeconds) s d’eau froide — vasoconstriction temporaire.",
            body: "Le froid resserre les vaisseaux superficiels et donne un effet « dégonflé » immédiat. Ça ne remplace pas la nutrition, mais c’est un bon levier matinal.",
            bullets: [
                "Rinçage visage \(ProcessDailyTargets.coldFaceRinseSeconds) s après le réveil",
                "Combine avec \(ProcessDailyTargets.morningLightMinutes) min de lumière naturelle le matin"
            ],
            accent: .action
        )
    ]

    static func topics(for pillar: Pillar) -> [Topic] {
        switch pillar {
        case .nutrition: return nutritionTopics
        case .training: return trainingTopics
        case .sleep: return sleepTopics
        case .face: return faceTopics
        }
    }

    static let nutritionSources: [(label: String, url: String)] = [
        ("OMS — sel et potassium", "https://www.who.int/news/item/31-01-2013-who-issues-new-guidance-on-dietary-salt-and-potassium"),
        ("Healthline — alimentation et visage", "https://www.healthline.com/health/food-nutrition/face-bloating-morning"),
        ("NCBI — apport en potassium", "https://www.ncbi.nlm.nih.gov/books/NBK132453/")
    ]
}
