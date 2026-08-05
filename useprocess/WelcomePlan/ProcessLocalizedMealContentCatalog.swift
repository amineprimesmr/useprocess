import Foundation

extension ProcessLocalizedMealContent {
    /// Résumés catalogue FR → EN (clés = blurb `scoreSummary` repas Process).
    static let mealSummariesFRToEN: [String: String] = [
        "Le plus simple — 3 œufs, banane et kiwi potassium.": "The simplest — 3 eggs, banana, and potassium-rich kiwi.",
        "Petit-déj style sucré — yaourt ou kéfir nature, myrtilles et une pointe de miel.": "Sweet-style breakfast — plain yogurt or kefir, blueberries, and a touch of honey.",
        "Brunch salé drainant — saumon frais (jamais fumé), avocat et concombre.": "Savory draining brunch — fresh salmon (never smoked), avocado, and cucumber.",
        "Classique dense — poulet doré, tubercule rôti et brocoli grillé.": "Dense classic — golden chicken, roasted sweet potato, and grilled broccoli.",
        "Patate douce rôtie, viande hachée maigre, pico frais et avocat en éventail.": "Roasted sweet potato, lean ground meat, fresh pico, and fanned avocado.",
        "Grande salade protéinée — avocat, concombre, roquette, tomate.": "Big protein salad — avocado, cucumber, arugula, tomato.",
        "Oméga-3, quinoa complet et salade fraîche menthe-citron.": "Omega-3s, whole quinoa, and a fresh mint-lemon salad.",
        "Dinde poêlée, pommes rôties et salade verte avocat.": "Pan-seared turkey, roasted potatoes, and green salad with avocado.",
        "Bœuf 5% frais, riz basmati et poivrons rôtis — pas de patate douce.": "Fresh 5% ground beef, basmati rice, and roasted peppers — no sweet potato.",
        "Poisson blanc léger, haricots verts et salade fenouil-concombre.": "Light white fish, green beans, and fennel-cucumber salad.",
        "Steak grillé, salade épinards-tomate et pommes de terre sautées — dîner viande + salade.": "Grilled steak, spinach-tomato salad, and sautéed potatoes — meat + salad dinner.",
        "Poulet doré au four et grande salade avocat-concombre.": "Oven-roasted golden chicken and a big avocado-cucumber salad.",
        "Dinde poêlée, brocoli rôti et riz — dîner protéiné sans salade uniquement.": "Pan-seared turkey, roasted broccoli, and rice — a warm protein dinner, not just salad.",
        "Poisson blanc rôti, carottes fondantes et salade mâche citron.": "Roasted white fish, tender carrots, and lemon lamb’s lettuce salad.",
        "Repas unique dense — steak grillé, patate rôtie, avocat.": "One dense plate — grilled steak, roasted sweet potato, avocado.",
        "OMAD salade-bowl — poulet grillé, quinoa, légumes variés et avocat.": "OMAD salad bowl — grilled chicken, quinoa, mixed vegetables, and avocado.",
        "Collation simple — banane potassium et skyr protéiné.": "Simple snack — potassium banana and high-protein skyr.",
        "Collation protéinée — ananas frais, concombre et dinde maison.": "Protein snack — fresh pineapple, cucumber, and homemade turkey.",
    ]

