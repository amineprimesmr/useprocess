import Foundation

/// Libellés catalogue aliments Debloat — FR persisté (`name` / `why` / `portion`), EN via `AppCopy.t`.
enum ProcessLocalizedDebloatFoodContent {

    @MainActor
    static func name(for food: DebloatFoodItem) -> String {
        if let en = namesFRToEN[food.id] {
            return AppCopy.t(food.name, en: en)
        }
        return food.name
    }

    @MainActor
    static func why(for food: DebloatFoodItem) -> String {
        if let en = whyFRToEN[food.id] {
            return AppCopy.t(food.whyItHelpsOrHurts, en: en)
        }
        return food.whyItHelpsOrHurts
    }

    @MainActor
    static func portion(for food: DebloatFoodItem) -> String? {
        guard let fr = food.portionHint else { return nil }
        if let en = portionHintsFRToEN[fr] {
            return AppCopy.t(fr, en: en)
        }
        return fr
    }

    @MainActor
    static func portionHint(_ fr: String) -> String {
        if let en = portionHintsFRToEN[fr] {
            return AppCopy.t(fr, en: en)
        }
        if let en = groceryQuantityFRToEN[fr] {
            return AppCopy.t(fr, en: en)
        }
        // ×N portions
        if fr.hasPrefix("×"), fr.hasSuffix(" portions"),
           let n = fr.dropFirst().split(separator: " ").first {
            return AppCopy.t(fr, en: "×\(n) portions")
        }
        return fr
    }

    /// Recettes générées depuis likes — préfixes FR → EN + noms aliments.
    @MainActor
    static func localizedRecipeName(_ fr: String) -> String {
        let trimmed = fr.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes: [(fr: String, en: String)] = [
            ("Matin dégonflé · ", "Debloat morning · "),
            ("Bowl K · ", "K bowl · "),
            ("Dîner anti-rétention · ", "Anti-retention dinner · "),
            ("Collation drainante · ", "Draining snack · "),
        ]
        for prefix in prefixes where trimmed.hasPrefix(prefix.fr) {
            let restFR = String(trimmed.dropFirst(prefix.fr.count))
            let restEN = localizeEmbeddedFoodNames(restFR)
            return AppCopy.t(trimmed, en: prefix.en + restEN)
        }
        return trimmed
    }

    @MainActor
    static func localizedRecipeTip(_ fr: String) -> String? {
        let trimmed = fr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("Priorité potassium : ") else { return nil }
        // "Priorité potassium : X + Y. Évite le sel ce repas."
        let body = trimmed
            .replacingOccurrences(of: "Priorité potassium : ", with: "")
            .replacingOccurrences(of: ". Évite le sel ce repas.", with: "")
        let foods = body.components(separatedBy: " + ").map { localizeEmbeddedFoodNames($0) }
        let en = "Potassium first: \(foods.joined(separator: " + ")). Skip salt this meal."
        return AppCopy.t(trimmed, en: en)
    }

    @MainActor
    static func localizedRecipePrep(_ fr: String) -> String? {
        let trimmed = fr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("Zéro sauce industrielle") else { return nil }
        // Best-effort: replace known food names, then wrap template.
        let withNames = localizeEmbeddedFoodNames(trimmed)
        let en = withNames
            .replacingOccurrences(of: "Prépare ", with: "Prep ")
            .replacingOccurrences(of: " sans sel (herbes + citron).", with: " without salt (herbs + lemon).")
            .replacingOccurrences(of: "Ajoute ", with: "Add ")
            .replacingOccurrences(of: " cuits vapeur ou four.", with: " steamed or oven-roasted.")
            .replacingOccurrences(of: "Finis avec ", with: "Finish with ")
            .replacingOccurrences(of: " et ", with: " and ")
            .replacingOccurrences(
                of: "Zéro sauce industrielle — l'objectif est le visage dégonflé.",
                with: "No store-bought sauce — the goal is a debloated face."
            )
            .replacingOccurrences(
                of: "Zéro sauce industrielle — l’objectif est le visage dégonflé.",
                with: "No store-bought sauce — the goal is a debloated face."
            )
        return AppCopy.t(trimmed, en: en)
    }

