import Foundation

/// Catalogue curaté — visage dégonflé (↓Na · ↑K · ↑Mg). Valeurs ≈ / 100 g.
enum DebloatFoodCatalog {
    static let all: [DebloatFoodItem] = preferFoods + moderateFoods + avoidFoods

    static var preferFoods: [DebloatFoodItem] {
        heroAndPrefer
    }

    static func item(id: String) -> DebloatFoodItem? {
        byID[id]
    }

    static func item(matchingName name: String) -> DebloatFoodItem? {
        let key = DebloatFoodNameNormalizer.normalize(name)
        if let exact = byNormalizedName[key] { return exact }
        return all.first { food in
            let foodKey = DebloatFoodNameNormalizer.normalize(food.name)
            return key.contains(foodKey) || foodKey.contains(key)
        }
    }

    static func foods(tier: DebloatFoodTier) -> [DebloatFoodItem] {
        all.filter { $0.tier == tier }.sorted { $0.debloatScore > $1.debloatScore }
    }

    static func foods(in categories: [DebloatFoodCategory], excludingAvoid: Bool = true) -> [DebloatFoodItem] {
        all.filter { categories.contains($0.category) && (!excludingAvoid || $0.tier != .avoid) }
            .sorted { $0.debloatScore > $1.debloatScore }
    }

    static func sections(for tab: DebloatFoodHubTab) -> [DebloatFoodCatalogSection] {
        switch tab {
        case .prefer:
            return group(preferFoods.filter { $0.tier == .hero || $0.tier == .prefer })
        case .avoid:
            return group(avoidFoods + moderateFoods)
        case .tastes:
            return []
        }
    }

    static func swapItems(for food: DebloatFoodItem) -> [DebloatFoodItem] {
        food.swaps.compactMap { byID[$0] }
    }

    // MARK: - Private index

    private static let byID: [String: DebloatFoodItem] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    private static let byNormalizedName: [String: DebloatFoodItem] = Dictionary(
        uniqueKeysWithValues: all.map { (DebloatFoodNameNormalizer.normalize($0.name), $0) }
    )

    private static func group(_ foods: [DebloatFoodItem]) -> [DebloatFoodCatalogSection] {
        let order = DebloatFoodCategory.allCases
        return order.compactMap { category in
            let items = foods.filter { $0.category == category }
                .sorted { lhs, rhs in
                    if lhs.tier != rhs.tier {
                        return tierRank(lhs.tier) < tierRank(rhs.tier)
                    }
                    return lhs.debloatScore > rhs.debloatScore
                }
            guard !items.isEmpty else { return nil }
            return DebloatFoodCatalogSection(id: category.rawValue, category: category, items: items)
        }
    }

    private static func tierRank(_ tier: DebloatFoodTier) -> Int {
        switch tier {
        case .hero: return 0
        case .prefer: return 1
        case .moderate: return 2
        case .avoid: return 3
        }
    }

    // MARK: - Builder

    private static func food(
        _ id: String,
        _ name: String,
        _ category: DebloatFoodCategory,
        _ tier: DebloatFoodTier,
        k: Double?,
        na: Double?,
        mg: Double?,
        why: String,
        tags: [String] = [],
        swaps: [String] = [],
        portion: String? = nil
    ) -> DebloatFoodItem {
        let score = DebloatFoodScoreEngine.score(
            potassiumMgPer100g: k,
            sodiumMgPer100g: na,
            magnesiumMgPer100g: mg,
            tier: tier,
            tags: tags
        )
        return DebloatFoodItem(
            id: id,
            name: name,
            category: category,
            tier: tier,
            potassiumMgPer100g: k,
            sodiumMgPer100g: na,
            magnesiumMgPer100g: mg,
            debloatScore: score,
            whyItHelpsOrHurts: why,
            tags: tags,
            swaps: swaps,
            portionHint: portion
        )
    }
}

struct DebloatFoodCatalogSection: Identifiable, Hashable {
    let id: String
    let category: DebloatFoodCategory
    let items: [DebloatFoodItem]

    @MainActor
    var title: String { category.sectionTitle }
}

enum DebloatFoodHubMode: String, CaseIterable, Identifiable {
    case foods
    case recipes

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .foods: return AppCopy.t("Aliments", en: "Foods")
        case .recipes: return AppCopy.t("Recettes", en: "Recipes")
        }
    }
}

enum DebloatFoodHubTab: String, CaseIterable, Identifiable {
    case prefer
    case avoid
    case tastes

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .prefer: return AppCopy.t("Privilégier", en: "Prefer")
        case .avoid: return AppCopy.t("Éviter", en: "Avoid")
        case .tastes: return AppCopy.t("Mes goûts", en: "My tastes")
        }
    }
}

// MARK: - Catalogue data