    /// Préparations catalogue FR → EN (clés = prep normalisé).
    static let mealPrepsFRToEN: [String: String] = [
        // Œufs Brouillés Banane Kiwi
        """
1. Casse les 3 œufs dans un bol, bats-les à la fourchette avec poivre (sans sel).
2. Fais chauffer une poêle à feu moyen avec un filet d’huile d’olive.
3. Verse les œufs et brouille 4 à 5 min en remuant jusqu’à texture crémeuse.
4. Coupe la banane et le kiwi en rondelles, puis sers à côté des œufs.
""": """
1. Crack the 3 eggs into a bowl and whisk with a fork with pepper (no salt).
2. Heat a skillet over medium with a drizzle of olive oil.
3. Pour in the eggs and scramble 4 to 5 min, stirring until creamy.
4. Slice the banana and kiwi into rounds, then serve next to the eggs.
""",
        // Yaourt Myrtilles Miel
        """
1. Verse le yaourt nature ou le kéfir dans un bol.
2. Ajoute les myrtilles rincées sur le dessus.
3. Verse 1 c. à café de miel en filet léger.
4. Concasse les amandes non salées et parsème avant de manger.
""": """
1. Spoon the plain yogurt or kefir into a bowl.
2. Add the rinsed blueberries on top.
3. Drizzle 1 tsp honey lightly.
4. Chop the unsalted almonds and sprinkle on before eating.
""",
        // Bowl Saumon Avocat Concombre
        """
1. Fais chauffer une poêle à feu moyen-vif avec un filet d’huile d’olive.
2. Poêle le saumon frais 3 à 4 min par face, sans sel — poivre et herbes seulement.
3. Coupe l’avocat en lamelles et le concombre en rondelles.
4. Dresse le saumon, l’avocat et le concombre dans un bol.
5. Arrose de citron et parsème d’aneth ou de ciboulette.
""": """
1. Heat a skillet over medium-high with a drizzle of olive oil.
2. Pan-sear the fresh salmon 3 to 4 min per side, no salt — pepper and herbs only.
3. Slice the avocado into strips and the cucumber into rounds.
4. Plate the salmon, avocado, and cucumber in a bowl.
5. Finish with lemon and sprinkle with dill or chives.
""",
        // Poulet Patate Douce Brocoli
        """
1. Préchauffe le four à 200°C.
2. Coupe la patate douce, le brocoli et la courgette en morceaux réguliers.
3. Mélange les légumes avec 1 c. à soupe d’huile d’olive, herbes et huile infusée à l’ail (sans sel).
4. Étale sur une plaque et rôtis 22 min à 200°C en remuant à mi-cuisson.
5. Pendant ce temps, poêle le blanc de poulet 6 min de chaque côté à feu moyen.
6. Laisse reposer le poulet 2 min, tranche-le, puis dresse avec les légumes rôtis.
""": """
1. Preheat the oven to 400°F (200°C).
2. Cut the sweet potato, broccoli, and zucchini into even pieces.
3. Toss the vegetables with 1 tbsp olive oil, herbs, and garlic-infused oil (no salt).
4. Spread on a sheet pan and roast 22 min at 400°F, stirring halfway.
5. Meanwhile, pan-sear the chicken breast 6 min per side over medium heat.
6. Rest the chicken 2 min, slice it, then plate with the roasted vegetables.
""",
        // Patate Douce Viande Avocat
        """
1. Préchauffe le four à 200°C. Lave la patate douce et coupe-la en 2 dans le sens de la longueur.
2. Enfourne 40–50 min (face coupée vers le haut ou le bas) jusqu’à ce qu’elle soit ultra-tendre à la fourchette.
3. Fais revenir l’ail et le cumin dans une goutte d’huile d’olive, puis ajoute la viande hachée et cuis-la bien en l’émiettant.
4. Hors du feu, ajoute un peu de jus de citron et du poivre. Réserve.
5. Coupe tomates, oignon rouge et poivron en tout petits dés. Mélange avec coriandre ou persil, le reste de citron, une pincée de cumin et poivre. Laisse mariner 5–10 min.
6. Pose les 2 moitiés de patate côte à côte, écrase légèrement la chair. Répartis la viande chaude, puis la salade. Dispose l’avocat en tranches fines en éventail au centre. Finis avec un filet de citron et un peu d’herbes.
""": """
1. Preheat the oven to 400°F (200°C). Wash the sweet potato and halve it lengthwise.
2. Roast 40–50 min (cut side up or down) until fork-tender.
3. Sauté garlic and cumin in a drop of olive oil, then add the ground meat and cook through, crumbling it.
4. Off heat, add a little lemon juice and pepper. Set aside.
5. Dice tomatoes, red onion, and bell pepper very small. Mix with cilantro or parsley, remaining lemon, a pinch of cumin, and pepper. Marinate 5–10 min.
6. Place both sweet potato halves side by side and lightly mash the flesh. Top with hot meat, then the pico. Fan thin avocado slices in the center. Finish with lemon and herbs.
""",
        // Salade Poulet Avocat Composée
        """
1. Fais chauffer une poêle ou un grill à feu moyen-vif.
2. Cuire le blanc de poulet 6 min de chaque côté, puis laisse reposer 2 min.
3. Tranche le poulet en lanières.
4. Dans un grand bol, mets la roquette, les tomates cerises et le concombre.
5. Ajoute l’avocat en lamelles et le poulet.
6. Prépare une vinaigrette citron + huile d’olive maison, arrose et mélange.
""": """
1. Heat a skillet or grill over medium-high.
2. Cook the chicken breast 6 min per side, then rest 2 min.
3. Slice the chicken into strips.
4. In a large bowl, add arugula, cherry tomatoes, and cucumber.
5. Add avocado slices and the chicken.
6. Whisk a homemade lemon + olive oil dressing, drizzle, and toss.
""",
        // Saumon Quinoa Salade Concombre
        """
1. Rince le quinoa, puis cuis-le selon le paquet. Égoutte et laisse tiédir.
2. Coupe le concombre, ciseèle la menthe, mélange avec citron et huile d’olive.
3. Fais chauffer une poêle à feu moyen-vif.
4. Poêle le saumon 4 min peau vers le bas, puis 2 min côté chair (sans sel).
5. Dresse le quinoa, la salade concombre-menthe et le saumon dans l’assiette.
""": """
1. Rinse the quinoa, then cook per package. Drain and let cool slightly.
2. Slice the cucumber, chop the mint, and toss with lemon and olive oil.
3. Heat a skillet over medium-high.
4. Pan-sear the salmon 4 min skin-side down, then 2 min on the flesh side (no salt).
5. Plate the quinoa, cucumber-mint salad, and salmon.
""",
        // Dinde Pommes Salade Verte
        """
1. Préchauffe le four à 200°C.
2. Coupe les pommes de terre en quartiers, mélange avec thym et huile d’olive.
3. Rôtis 25 min à 200°C jusqu’à doré.
4. Poêle la dinde 5 min de chaque côté à feu moyen.
5. Prépare la salade verte et l’avocat en lamelles.
6. Finis avec citron et huile d’olive, puis dresse dinde, pommes et salade.
""": """
1. Preheat the oven to 400°F (200°C).
2. Cut the potatoes into wedges and toss with thyme and olive oil.
3. Roast 25 min at 400°F until golden.
4. Pan-sear the turkey 5 min per side over medium heat.
5. Prep the green salad and avocado slices.
6. Finish with lemon and olive oil, then plate turkey, potatoes, and salad.
""",
        // Bœuf Haché Riz Poivrons
        """
1. Préchauffe le four à 200°C et lance la cuisson du riz basmati.
2. Coupe poivrons et fenouil, mélange avec huile d’olive et herbes.
3. Rôtis les légumes 18 min à 200°C.
4. Poêle le bœuf haché 6 min à feu vif en émiettant bien (sans sauce salée).
5. Dresse riz, bœuf et légumes, puis parsème d’herbes fraîches.
""": """
1. Preheat the oven to 400°F (200°C) and start the basmati rice.
2. Cut peppers and fennel, toss with olive oil and herbs.
3. Roast the vegetables 18 min at 400°F.
4. Pan-cook the ground beef 6 min over high heat, crumbling well (no salty sauce).
5. Plate rice, beef, and vegetables, then finish with fresh herbs.
""",
        // Lieu Noir Haricots Salade Fenouil
        """
1. Arrose le lieu de citron et d’herbes (sans sel).
2. Poêle le filet 3 min de chaque côté à feu moyen.
3. Poêle les haricots verts 5 min avec un filet d’huile infusée à l’ail.
4. Tranche finement le fenouil et le concombre pour la salade.
5. Dresse poisson, haricots et salade, puis arrose d’huile d’olive et citron.
""": """
1. Dress the pollock with lemon and herbs (no salt).
2. Pan-sear the fillet 3 min per side over medium heat.
3. Sauté the green beans 5 min with a drizzle of garlic-infused oil.
4. Thinly slice fennel and cucumber for the salad.
5. Plate fish, beans, and salad, then drizzle with olive oil and lemon.
""",
        // Steak Salade Épinards Pommes
        """
1. Coupe les pommes de terre en morceaux et fais-les revenir à la poêle avec huile d’olive et herbes jusqu’à doré.
2. Sors le steak du frigo 10 min avant la cuisson pour qu’il soit moins froid.
3. Grille le steak 3 min de chaque côté selon l’épaisseur (sel très léger ou aucun).
4. Compose la salade d’épinards frais et tomates avec citron et huile d’olive.
5. Laisse reposer le steak 2 min, puis dresse avec pommes de terre et salade.
""": """
1. Cut the potatoes into pieces and sauté in a skillet with olive oil and herbs until golden.
2. Take the steak out of the fridge 10 min before cooking so it’s less cold.
3. Grill the steak 3 min per side depending on thickness (very light salt or none).
4. Build the fresh spinach and tomato salad with lemon and olive oil.
5. Rest the steak 2 min, then plate with potatoes and salad.
""",
        // Poulet Rôti Salade Avocat
        """
1. Préchauffe le four à 200°C.
2. Marine le poulet 10 min avec citron, herbes et huile infusée à l’ail.
3. Enfourne le poulet 22 min à 200°C jusqu’à doré.
4. Pendant la cuisson, coupe roquette, concombre, tomates et avocat.
5. Compose la salade et arrose de citron + huile d’olive.
6. Tranche le poulet et sers avec la salade.
""": """
1. Preheat the oven to 400°F (200°C).
2. Marinate the chicken 10 min with lemon, herbs, and garlic-infused oil.
3. Roast the chicken 22 min at 400°F until golden.
4. While it cooks, prep arugula, cucumber, tomatoes, and avocado.
5. Build the salad and dress with lemon + olive oil.
6. Slice the chicken and serve with the salad.
""",
        // Dinde Brocoli Riz Basmati
        """
1. Préchauffe le four à 200°C et lance la cuisson du riz basmati.
2. Coupe brocoli et courgette, mélange avec citron et huile infusée à l’ail.
3. Rôtis les légumes 15 min à 200°C.
4. Poêle la dinde 5 min de chaque côté à feu moyen.
5. Dresse riz, dinde et légumes rôtis dans l’assiette.
""": """
1. Preheat the oven to 400°F (200°C) and start the basmati rice.
2. Cut broccoli and zucchini, toss with lemon and garlic-infused oil.
3. Roast the vegetables 15 min at 400°F.
4. Pan-sear the turkey 5 min per side over medium heat.
5. Plate rice, turkey, and roasted vegetables.
""",
        // Cabillaud Carottes Salade Mâche
        """
1. Préchauffe le four à 200°C.
2. Coupe les carottes, mélange avec thym et huile d’olive, rôtis 20 min.
3. Assaisonne le cabillaud citron-herbes, puis enfourne 14 min à 190°C.
4. Prépare la salade mâche-concombre avec citron et huile d’olive.
5. Dresse poisson, carottes et salade dans l’assiette.
""": """
1. Preheat the oven to 400°F (200°C).
2. Cut the carrots, toss with thyme and olive oil, and roast 20 min.
3. Season the cod with lemon and herbs, then bake 14 min at 375°F (190°C).
4. Prep the lamb’s lettuce–cucumber salad with lemon and olive oil.
5. Plate fish, carrots, and salad.
""",
        // Assiette OMAD Steak Patate Avocat
        """
1. Préchauffe le four à 200°C.
2. Coupe la patate douce, rôtis 22 min à 200°C avec un filet d’huile.
3. Grille le steak 3 min de chaque côté, puis laisse reposer 2 min.
4. Prépare la salade roquette-concombre et tranche l’avocat.
5. Dresse tout sur une grande assiette : steak, patate, salade, avocat.
""": """
1. Preheat the oven to 400°F (200°C).
2. Cut the sweet potato and roast 22 min at 400°F with a drizzle of oil.
3. Grill the steak 3 min per side, then rest 2 min.
4. Prep the arugula-cucumber salad and slice the avocado.
5. Plate everything on a large plate: steak, sweet potato, salad, avocado.
""",
        // Bowl OMAD Poulet Quinoa Salade
        """
1. Cuis le quinoa selon le paquet, égoutte et laisse tiédir.
2. Grille le poulet 6 min de chaque côté, puis tranche-le.
3. Coupe tomates, concombre et avocat ; prépare la roquette.
4. Compose le bowl : quinoa, salade, légumes et poulet.
5. Arrose d’une vinaigrette citron + huile d’olive maison.
""": """
1. Cook the quinoa per package, drain, and let cool slightly.
2. Grill the chicken 6 min per side, then slice it.
3. Cut tomatoes, cucumber, and avocado; prep the arugula.
4. Build the bowl: quinoa, salad, vegetables, and chicken.
5. Drizzle a homemade lemon + olive oil dressing.
""",
        // Banane Skyr
        """
1. Coupe la banane en rondelles.
2. Sers avec le skyr nature sans lactose à côté.
""": """
1. Slice the banana into rounds.
2. Serve with the lactose-free plain skyr on the side.
""",
        // Ananas Dinde Rôtie
        """
1. Coupe l’ananas frais en tranches ou en cubes.
2. Émince la dinde rôtie maison (pas de charcuterie salée).
3. Coupe le concombre en bâtonnets.
4. Dispose le tout dans une assiette et sers frais.
""": """
1. Cut the fresh pineapple into slices or cubes.
2. Slice the homemade roast turkey (no salty deli meat).
3. Cut the cucumber into sticks.
4. Arrange everything on a plate and serve fresh.
""",
    ]