    @MainActor
    private static func localizeEmbeddedFoodNames(_ text: String) -> String {
        var result = text
        // Remplacer les noms longs d'abord pour éviter les collisions partielles.
        let pairs = DebloatFoodCatalog.all
            .map { ($0.name, $0.localizedName) }
            .sorted { $0.0.count > $1.0.count }
        for (frName, enName) in pairs where result.contains(frName) {
            result = result.replacingOccurrences(of: frName, with: enName)
        }
        return result
    }

    /// Quantités générées (liste de courses) — clés FR.
    static let groceryQuantityFRToEN: [String: String] = [
        "1 portion": "1 portion",
        "2 portions": "2 portions",
        "3–4 portions": "3–4 portions",
        "6×1,5 L": "6×1.5 L",
        "4–6 unités": "4–6 units",
        "2–3 unités": "2–3 units",
        "1 botte / pot": "1 bunch / jar",
        "1 paquet": "1 pack",
        "à éviter": "avoid",
    ]

    /// Clés = `DebloatFoodItem.id`.
    static let namesFRToEN: [String: String] = [
        "concombre": "Cucumber",
        "courgette": "Zucchini",
        "asperge": "Asparagus",
        "celeri": "Celery stalks",
        "fenouil": "Fennel",
        "artichaut": "Artichoke",
        "poireau": "Leek",
        "epinards": "Spinach",
        "blettes": "Swiss chard",
        "tomate": "Tomato",
        "tomate-concentree": "Unsalted tomato paste",
        "poivron": "Bell pepper",
        "radis-noir": "Black radish",
        "aubergine": "Eggplant",
        "carotte": "Carrot",
        "brocoli": "Broccoli",
        "choux-bruxelles": "Brussels sprouts",
        "haricots-verts": "Green beans",
        "roquette": "Arugula",
        "mache": "Lamb's lettuce",
        "betterave": "Beet",
        "champignons": "Mushrooms",
        "pasteque": "Watermelon",
        "melon": "Melon",
        "ananas": "Pineapple",
        "citron": "Lemon",
        "orange": "Orange",
        "pamplemousse": "Grapefruit",
        "citron-vert": "Lime",
        "kiwi": "Kiwi",
        "fraises": "Strawberries",
        "framboises": "Raspberries",
        "myrtilles": "Blueberries",
        "mures": "Blackberries",
        "banane": "Banana",
        "avocat": "Avocado",
        "pomme": "Apple",
        "figue": "Fig",
        "abricot": "Apricot",
        "abricots-secs": "Dried apricots",
        "peche": "Peach / nectarine",
        "raisins-secs": "Raisins",
        "dattes": "Dates",
        "patate-douce": "Sweet potato",
        "pomme-de-terre": "Potato",
        "lentilles": "Lentils",
        "haricots-blancs": "White beans",
        "haricots-rouges": "Kidney beans",
        "pois-chiches": "Chickpeas",
        "pois-casses": "Split peas",
        "amandes": "Unsalted almonds",
        "pistaches": "Unsalted pistachios",
        "graines-courge": "Pumpkin seeds",
        "noix-cajou": "Cashews",
        "noix-bresil": "Brazil nuts",
        "chia": "Chia seeds",
        "lin": "Flax seeds",
        "sesame": "Sesame seeds",
        "tournesol": "Sunflower seeds",
        "chocolat-noir": "Dark chocolate ≥ 70%",
        "cacao": "Unsweetened cocoa",
        "flocons-avoine": "Oats",
        "quinoa": "Quinoa",
        "sarrasin": "Buckwheat",
        "noisettes": "Hazelnuts",
        "poulet": "Chicken (skinless)",
        "dinde": "Turkey (skinless)",
        "oeufs": "Eggs",
        "saumon": "Salmon (fresh)",
        "sardines": "Sardines (plain)",
        "maquereau": "Mackerel",
        "thon": "Tuna (plain)",
        "poisson-blanc": "White fish",
        "yaourt-nature": "Plain yogurt",
        "fromage-blanc": "Fromage blanc",
        "kefir": "Plain kefir",
        "tofu": "Tofu",
        "tempeh": "Tempeh",
        "persil": "Parsley",
        "gingembre": "Ginger",
        "cumin": "Cumin",
        "ail": "Garlic",
        "oignon": "Onion",
        "basilic": "Basil",
        "thym": "Thyme",
        "origan": "Oregano",
        "menthe": "Mint",
        "herbes-provence": "Herbes de Provence",
        "vinaigre-cidre": "Apple cider vinegar",
        "eau-plate": "Still water",
        "hepar": "Hépar",
        "contrex": "Contrex",
        "rozana": "Rozana",
        "courmayeur": "Courmayeur",
        "the-vert": "Green tea",
        "tisane-ortie": "Nettle tea",
        "tisane-queues-cerise": "Cherry stem tea",
        "tisane-pissenlit": "Dandelion tea",
        "tisane-prele": "Horsetail tea",
        "tisane-bouleau": "Birch tea",
        "tisane-fenouil": "Fennel tea",
        "tisane-hibiscus": "Hibiscus tea",
        "tisane-reine-pres": "Meadowsweet tea",
        "tisane-camomille": "Chamomile",
        "eau-citronnee": "Lemon water",
        "eau-concombre-menthe": "Cucumber-mint-ginger water",
        "jus-ananas": "100% pineapple juice",
        "eau-coco": "Plain coconut water",
        "pain-complet": "Whole-grain bread",
        "fromage-frais": "Fresh cheeses",
        "yaourt-aromatise": "Flavored yogurt",
        "chocolat-lait": "Milk chocolate",
        "fruits-secs-sales": "Salted dried fruit / nuts",
        "algues": "Seaweed (unrinsed)",
        "sel-table": "Table salt / fleur de sel",
        "jambon-blanc": "Ham (cured or cooked)",
        "saucisson": "Salami / dry sausage",
        "lardons": "Bacon / lardons",
        "pate-rillettes": "Pâté / rillettes",
        "chorizo": "Chorizo",
        "fromage-affine": "Aged / salty cheeses",
        "pain-baguette": "Bread (baguette / sandwich / crispbread)",
        "pain-mie": "Sandwich bread / crispbread",
        "saumon-fume": "Smoked salmon",
        "anchois": "Anchovies / salted fish",
        "olives-saumure": "Olives / pickles / capers",
        "chips": "Chips / salty snacks",
        "cacahuetes-salees": "Salted peanuts",
        "plats-prepares": "Prepared / takeout meals",
        "sauce-soja": "Soy sauce / ketchup / mayo / mustard",
        "bouillon-cube": "Bouillon cubes / stock bases",
        "conserves-non-rincees": "Unrinsed canned foods",
        "viennoiseries": "Pastries / industrial cookies",
        "alcool": "Alcohol (especially at night)",
        "cafeine-tardive": "Coffee / black tea after 3 p.m.",
        "sodas": "Sodas / industrial juices",
        "beurre-sale": "Salted butter / salted margarine",
        "eaux-sodees": "High-sodium waters (Badoit, Vichy…)",
        "fast-food": "Fast food / salty delivery",
    ]