private extension DebloatFoodCatalog {
    static let heroAndPrefer: [DebloatFoodItem] = [
        // Légumes — concombre n°1
        food("concombre", "Concombre", .legumes, .hero, k: 147, na: 2, mg: 13,
             why: "N°1 anti-gonflement : eau + K, quasi zéro sodium.",
             tags: ["soir-safe", "high-K", "drainant"], portion: "1/2 à 1 concombre"),
        food("courgette", "Courgette", .legumes, .hero, k: 261, na: 8, mg: 18,
             why: "Légume drainant, parfait le soir pour un visage plus net.",
             tags: ["soir-safe", "high-K"], portion: "200 g cuite"),
        food("asperge", "Asperge", .legumes, .prefer, k: 202, na: 2, mg: 14,
             why: "Diurétique naturel, aide à évacuer l’eau en excès.",
             tags: ["soir-safe", "drainant"], portion: "1 botte"),
        food("celeri", "Céleri branche", .legumes, .prefer, k: 260, na: 80, mg: 11,
             why: "Croquant drainant — garde le sodium bas en le mangeant nature.",
             tags: ["soir-safe", "drainant"], portion: "2–3 branches"),
        food("fenouil", "Fenouil", .legumes, .prefer, k: 414, na: 52, mg: 17,
             why: "Riche en K, digeste, excellent pour limiter la rétention.",
             tags: ["soir-safe", "high-K"], portion: "1 bulbe"),
        food("artichaut", "Artichaut", .legumes, .prefer, k: 370, na: 94, mg: 60,
             why: "Soutient le drainage et apporte du magnésium utile.",
             tags: ["soir-safe"], portion: "1 artichaut"),
        food("poireau", "Poireau", .legumes, .prefer, k: 180, na: 20, mg: 28,
             why: "Base soupe anti-rétention, faible en sodium si non salée.",
             tags: ["soir-safe"], portion: "1 poireau"),
        food("epinards", "Épinards", .legumes, .hero, k: 558, na: 79, mg: 79,
             why: "Triple levier : potassium + magnésium + volume drainant.",
             tags: ["soir-safe", "high-K"], portion: "150 g cuits"),
        food("blettes", "Blettes", .legumes, .prefer, k: 379, na: 213, mg: 81,
             why: "Feuilles riches en K/Mg — rincer et cuire sans sel.",
             tags: ["high-K"], portion: "200 g"),
        food("tomate", "Tomate", .legumes, .prefer, k: 237, na: 5, mg: 11,
             why: "Fraîche ou concentrée nature : boost K sans sel ajouté.",
             tags: ["soir-safe", "high-K"], swaps: ["tomate-concentree"], portion: "2 tomates"),
        food("tomate-concentree", "Tomate concentrée nature", .potassium, .hero, k: 1014, na: 58, mg: 68,
             why: "Concentrateur de potassium — choisir sans sel ajouté.",
             tags: ["high-K", "soir-safe"], portion: "2 c. à s."),
        food("poivron", "Poivron", .legumes, .prefer, k: 211, na: 4, mg: 12,
             why: "Couleur, croquant, sodium quasi nul.",
             tags: ["soir-safe"], portion: "1 poivron"),
        food("radis-noir", "Radis noir", .legumes, .prefer, k: 233, na: 39, mg: 25,
             why: "Drainant classique, utile en cure courte visage.",
             tags: ["drainant"], portion: "quelques tranches"),
        food("aubergine", "Aubergine", .legumes, .prefer, k: 229, na: 2, mg: 14,
             why: "Cuite sans sel : volume satiating et K correct.",
             tags: ["soir-safe"], portion: "1 aubergine"),
        food("carotte", "Carotte", .legumes, .prefer, k: 320, na: 69, mg: 12,
             why: "Base stable, utile en soupe ou râpée sans vinaigrette salée.",
             tags: ["soir-safe"], portion: "2 carottes"),
        food("brocoli", "Brocoli", .legumes, .prefer, k: 316, na: 33, mg: 21,
             why: "K + fibres — portions modérées si digestion sensible.",
             tags: ["soir-safe", "high-K"], portion: "200 g"),
        food("choux-bruxelles", "Choux de Bruxelles", .legumes, .prefer, k: 389, na: 25, mg: 23,
             why: "Potassium solide ; vapeur + herbes plutôt que beurre salé.",
             tags: ["high-K"], portion: "150 g"),
        food("haricots-verts", "Haricots verts", .legumes, .prefer, k: 211, na: 6, mg: 25,
             why: "Accompagnement soir-safe, sodium négligeable.",
             tags: ["soir-safe"], portion: "200 g"),
        food("roquette", "Roquette", .legumes, .prefer, k: 369, na: 27, mg: 47,
             why: "Salade high-K ; citron + huile, zéro sel.",
             tags: ["soir-safe", "high-K"], portion: "1 bol"),
        food("mache", "Mâche", .legumes, .prefer, k: 459, na: 4, mg: 22,
             why: "Feuille douce très riche en potassium.",
             tags: ["soir-safe", "high-K"], portion: "1 bol"),
        food("betterave", "Betterave", .legumes, .prefer, k: 325, na: 78, mg: 23,
             why: "Cuite nature (pas en vinaigrette industrielle).",
             tags: ["high-K"], portion: "1 betterave"),
        food("champignons", "Champignons", .legumes, .prefer, k: 318, na: 5, mg: 9,
             why: "Goût umami sans sel — allié anti-rétention.",
             tags: ["soir-safe", "high-K"], portion: "150 g"),

        // Fruits
        food("pasteque", "Pastèque", .fruits, .hero, k: 112, na: 1, mg: 10,
             why: "Eau + K : effet drainant rapide sur le visage.",
             tags: ["soir-safe", "high-K", "tiktok-trend"], portion: "2 parts"),
        food("melon", "Melon", .fruits, .hero, k: 267, na: 16, mg: 12,
             why: "Fruit drainant dense en potassium.",
             tags: ["soir-safe", "high-K"], portion: "1/2 melon"),
        food("ananas", "Ananas", .fruits, .hero, k: 109, na: 1, mg: 12,
             why: "Bromélaïne + drainage — frais ou jus 100 % modéré.",
             tags: ["soir-safe", "tiktok-trend", "high-K"], portion: "2 parts"),
        food("citron", "Citron", .fruits, .prefer, k: 138, na: 2, mg: 8,
             why: "Remplace le sel : acidité + rituels eau citronnée.",
             tags: ["soir-safe"], portion: "1/2 citron"),
        food("orange", "Orange", .fruits, .prefer, k: 181, na: 0, mg: 10,
             why: "Hydratation et K sans sodium.",
             tags: ["soir-safe"], portion: "1 orange"),
        food("pamplemousse", "Pamplemousse", .fruits, .prefer, k: 135, na: 0, mg: 9,
             why: "Léger, drainant, utile le matin.",
             tags: ["soir-safe"], portion: "1/2 fruit"),
        food("citron-vert", "Citron vert", .fruits, .prefer, k: 102, na: 2, mg: 6,
             why: "Assaisonnement anti-sel pour bols et poissons.",
             tags: ["soir-safe"], portion: "1/2 fruit"),
        food("kiwi", "Kiwi", .fruits, .prefer, k: 312, na: 3, mg: 17,
             why: "Potassium élevé dans un petit volume.",
             tags: ["soir-safe", "high-K"], portion: "2 kiwis"),
        food("fraises", "Fraises", .fruits, .prefer, k: 153, na: 1, mg: 13,
             why: "Fruit eau + K, collation visage-friendly.",
             tags: ["soir-safe"], portion: "150 g"),
        food("framboises", "Framboises", .fruits, .prefer, k: 151, na: 1, mg: 22,
             why: "Fibres + K, peu de sodium.",
             tags: ["soir-safe"], portion: "125 g"),
        food("myrtilles", "Myrtilles", .fruits, .prefer, k: 77, na: 1, mg: 6,
             why: "Antioxydants utiles, sodium négligeable.",
             tags: ["soir-safe"], portion: "125 g"),
        food("mures", "Mûres", .fruits, .prefer, k: 162, na: 1, mg: 20,
             why: "Baies drainantes, snack simple.",
             tags: ["soir-safe"], portion: "125 g"),
        food("banane", "Banane", .fruits, .hero, k: 358, na: 1, mg: 27,
             why: "Source K star — idéale post-sport / matin.",
             tags: ["high-K"], portion: "1 banane"),
        food("avocat", "Avocat", .fruits, .hero, k: 485, na: 7, mg: 29,
             why: "K très élevé, remplace les sauces salées.",
             tags: ["high-K", "soir-safe"], portion: "1/2 avocat"),
        food("pomme", "Pomme", .fruits, .prefer, k: 107, na: 1, mg: 5,
             why: "Base neutre, utile en collation sans sel.",
             tags: ["soir-safe"], portion: "1 pomme"),
        food("figue", "Figue", .fruits, .prefer, k: 232, na: 1, mg: 17,
             why: "Fraîche ou sèche non sucrée : boost K.",
             tags: ["high-K"], portion: "2–3 figues"),
        food("abricot", "Abricot", .fruits, .prefer, k: 259, na: 1, mg: 10,
             why: "Frais ou sec non sucré — potassium concentré.",
             tags: ["high-K"], swaps: ["abricots-secs"], portion: "3 abricots"),
        food("abricots-secs", "Abricots secs", .potassium, .hero, k: 1162, na: 10, mg: 32,
             why: "Concentrateur K — portion petite, non sucrés.",
             tags: ["high-K"], portion: "4–5 pièces"),
        food("peche", "Pêche / nectarine", .fruits, .prefer, k: 190, na: 0, mg: 9,
             why: "Fruit eau de saison, sodium nul.",
             tags: ["soir-safe"], portion: "1–2 fruits"),
        food("raisins-secs", "Raisins secs", .potassium, .prefer, k: 749, na: 11, mg: 32,
             why: "K dense — éviter les versions salées/enrobées.",
             tags: ["high-K"], portion: "une poignée"),
        food("dattes", "Dattes", .potassium, .prefer, k: 656, na: 1, mg: 43,
             why: "K + Mg ; portion contrôlée, non fourrées.",
             tags: ["high-K"], portion: "2 dattes"),

        // Potassium extras
        food("patate-douce", "Patate douce", .potassium, .hero, k: 337, na: 55, mg: 25,
             why: "Féculent high-K : vapeur/four, peau si possible.",
             tags: ["high-K", "soir-safe"], swaps: ["pain-baguette"], portion: "1 moyenne"),
        food("pomme-de-terre", "Pomme de terre", .potassium, .hero, k: 421, na: 6, mg: 23,
             why: "Avec peau, vapeur/four : bombe potassium anti-rétention.",
             tags: ["high-K", "soir-safe"], swaps: ["pain-baguette"], portion: "1–2 pommes de terre"),
        food("lentilles", "Lentilles", .potassium, .prefer, k: 369, na: 2, mg: 36,
             why: "K + protéines ; rincer si conserve.",
             tags: ["high-K"], portion: "150 g cuites"),
        food("haricots-blancs", "Haricots blancs", .potassium, .prefer, k: 561, na: 2, mg: 63,
             why: "Très haut K/Mg — version nature rincée.",
             tags: ["high-K"], portion: "150 g cuits"),
        food("haricots-rouges", "Haricots rouges", .potassium, .prefer, k: 403, na: 2, mg: 45,
             why: "Légumineuse high-K, rincer les conserves.",
             tags: ["high-K"], portion: "150 g cuits"),
        food("pois-chiches", "Pois chiches", .potassium, .prefer, k: 291, na: 7, mg: 48,
             why: "Base bowl sans sel ; houmous maison sans bicarbonate salé.",
             tags: ["high-K"], portion: "150 g cuits"),
        food("pois-casses", "Pois cassés", .potassium, .prefer, k: 362, na: 2, mg: 35,
             why: "Soupe maison non salée = drainage progressif.",
             tags: ["high-K"], portion: "150 g cuits"),
        food("amandes", "Amandes non salées", .magnesium, .prefer, k: 733, na: 1, mg: 270,
             why: "Mg + K — collation anti-rétention (non salées).",
             tags: ["high-K"], swaps: ["cacahuetes-salees"], portion: "20–25 g"),
        food("pistaches", "Pistaches non salées", .magnesium, .prefer, k: 1025, na: 1, mg: 121,
             why: "K exceptionnel si non salées.",
             tags: ["high-K"], swaps: ["cacahuetes-salees"], portion: "20 g"),

        // Magnésium
        food("graines-courge", "Graines de courge", .magnesium, .hero, k: 809, na: 7, mg: 592,
             why: "Meilleur levier Mg alimentaire pour l’équilibre hydrique.",
             tags: ["high-K"], portion: "20 g"),
        food("noix-cajou", "Noix de cajou", .magnesium, .prefer, k: 660, na: 12, mg: 292,
             why: "Mg dense — version nature uniquement.",
             tags: [], swaps: ["cacahuetes-salees"], portion: "20 g"),
        food("noix-bresil", "Noix du Brésil", .magnesium, .prefer, k: 659, na: 3, mg: 376,
             why: "Mg + sélénium ; 2–3 noix suffisent.",
             tags: [], portion: "2–3 noix"),
        food("chia", "Graines de chia", .magnesium, .prefer, k: 407, na: 16, mg: 335,
             why: "Mg + fibres ; pudding nature sans sirop.",
             tags: [], portion: "15 g"),
        food("lin", "Graines de lin", .magnesium, .prefer, k: 813, na: 30, mg: 392,
             why: "Mg utile ; moudre pour assimilation.",
             tags: [], portion: "1 c. à s."),
        food("sesame", "Graines de sésame", .magnesium, .prefer, k: 468, na: 11, mg: 351,
             why: "Mg sur salades — non salé.",
             tags: [], portion: "1 c. à s."),
        food("tournesol", "Graines de tournesol", .magnesium, .prefer, k: 645, na: 9, mg: 325,
             why: "Collation Mg si non salées.",
             tags: [], portion: "20 g"),
        food("chocolat-noir", "Chocolat noir ≥ 70 %", .magnesium, .prefer, k: 559, na: 20, mg: 228,
             why: "Mg plaisir contrôlé — éviter lait/sucré.",
             tags: [], swaps: ["chocolat-lait"], portion: "20 g"),
        food("cacao", "Cacao non sucré", .magnesium, .prefer, k: 1524, na: 21, mg: 499,
             why: "Mg ultra-dense en poudre nature.",
             tags: ["high-K"], portion: "1 c. à s."),
        food("flocons-avoine", "Flocons d’avoine", .magnesium, .prefer, k: 429, na: 2, mg: 177,
             why: "Petit-déj Mg ; nature, pas sachets aromatisés.",
             tags: [], swaps: ["pain-mie"], portion: "40–50 g"),
        food("quinoa", "Quinoa", .magnesium, .prefer, k: 563, na: 5, mg: 197,
             why: "Alternative pain/riz blanc : K + Mg.",
             tags: ["high-K"], swaps: ["pain-baguette"], portion: "80 g crus"),
        food("sarrasin", "Sarrasin", .magnesium, .prefer, k: 460, na: 1, mg: 231,
             why: "Sans gluten, bon Mg, cuisson sans sel.",
             tags: [], swaps: ["pain-baguette"], portion: "80 g crus"),
        food("noisettes", "Noisettes", .magnesium, .prefer, k: 680, na: 0, mg: 163,
             why: "Mg + K, collation non salée.",
             tags: [], portion: "20 g"),

        // Protéines
        food("poulet", "Poulet (sans peau)", .protein, .prefer, k: 256, na: 74, mg: 25,
             why: "Protéine propre — rôti froid > charcuterie.",
             tags: ["soir-safe"], swaps: ["jambon-blanc", "saucisson"], portion: "150–180 g"),
        food("dinde", "Dinde (sans peau)", .protein, .prefer, k: 242, na: 49, mg: 24,
             why: "Alternative blanche low-Na à la charcuterie.",
             tags: ["soir-safe"], swaps: ["jambon-blanc"], portion: "150 g"),
        food("oeufs", "Œufs", .protein, .prefer, k: 138, na: 142, mg: 12,
             why: "Protéine stable ; cuisson sans sel.",
             tags: ["soir-safe"], portion: "2 œufs"),
        food("saumon", "Saumon (frais)", .protein, .hero, k: 363, na: 59, mg: 29,
             why: "K + oméga-3 — frais, jamais fumé pour le visage.",
             tags: ["high-K", "soir-safe"], swaps: ["saumon-fume"], portion: "140 g"),
        food("sardines", "Sardines (nature)", .protein, .prefer, k: 397, na: 100, mg: 39,
             why: "K solide ; choisir nature à l’eau/huile, égoutter.",
             tags: ["high-K"], swaps: ["anchois"], portion: "1 boîte nature"),
        food("maquereau", "Maquereau", .protein, .prefer, k: 314, na: 90, mg: 33,
             why: "Poisson gras utile ; éviter versions fumées.",
             tags: ["soir-safe"], portion: "140 g"),
        food("thon", "Thon (nature)", .protein, .prefer, k: 237, na: 50, mg: 30,
             why: "Nature à l’eau rincé ; skip sauce soja.",
             tags: ["soir-safe"], portion: "120 g"),
        food("poisson-blanc", "Poisson blanc", .protein, .prefer, k: 350, na: 78, mg: 28,
             why: "Cabillaud/lieu : protéine soir-safe low-Na.",
             tags: ["soir-safe", "high-K"], portion: "160 g"),
        food("yaourt-nature", "Yaourt nature", .protein, .prefer, k: 255, na: 70, mg: 19,
             why: "K lacté doux — nature, pas aromatisé sucré.",
             tags: ["soir-safe", "high-K"], swaps: ["fromage-affine"], portion: "1 pot"),
        food("fromage-blanc", "Fromage blanc", .protein, .prefer, k: 141, na: 40, mg: 11,
             why: "Texture satiante, sodium modéré si nature 0%.",
             tags: ["soir-safe"], portion: "150 g"),
        food("kefir", "Kéfir nature", .protein, .prefer, k: 164, na: 40, mg: 14,
             why: "Option fermentée douce — nature uniquement.",
             tags: ["soir-safe"], portion: "200 ml"),
        food("tofu", "Tofu", .protein, .prefer, k: 237, na: 7, mg: 58,
             why: "Protéine végétale ; nature, pas mariné salé.",
             tags: ["soir-safe"], portion: "150 g"),
        food("tempeh", "Tempeh", .protein, .prefer, k: 412, na: 9, mg: 81,
             why: "K/Mg intéressants — cuisson herbes/citron.",
             tags: ["high-K"], portion: "120 g"),

        // Herbes
        food("persil", "Persil", .herbs, .hero, k: 554, na: 56, mg: 50,
             why: "Diurétique star — frais en fin de plat.",
             tags: ["drainant", "soir-safe", "tiktok-trend"], portion: "1/2 bouquet"),
        food("gingembre", "Gingembre", .herbs, .prefer, k: 415, na: 13, mg: 43,
             why: "Anti-rétention + digestion ; infusion ou râpé.",
             tags: ["soir-safe", "tiktok-trend"], portion: "1 cm frais"),
        food("cumin", "Cumin", .herbs, .prefer, k: 1788, na: 168, mg: 366,
             why: "Remplace une partie du sel par la chaleur aromatique.",
             tags: [], portion: "1 c. à c."),
        food("ail", "Ail", .herbs, .prefer, k: 401, na: 17, mg: 25,
             why: "Goût fort sans saler — modérer si digestion fragile.",
             tags: [], portion: "1 gousse"),
        food("oignon", "Oignon", .herbs, .prefer, k: 146, na: 4, mg: 10,
             why: "Base aromatique ; portions modérées si ballonnements.",
             tags: [], portion: "1/2 oignon"),
        food("basilic", "Basilic", .herbs, .prefer, k: 295, na: 4, mg: 64,
             why: "Fraîcheur anti-sel sur tomates et poissons.",
             tags: ["soir-safe"], portion: "quelques feuilles"),
        food("thym", "Thym", .herbs, .prefer, k: 609, na: 55, mg: 160,
             why: "Assaisonnement Mg/K — oublié le cube de bouillon.",
             tags: ["soir-safe"], swaps: ["bouillon-cube"], portion: "1 pincée"),
        food("origan", "Origan", .herbs, .prefer, k: 1260, na: 15, mg: 270,
             why: "Aromate puissant pour oublier le sel.",
             tags: [], portion: "1 pincée"),
        food("menthe", "Menthe", .herbs, .prefer, k: 458, na: 30, mg: 63,
             why: "Eau concombre-menthe : rituel drainant.",
             tags: ["soir-safe", "tiktok-trend"], portion: "quelques feuilles"),
        food("herbes-provence", "Herbes de Provence", .herbs, .prefer, k: 900, na: 40, mg: 200,
             why: "Mélange anti-sel pour viandes et légumes.",
             tags: ["soir-safe"], portion: "1 c. à c."),
        food("vinaigre-cidre", "Vinaigre de cidre", .herbs, .prefer, k: 73, na: 5, mg: 5,
             why: "Acidité modérée en vinaigrette sans sel.",
             tags: ["soir-safe"], portion: "1 c. à s."),

        // Boissons
        food("eau-plate", "Eau plate", .drinks, .hero, k: 0, na: 2, mg: 2,
             why: "Base absolue : 1,5–2,5 L/jour pour drainer.",
             tags: ["soir-safe"], portion: "2 L / jour"),
        food("hepar", "Hépar", .drinks, .prefer, k: 0, na: 14, mg: 119,
             why: "Eau minérale riche Mg, pauvre Na — alliée visage.",
             tags: ["soir-safe", "tiktok-trend"], portion: "1 bouteille"),
        food("contrex", "Contrex", .drinks, .prefer, k: 0, na: 9, mg: 84,
             why: "Mg élevé / Na bas — drainage minéral.",
             tags: ["soir-safe"], portion: "1 bouteille"),
        food("rozana", "Rozana", .drinks, .prefer, k: 0, na: 8, mg: 160,
             why: "Profil Mg fort, sodium bas.",
             tags: ["soir-safe"], portion: "1 bouteille"),
        food("courmayeur", "Courmayeur", .drinks, .prefer, k: 0, na: 1, mg: 52,
             why: "Eau très pauvre en sodium.",
             tags: ["soir-safe"], portion: "1 bouteille"),
        food("the-vert", "Thé vert", .drinks, .prefer, k: 27, na: 1, mg: 3,
             why: "Diurétique doux — éviter après 15 h si sommeil fragile.",
             tags: ["drainant"], portion: "2 tasses"),
        food("tisane-ortie", "Tisane d’ortie", .drinks, .hero, k: 40, na: 2, mg: 8,
             why: "Tendance drainante visage — cure courte.",
             tags: ["drainant", "tiktok-trend", "soir-safe"], portion: "2 tasses"),
        food("tisane-queues-cerise", "Tisane queues de cerise", .drinks, .hero, k: 30, na: 1, mg: 5,
             why: "Classique anti-rétention (effet diurétique).",
             tags: ["drainant", "tiktok-trend", "soir-safe"], portion: "2 tasses"),
        food("tisane-pissenlit", "Tisane de pissenlit", .drinks, .prefer, k: 25, na: 1, mg: 4,
             why: "Drainage doux, utile en phase visage gonflé.",
             tags: ["drainant", "soir-safe"], portion: "1–2 tasses"),
        food("tisane-prele", "Tisane de prêle", .drinks, .prefer, k: 20, na: 1, mg: 4,
             why: "Support drainage — ne pas abuser.",
             tags: ["drainant"], portion: "1 tasse"),
        food("tisane-bouleau", "Tisane de bouleau", .drinks, .prefer, k: 22, na: 1, mg: 3,
             why: "Tradition anti-rétention.",
             tags: ["drainant", "soir-safe"], portion: "1–2 tasses"),
        food("tisane-fenouil", "Tisane de fenouil", .drinks, .prefer, k: 18, na: 1, mg: 3,
             why: "Digestion + légèreté après repas.",
             tags: ["soir-safe"], portion: "1 tasse"),
        food("tisane-hibiscus", "Tisane d’hibiscus", .drinks, .prefer, k: 20, na: 1, mg: 3,
             why: "Boisson colorée low-Na, utile froid.",
             tags: ["soir-safe"], portion: "1–2 tasses"),
        food("tisane-reine-pres", "Tisane reine-des-prés", .drinks, .prefer, k: 15, na: 1, mg: 2,
             why: "Option drainage douce.",
             tags: ["drainant"], portion: "1 tasse"),
        food("tisane-camomille", "Camomille", .drinks, .prefer, k: 9, na: 1, mg: 1,
             why: "Soir : calme + rituel sans caféine.",
             tags: ["soir-safe"], portion: "1 tasse le soir"),
        food("eau-citronnee", "Eau citronnée", .drinks, .prefer, k: 20, na: 1, mg: 2,
             why: "Rituel simple : hydration + signal anti-sel.",
             tags: ["soir-safe", "tiktok-trend"], portion: "1 L"),
        food("eau-concombre-menthe", "Eau concombre-menthe-gingembre", .drinks, .hero, k: 40, na: 2, mg: 4,
             why: "Infusion froide drainante — tendance + efficace.",
             tags: ["soir-safe", "tiktok-trend", "drainant"], portion: "1 carafe"),
        food("jus-ananas", "Jus d’ananas 100 %", .drinks, .prefer, k: 130, na: 2, mg: 12,
             why: "Modéré : bromélaïne, sans sucre ajouté.",
             tags: ["tiktok-trend"], portion: "150 ml"),
        food("eau-coco", "Eau de coco nature", .drinks, .hero, k: 250, na: 105, mg: 25,
             why: "K tendance TikTok — nature, pas aromatisée sucrée.",
             tags: ["high-K", "tiktok-trend"], portion: "250 ml")
    ]