    /// Ingrédients catalogue FR → EN.
    static let itemNamesFRToEN: [String: String] = [
        "Amandes non salées": "Unsalted almonds",
        "Ananas frais": "Fresh pineapple",
        "Avocat bien mûr": "Very ripe avocado",
        "Avocat mûr": "Ripe avocado",
        "Banane": "Banana",
        "Banane jaune peu tachetée": "Yellow banana, lightly spotted",
        "Blanc de poulet (label rouge)": "Chicken breast (quality label)",
        "Blanc de poulet grillé": "Grilled chicken breast",
        "Blanc de poulet grillé (label rouge)": "Grilled chicken breast (quality label)",
        "Blanc de poulet label rouge": "Chicken breast (quality label)",
        "Brocoli + courgette, huile infusée à l'ail": "Broccoli + zucchini, garlic-infused oil",
        "Bœuf haché 5% MG frais": "Fresh 5% ground beef",
        "Carottes rôties au thym": "Thyme-roasted carrots",
        "Citron + ail + cumin + huile d'olive": "Lemon + garlic + cumin + olive oil",
        "Citron + aneth ou ciboulette": "Lemon + dill or chives",
        "Concombre": "Cucumber",
        "Concombre + citron + huile d'olive": "Cucumber + lemon + olive oil",
        "Dinde rôtie maison froide": "Cold homemade roast turkey",
        "Escalope de dinde": "Turkey cutlet",
        "Filet de cabillaud frais": "Fresh cod fillet",
        "Filet de lieu noir frais": "Fresh pollock fillet",
        "Haricots verts poêlés": "Sautéed green beans",
        "Huile d'olive": "Olive oil",
        "Huile d'olive + citron": "Olive oil + lemon",
        "Huile d'olive extra vierge": "Extra-virgin olive oil",
        "Kiwi": "Kiwi",
        "Miel": "Honey",
        "Myrtilles": "Blueberries",
        "Patate douce (très grosse ou 2 moyennes)": "Sweet potato (1 large or 2 medium)",
        "Patate douce rôtie": "Roasted sweet potato",
        "Pavé de saumon frais": "Fresh salmon fillet",
        "Poivrons + fenouil rôtis": "Roasted peppers + fennel",
        "Pommes de terre fermières rôties": "Roasted farm potatoes",
        "Pommes de terre fermières sautées": "Sautéed farm potatoes",
        "Quinoa cuit": "Cooked quinoa",
        "Riz basmati semi-complet": "Brown basmati rice",
        "Roquette + tomates cerises": "Arugula + cherry tomatoes",
        "Salade composée (roquette, concombre)": "Mixed salad (arugula, cucumber)",
        "Salade composée (roquette, tomate, concombre)": "Mixed salad (arugula, tomato, cucumber)",
        "Salade concombre menthe": "Cucumber mint salad",
        "Salade fenouil + concombre": "Fennel + cucumber salad",
        "Salade mâche + concombre": "Lamb’s lettuce + cucumber salad",
        "Salade pico (tomates, oignon rouge, poivron, coriandre)": "Pico salad (tomatoes, red onion, bell pepper, cilantro)",
        "Salade roquette + concombre": "Arugula + cucumber salad",
        "Salade verte + avocat": "Green salad + avocado",
        "Salade épinards + tomates": "Spinach + tomato salad",
        "Saumon frais": "Fresh salmon",
        "Skyr nature sans lactose": "Lactose-free plain skyr",
        "Steak maigre (rumsteck)": "Lean steak (rump)",
        "Tomates cerises": "Cherry tomatoes",
        "Viande hachée maigre (dinde, poulet ou bœuf 5%)": "Lean ground meat (turkey, chicken, or 5% beef)",
        "Yaourt nature ou kéfir nature": "Plain yogurt or plain kefir",
        "Œufs plein air": "Pasture-raised eggs",
    ]

    /// Quantités avec libellé FR → EN.
    static let quantitiesFRToEN: [String: String] = [
        "1 c. à café": "1 tsp",
        "1 c. à soupe": "1 tbsp",
        "1/2 citron": "1/2 lemon",
        "160 g cuit": "160 g cooked",
        "180 g cuit": "180 g cooked",
    ]

    static func normalizedPrepKey(_ prep: String) -> String {
        prep
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