    /// Clés = `DebloatFoodItem.id`.
    static let whyFRToEN: [String: String] = [
        "concombre": "No. 1 anti-bloat: water + K, almost zero sodium.",
        "courgette": "Draining vegetable — perfect at night for a cleaner face.",
        "asperge": "Natural diuretic — helps flush excess water.",
        "celeri": "Crunchy and draining — keep sodium low by eating it plain.",
        "fenouil": "High in K, easy to digest, great for limiting retention.",
        "artichaut": "Supports drainage and adds useful magnesium.",
        "poireau": "Anti-retention soup base — low sodium if unsalted.",
        "epinards": "Triple lever: potassium + magnesium + draining volume.",
        "blettes": "Leaves rich in K/Mg — rinse and cook without salt.",
        "tomate": "Fresh or plain concentrated: K boost with no added salt.",
        "tomate-concentree": "Potassium concentrator — choose no-salt-added.",
        "poivron": "Color, crunch, almost zero sodium.",
        "radis-noir": "Classic draining food — useful in a short face reset.",
        "aubergine": "Cooked without salt: filling volume and solid K.",
        "carotte": "Stable base — soup or grated without salty dressing.",
        "brocoli": "K + fiber — moderate portions if digestion is sensitive.",
        "choux-bruxelles": "Solid potassium; steam + herbs instead of salted butter.",
        "haricots-verts": "Evening-safe side — negligible sodium.",
        "roquette": "High-K salad; lemon + oil, zero salt.",
        "mache": "Mild leaf, very high in potassium.",
        "betterave": "Cook plain (not in industrial vinaigrette).",
        "champignons": "Umami without salt — anti-retention ally.",
        "pasteque": "Water + K: fast draining effect on the face.",
        "melon": "Draining fruit dense in potassium.",
        "ananas": "Bromelain + drainage — fresh or moderate 100% juice.",
        "citron": "Replaces salt: acidity + lemon-water rituals.",
        "orange": "Hydration and K with no sodium.",
        "pamplemousse": "Light, draining, useful in the morning.",
        "citron-vert": "Anti-salt seasoning for bowls and fish.",
        "kiwi": "High potassium in a small volume.",
        "fraises": "Water + K fruit — face-friendly snack.",
        "framboises": "Fiber + K, little sodium.",
        "myrtilles": "Helpful antioxidants, negligible sodium.",
        "mures": "Draining berries — simple snack.",
        "banane": "Star K source — ideal post-workout / morning.",
        "avocat": "Very high K — replaces salty sauces.",
        "pomme": "Neutral base — useful unsalted snack.",
        "figue": "Fresh or unsweetened dried: K boost.",
        "abricot": "Fresh or unsweetened dried — concentrated potassium.",
        "abricots-secs": "K concentrator — small portion, unsweetened.",
        "peche": "Seasonal water fruit, zero sodium.",
        "raisins-secs": "Dense K — avoid salted/coated versions.",
        "dattes": "K + Mg; controlled portion, not stuffed.",
        "patate-douce": "High-K starch: steam/oven, skin on if possible.",
        "pomme-de-terre": "With skin, steam/oven: potassium bomb vs retention.",
        "lentilles": "K + protein; rinse if canned.",
        "haricots-blancs": "Very high K/Mg — plain rinsed version.",
        "haricots-rouges": "High-K legume — rinse canned.",
        "pois-chiches": "Unsalted bowl base; homemade hummus without salty baking soda.",
        "pois-casses": "Homemade unsalted soup = gradual drainage.",
        "amandes": "Mg + K — anti-retention snack (unsalted).",
        "pistaches": "Exceptional K if unsalted.",
        "graines-courge": "Best food Mg lever for fluid balance.",
        "noix-cajou": "Dense Mg — plain version only.",
        "noix-bresil": "Mg + selenium; 2–3 nuts are enough.",
        "chia": "Mg + fiber; plain pudding, no syrup.",
        "lin": "Useful Mg; grind for absorption.",
        "sesame": "Mg on salads — unsalted.",
        "tournesol": "Mg snack if unsalted.",
        "chocolat-noir": "Controlled Mg treat — avoid milk/sweet versions.",
        "cacao": "Ultra-dense Mg in plain powder.",
        "flocons-avoine": "Mg breakfast; plain, not flavored packets.",
        "quinoa": "Bread/white-rice alternative: K + Mg.",
        "sarrasin": "Gluten-free, good Mg, cook without salt.",
        "noisettes": "Mg + K, unsalted snack.",
        "poulet": "Clean protein — cold roast > deli meats.",
        "dinde": "Low-Na white alternative to deli meats.",
        "oeufs": "Stable protein; cook without salt.",
        "saumon": "K + omega-3 — fresh, never smoked for the face.",
        "sardines": "Solid K; choose plain in water/oil, drain.",
        "maquereau": "Useful oily fish; avoid smoked versions.",
        "thon": "Plain in water, rinsed; skip soy sauce.",
        "poisson-blanc": "Cod/pollock: evening-safe low-Na protein.",
        "yaourt-nature": "Gentle dairy K — plain, not sweet flavored.",
        "fromage-blanc": "Filling texture, moderate sodium if plain 0%.",
        "kefir": "Gentle fermented option — plain only.",
        "tofu": "Plant protein; plain, not salty marinated.",
        "tempeh": "Interesting K/Mg — cook with herbs/lemon.",
        "persil": "Star diuretic — fresh at the end of the dish.",
        "gingembre": "Anti-retention + digestion; infusion or grated.",
        "cumin": "Replace some salt with aromatic heat.",
        "ail": "Strong flavor without salting — ease up if digestion is fragile.",
        "oignon": "Aromatic base; moderate portions if bloating.",
        "basilic": "Anti-salt freshness on tomatoes and fish.",
        "thym": "Mg/K seasoning — forget the bouillon cube.",
        "origan": "Powerful aromatic to forget salt.",
        "menthe": "Cucumber-mint water: draining ritual.",
        "herbes-provence": "Anti-salt blend for meats and vegetables.",
        "vinaigre-cidre": "Moderate acidity in salt-free vinaigrette.",
        "eau-plate": "Absolute base: 1.5–2.5 L/day to drain.",
        "hepar": "Mg-rich mineral water, low Na — face ally.",
        "contrex": "High Mg / low Na — mineral drainage.",
        "rozana": "Strong Mg profile, low sodium.",
        "courmayeur": "Very low-sodium water.",
        "the-vert": "Gentle diuretic — avoid after 3 p.m. if sleep is fragile.",
        "tisane-ortie": "Draining face trend — short course.",
        "tisane-queues-cerise": "Classic anti-retention (diuretic effect).",
        "tisane-pissenlit": "Gentle drainage — useful when the face is puffy.",
        "tisane-prele": "Drainage support — don't overdo it.",
        "tisane-bouleau": "Anti-retention tradition.",
        "tisane-fenouil": "Digestion + lightness after meals.",
        "tisane-hibiscus": "Colorful low-Na drink, useful cold.",
        "tisane-reine-pres": "Gentle drainage option.",
        "tisane-camomille": "Evening: calm + caffeine-free ritual.",
        "eau-citronnee": "Simple ritual: hydration + anti-salt signal.",
        "eau-concombre-menthe": "Cold draining infusion — trendy and effective.",
        "jus-ananas": "Moderate: bromelain, no added sugar.",
        "eau-coco": "TikTok-trending K — plain, not sweet flavored.",
        "pain-complet": "Better than white but still salty — keep portions short.",
        "fromage-frais": "Check the salt; prefer plain versions.",
        "yaourt-aromatise": "Sugars + sometimes additives — plain wins for the face.",
        "chocolat-lait": "Less useful Mg than dark ≥70%.",
        "fruits-secs-sales": "Salt cancels the K/Mg benefit.",
        "algues": "Often very high Na — rinse thoroughly or avoid.",
        "sel-table": "No. 1 cause of facial retention — replace with herbs + lemon.",
        "jambon-blanc": "Deli meat = massive sodium → puffy face.",
        "saucisson": "Salt bombs — exclude in a face-focused phase.",
        "lardons": "Sodium + processing = retention.",
        "pate-rillettes": "Salty deli — swap for fresh protein.",
        "chorizo": "Very salty + processed spice.",
        "fromage-affine": "Roquefort, feta, Parmesan, blue… sodium dominates.",
        "pain-baguette": "Top salt contributor — swap for a high-K starch.",
        "pain-mie": "Hidden salt + ultra-processed.",
        "saumon-fume": "Smoked = high sodium; choose fresh salmon.",
        "anchois": "Extreme salting — retention guaranteed.",
        "olives-saumure": "Brine = sodium trap on the table.",
        "chips": "Salt + ultra-processed: double hit for the face.",
        "cacahuetes-salees": "Salt cancels the Mg — plain version only.",
        "plats-prepares": "Pizza, lasagna, quiche… industrial sodium.",
        "sauce-soja": "Sauces = concentrated salt. Lemon + herbs.",
        "bouillon-cube": "Massive hidden salt in soups.",
        "conserves-non-rincees": "Rinse = instant face-friendly move.",
        "viennoiseries": "Salt + sugar + UP → retention and inflammation.",
        "alcool": "Vasodilation + retention — puffy face on waking.",
        "cafeine-tardive": "Late excess → sleep ↓ → cortisol → puffy face.",
        "sodas": "Fast sugars + inflammation.",
        "beurre-sale": "Useless added salt — oil + herbs.",
        "eaux-sodees": "Very high-Na sparkling in volume = retention.",
        "fast-food": "Salt + UP combo: direct enemy of a clean face.",
    ]