    static let moderateFoods: [DebloatFoodItem] = [
        food("pain-complet", "Pain complet", .avoidOther, .moderate, k: 250, na: 450, mg: 50,
             why: "Mieux que blanc mais encore salé — portions courtes.",
             tags: ["evening-risk"], swaps: ["quinoa", "patate-douce"], portion: "1 tranche"),
        food("fromage-frais", "Fromages frais", .avoidOther, .moderate, k: 100, na: 300, mg: 10,
             why: "Vérifier le sel ; préférer nature nature.",
             tags: [], swaps: ["yaourt-nature"], portion: "30–40 g"),
        food("yaourt-aromatise", "Yaourt aromatisé", .avoidOther, .moderate, k: 180, na: 60, mg: 15,
             why: "Sucres + parfois additifs — le nature gagne pour le visage.",
             tags: [], swaps: ["yaourt-nature"], portion: "1 pot"),
        food("chocolat-lait", "Chocolat au lait", .avoidOther, .moderate, k: 340, na: 80, mg: 50,
             why: "Moins de Mg utile que le noir ≥70 %.",
             tags: [], swaps: ["chocolat-noir"], portion: "20 g"),
        food("fruits-secs-sales", "Fruits secs salés", .avoidOther, .moderate, k: 600, na: 400, mg: 150,
             why: "Le sel annule le bénéfice K/Mg.",
             tags: ["evening-risk"], swaps: ["amandes", "pistaches"], portion: "éviter"),
        food("algues", "Algues (non rincées)", .avoidOther, .moderate, k: 200, na: 900, mg: 100,
             why: "Souvent très Na — rincer longuement ou éviter.",
             tags: ["evening-risk"], swaps: ["roquette"], portion: "petite portion rincée")
    ]