    /// Clés = `portionHint` FR persisté.
    static let portionHintsFRToEN: [String: String] = [
        "1 L": "1 L",
        "1 artichaut": "1 artichoke",
        "1 aubergine": "1 eggplant",
        "1 banane": "1 banana",
        "1 betterave": "1 beet",
        "1 bol": "1 bowl",
        "1 botte": "1 bunch",
        "1 bouteille": "1 bottle",
        "1 boîte nature": "1 plain can",
        "1 bulbe": "1 bulb",
        "1 c. à c.": "1 tsp",
        "1 c. à s.": "1 tbsp",
        "1 carafe": "1 pitcher",
        "1 cm frais": "1 cm fresh",
        "1 gousse": "1 clove",
        "1 moyenne": "1 medium",
        "1 orange": "1 orange",
        "1 pincée": "1 pinch",
        "1 poireau": "1 leek",
        "1 poivron": "1 bell pepper",
        "1 pomme": "1 apple",
        "1 pot": "1 cup",
        "1 tasse": "1 cup",
        "1 tasse le soir": "1 cup at night",
        "1 tranche": "1 slice",
        "1/2 avocat": "1/2 avocado",
        "1/2 bouquet": "1/2 bunch",
        "1/2 citron": "1/2 lemon",
        "1/2 fruit": "1/2 fruit",
        "1/2 melon": "1/2 melon",
        "1/2 oignon": "1/2 onion",
        "1/2 à 1 concombre": "1/2 to 1 cucumber",
        "120 g": "120 g",
        "125 g": "125 g",
        "140 g": "140 g",
        "15 g": "15 g",
        "150 g": "150 g",
        "150 g cuites": "150 g cooked",
        "150 g cuits": "150 g cooked",
        "150 ml": "150 ml",
        "150–180 g": "150–180 g",
        "160 g": "160 g",
        "1–2 fruits": "1–2 fruits",
        "1–2 pommes de terre": "1–2 potatoes",
        "1–2 tasses": "1–2 cups",
        "2 L / jour": "2 L / day",
        "2 c. à s.": "2 tbsp",
        "2 carottes": "2 carrots",
        "2 dattes": "2 dates",
        "2 kiwis": "2 kiwis",
        "2 parts": "2 servings",
        "2 tasses": "2 cups",
        "2 tomates": "2 tomatoes",
        "2 œufs": "2 eggs",
        "20 g": "20 g",
        "200 g": "200 g",
        "200 g cuite": "200 g cooked",
        "200 ml": "200 ml",
        "20–25 g": "20–25 g",
        "250 ml": "250 ml",
        "2–3 branches": "2–3 stalks",
        "2–3 figues": "2–3 figs",
        "2–3 noix": "2–3 nuts",
        "3 abricots": "3 apricots",
        "30–40 g": "30–40 g",
        "40–50 g": "40–50 g",
        "4–5 pièces": "4–5 pieces",
        "80 g crus": "80 g dry",
        "petite portion rincée": "small rinsed portion",
        "quelques feuilles": "a few leaves",
        "quelques tranches": "a few slices",
        "une poignée": "a handful",
        "éviter": "avoid",
    ]
}