    static let avoidFoods: [DebloatFoodItem] = [
        food("sel-table", "Sel de table / fleur de sel", .avoidSodium, .avoid, k: 0, na: 38700, mg: 0,
             why: "Cause n°1 de rétention faciale — remplacer par herbes + citron.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["herbes-provence", "citron", "cumin"]),
        food("jambon-blanc", "Jambon (cru ou blanc)", .avoidSodium, .avoid, k: 280, na: 900, mg: 18,
             why: "Charcuterie = sodium massif → visage gonflé.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["poulet", "dinde"]),
        food("saucisson", "Saucisson / salami", .avoidSodium, .avoid, k: 300, na: 1800, mg: 20,
             why: "Bombes de sel — à exclure en phase visage.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["poulet"]),
        food("lardons", "Lardons / bacon", .avoidSodium, .avoid, k: 250, na: 1500, mg: 15,
             why: "Sodium + transformation = rétention.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["champignons"]),
        food("pate-rillettes", "Pâté / rillettes", .avoidSodium, .avoid, k: 150, na: 800, mg: 12,
             why: "Charcuterie salée — swap protéine fraîche.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["poulet"]),
        food("chorizo", "Chorizo", .avoidSodium, .avoid, k: 280, na: 1600, mg: 18,
             why: "Très salé + épicé transformé.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["poulet"]),
        food("fromage-affine", "Fromages affinés / salés", .avoidSodium, .avoid, k: 100, na: 1200, mg: 25,
             why: "Roquefort, feta, parmesan, bleu… sodium dominant.",
             tags: ["evening-risk"], swaps: ["yaourt-nature", "fromage-blanc"]),
        food("pain-baguette", "Pain (baguette / mie / biscottes)", .avoidSodium, .avoid, k: 110, na: 650, mg: 25,
             why: "1er contributeur de sel en France — swap féculent K.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["patate-douce", "pomme-de-terre", "quinoa"]),
        food("pain-mie", "Pain de mie / biscottes", .avoidSodium, .avoid, k: 120, na: 500, mg: 20,
             why: "Sel caché + ultra-transformé.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["flocons-avoine", "quinoa"]),
        food("saumon-fume", "Saumon fumé", .avoidSodium, .avoid, k: 350, na: 1200, mg: 25,
             why: "Fumé = sodium élevé ; choisir saumon frais.",
             tags: ["evening-risk"], swaps: ["saumon"]),
        food("anchois", "Anchois / poissons salés", .avoidSodium, .avoid, k: 200, na: 3600, mg: 40,
             why: "Salaison extrême — rétention assurée.",
             tags: ["evening-risk"], swaps: ["sardines", "poisson-blanc"]),
        food("olives-saumure", "Olives / cornichons / câpres", .avoidSodium, .avoid, k: 80, na: 1550, mg: 10,
             why: "Saumure = piège sodium sur la table.",
             tags: ["evening-risk"], swaps: ["concombre", "tomate"]),
        food("chips", "Chips / apéritifs salés", .avoidSodium, .avoid, k: 1200, na: 500, mg: 40,
             why: "Sel + ultra-transformé : double peine visage.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["concombre", "amandes"]),
        food("cacahuetes-salees", "Cacahuètes salées", .avoidSodium, .avoid, k: 600, na: 400, mg: 160,
             why: "Le sel annule le Mg — version nature seulement.",
             tags: ["evening-risk"], swaps: ["amandes", "graines-courge"]),
        food("plats-prepares", "Plats préparés / traiteur", .avoidSodium, .avoid, k: 200, na: 900, mg: 20,
             why: "Pizza, lasagnes, quiches… sodium industriel.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["poulet", "courgette"]),
        food("sauce-soja", "Sauce soja / ketchup / mayo / moutarde", .avoidSodium, .avoid, k: 180, na: 5500, mg: 30,
             why: "Sauces = sel concentré. Citron + herbes.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["citron", "herbes-provence"]),
        food("bouillon-cube", "Bouillons cubes / fonds", .avoidSodium, .avoid, k: 50, na: 8000, mg: 5,
             why: "Sel caché massif dans les soupes.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["thym", "ail"]),
        food("conserves-non-rincees", "Conserves non rincées", .avoidSodium, .avoid, k: 200, na: 400, mg: 20,
             why: "Rincer = geste visage immédiat.",
             tags: ["evening-risk"], swaps: ["haricots-blancs"]),
        food("viennoiseries", "Viennoiseries / biscuits industriels", .avoidSodium, .avoid, k: 100, na: 400, mg: 15,
             why: "Sel + sucre + UT → rétention et inflammation.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["banane", "yaourt-nature"]),
        food("alcool", "Alcool (surtout le soir)", .avoidOther, .avoid, k: 0, na: 5, mg: 5,
             why: "Vasodilatation + rétention — visage gonflé au réveil.",
             tags: ["evening-risk"], swaps: ["eau-plate", "tisane-camomille"]),
        food("cafeine-tardive", "Café / thé noir après 15 h", .avoidOther, .avoid, k: 50, na: 5, mg: 5,
             why: "Excès tardif → sommeil ↓ → cortisol → visage gonflé.",
             tags: ["evening-risk"], swaps: ["tisane-camomille", "tisane-fenouil"]),
        food("sodas", "Sodas / jus industriels", .avoidOther, .avoid, k: 10, na: 20, mg: 2,
             why: "Sucres rapides + inflammation.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["eau-coco", "eau-citronnee"]),
        food("beurre-sale", "Beurre salé / margarine salée", .avoidSodium, .avoid, k: 20, na: 600, mg: 2,
             why: "Sel ajouté inutile — huile + herbes.",
             tags: ["evening-risk"], swaps: ["avocat"]),
        food("eaux-sodees", "Eaux riches en sodium (Badoit, Vichy…)", .avoidSodium, .avoid, k: 0, na: 170, mg: 10,
             why: "Gazeuses très Na en quantité = rétention.",
             tags: ["evening-risk"], swaps: ["hepar", "contrex", "eau-plate"]),
        food("fast-food", "Fast-food / livraisons salées", .avoidSodium, .avoid, k: 300, na: 1200, mg: 30,
             why: "Combo sel + UT : ennemi direct du visage net.",
             tags: ["evening-risk", "ultra-processed"], swaps: ["poulet", "roquette"])
    ]
}
