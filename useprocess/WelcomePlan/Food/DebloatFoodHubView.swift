import SwiftUI

/// Hub Debloat — catalogue recettes Process + aliments à privilégier / éviter.
struct DebloatFoodHubView: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool
    /// `true` quand la vue est montée en root d'onglet persistant plutôt qu'en présentation modale — masque le bouton de fermeture.
    var isTabRoot: Bool = false

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store = WelcomePlanStore.shared
    @Bindable private var prefs = DebloatFoodPreferenceStore.shared

    @State private var foodSearchQuery = ""
    @State private var showsAllFoodsPage = false
    @State private var selectedMealSlot: MealTimeSlot = .breakfast
    @State private var selectedFood: DebloatFoodItem?
    @State private var selectedCatalogMeal: CatalogMealSelection?
    @State private var cachedRecipeSections: [ProcessDebloatMealLibrary.CatalogSection] = ProcessDebloatMealLibrary.fullCatalogSections()

    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var recipeSections: [ProcessDebloatMealLibrary.CatalogSection] {
        cachedRecipeSections
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerRow
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                foodSearchField
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 38) {
                        browseByTypeSection

                        smartMealPicksSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
                .processTransparentScrollSurface()
            }
            .toolbar {
                if !isTabRoot {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppCopy.close) { dismiss() }
                    }
                }
            }
            .navigationDestination(isPresented: $showsAllFoodsPage) {
                DebloatFoodCatalogPageView(selectedFood: $selectedFood)
            }
            .sheet(item: $selectedFood) { food in
                DebloatFoodDetailSheet(food: food)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $selectedCatalogMeal) { selection in
                PlanMealDetailView(
                    entry: selection.entry,
                    plan: livePlan,
                    day: day,
                    isEditable: isEditable,
                    onDismiss: { selectedCatalogMeal = nil }
                )
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .processStackedToasts(bottomInset: 28)
        .onAppear { prefs.reload() }
    }

    // MARK: - Header

    private var navigationTitle: String {
        AppCopy.t("Qu'est-ce qu'on mange\naujourd'hui ?", en: "What are you craving\ntoday?")
    }

    private var latestScan: FaceScanResult? {
        FaceScanHistoryStore.shared.history.first
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Group {
                    if let latestScan {
                        FaceScanRecordingMediaView(result: latestScan, height: 48, displayMode: .thumbnail)
                    } else {
                        Circle()
                            .fill(theme.primaryText.opacity(theme.isDark ? 0.08 : 0.05))
                            .overlay {
                                Image(systemName: "face.smiling")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(theme.secondaryText)
                            }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())

                Spacer(minLength: 12)

                Button {
                    HapticManager.shared.impact(.light)
                    CoachPlanNavigationBridge.shared.focusHydrationOnHome()
                } label: {
                    ProcessHydrationDropIcon.image(side: 22)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.processPlain)
                .processGlassEffect(in: Circle(), interactive: true)
                .accessibilityLabel(AppCopy.t("Ouvrir l'hydratation", en: "Open hydration"))
            }

            Text(navigationTitle)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Browse by type

    /// Légumes / fruits / potassium / boissons drainantes d'abord — les vrais aliments Debloat,
    /// pas les fruits à coque (score élevé mais anecdotiques dans le protocole).
    private static let browseCategoryPriority: [DebloatFoodCategory: Int] = [
        .legumes: 0,
        .potassium: 1,
        .fruits: 2,
        .drinks: 3,
        .herbs: 4,
        .protein: 5,
        .magnesium: 6
    ]

    /// D'abord les aliments avec une vraie icône 3D (les plus reconnaissables, aucune répétition
    /// d'emoji), puis le reste trié par catégorie / score — jamais les obscurs (roquette, mâche…) en tête.
    private var topRankedFoods: [DebloatFoodItem] {
        let all = DebloatFoodCatalog.preferFoods
        let illustrated = DebloatFoodIllustrationTable.byId.keys
        let (withAsset, rest) = all.reduce(into: ([DebloatFoodItem](), [DebloatFoodItem]())) { acc, food in
            if illustrated.contains(food.id) {
                acc.0.append(food)
            } else {
                acc.1.append(food)
            }
        }
        let orderedWithAsset = withAsset.sorted {
            DebloatFoodIllustrationTable.displayOrder(for: $0.id) < DebloatFoodIllustrationTable.displayOrder(for: $1.id)
        }
        let orderedRest = rest.sorted { lhs, rhs in
            let lhsRank = Self.browseCategoryPriority[lhs.category] ?? 9
            let rhsRank = Self.browseCategoryPriority[rhs.category] ?? 9
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.debloatScore > rhs.debloatScore
        }
        return orderedWithAsset + orderedRest
    }

    private var browseByTypeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                HapticManager.shared.impact(.light)
                showsAllFoodsPage = true
            } label: {
                HStack(spacing: 4) {
                    Text(AppCopy.t("Aliments Debloat", en: "Debloat Foods"))
                        .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .buttonStyle(.processPlain)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(topRankedFoods) { food in
                        Button {
                            HapticManager.shared.selection()
                            selectedFood = food
                        } label: {
                            VStack(spacing: 8) {
                                Group {
                                    if let assetName = food.illustrationAssetName {
                                        Image(assetName)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(10)
                                    } else {
                                        Text(food.emoji)
                                            .font(.system(size: 30))
                                    }
                                }
                                .frame(width: 68, height: 68)
                                .processGlassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                                Text(food.localizedName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(1)
                                    .frame(width: 72)
                            }
                        }
                        .buttonStyle(.processPlain)
                        .contentShape(Rectangle())
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.7)
                        }
                    }

                    Button {
                        HapticManager.shared.impact(.light)
                        showsAllFoodsPage = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(theme.primaryText)
                                .frame(width: 68, height: 68)
                                .processGlassEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
                            Text(AppCopy.t("Tous les\naliments", en: "All\nFoods"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(width: 72)
                        }
                    }
                    .buttonStyle(.processPlain)
                }
                .scrollTargetLayout()
                .padding(.trailing, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .padding(.horizontal, -20)
            .padding(.leading, 4)
        }
    }

    // MARK: - Smart meal picks

    private var smartMealPicksTileSize: CGFloat { PlanMealCatalogLayout.tileSize + 44 }

    private var mealSlotOptions: [MealTimeSlot] {
        livePlan.configuredMealSlots.isEmpty
            ? [.breakfast, .lunch, .dinner]
            : livePlan.configuredMealSlots
    }

    private var effectiveSelectedSlot: MealTimeSlot {
        mealSlotOptions.contains(selectedMealSlot) ? selectedMealSlot : (mealSlotOptions.first ?? .lunch)
    }

    /// Titre remplacé par des onglets cliquables Petit déj / Déjeuner / Dîner.
    private var mealSlotTabs: some View {
        HStack(spacing: 18) {
            ForEach(mealSlotOptions, id: \.self) { slot in
                Button {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        selectedMealSlot = slot
                    }
                } label: {
                    Text(slot.displayTitle)
                        .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                        .foregroundStyle(effectiveSelectedSlot == slot ? theme.primaryText : theme.secondaryText.opacity(0.55))
                }
                .buttonStyle(.processPlain)
            }
        }
    }

    @ViewBuilder
    private var smartMealPicksSection: some View {
        let slot = effectiveSelectedSlot
        let todayEntry = PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
            .first { $0.slot == slot }
        let sectionMeals = recipeSections.first { $0.slot == slot }?.meals ?? []

        VStack(alignment: .leading, spacing: 14) {
            mealSlotTabs

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PlanMealCatalogLayout.spacing) {
                    if let todayEntry {
                        glassMealCard(
                            meal: todayEntry.meal,
                            slot: todayEntry.slot,
                            onTap: { selectedCatalogMeal = CatalogMealSelection(entry: todayEntry) }
                        )
                    }

                    ForEach(sectionMeals, id: \.name) { meal in
                        glassMealCard(
                            meal: meal,
                            slot: slot,
                            onTap: {
                                selectedCatalogMeal = CatalogMealSelection(
                                    entry: PlanDayMealEntry.catalog(meal: meal, slot: slot, plan: livePlan, day: day)
                                )
                            }
                        )
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, 4)
                .padding(.trailing, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .padding(.horizontal, -20)
            .padding(.leading, 4)
        }
        .id(slot)
    }

    /// Carte repas — titre au-dessus, photo en dessous, cadre liquid glass (comme "Smart Meal Picks").
    private func glassMealCard(meal: MealSuggestionContent, slot: MealTimeSlot, onTap: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            VStack(spacing: 10) {
                Text(meal.localizedDisplayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: smartMealPicksTileSize - 20, height: 38, alignment: .center)

                PlanMealCatalogCard(
                    meal: meal,
                    slot: slot,
                    plan: livePlan,
                    day: day,
                    tileSize: smartMealPicksTileSize - 20,
                    onTap: onTap
                )
                .allowsHitTesting(false)
            }
            .padding(10)
            .frame(width: smartMealPicksTileSize, height: smartMealPicksTileSize + 58)
        }
        .buttonStyle(.processPlain)
        .processGlassEffect(in: RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.94)
                .opacity(phase.isIdentity ? 1 : 0.82)
        }
    }

    private var foodSearchField: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.secondaryText)
                TextField(
                    AppCopy.t("Rechercher un aliment…", en: "Search a food…"),
                    text: $foodSearchQuery
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !foodSearchQuery.isEmpty {
                    Button {
                        foodSearchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.processPlain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .processGlassEffect(in: Capsule(), interactive: false)

            Button {
                HapticManager.shared.impact(.light)
                CoachPlanNavigationBridge.shared.openMealScan()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.processPlain)
            .processGlassEffect(in: Circle(), interactive: true)
            .accessibilityLabel(AppCopy.t("Scanner un aliment", en: "Scan a food"))
        }
    }

}

// MARK: - Hub enums (symbols)

extension DebloatFoodItem {
    /// Emoji propre à chaque aliment (par id catalogue) — repli sur la catégorie si non couvert.
    var emoji: String {
        DebloatFoodEmojiTable.byId[id] ?? category.fallbackEmoji
    }

    /// Icône 3D réelle (asset catalogue) quand disponible — sinon nil, repli sur l'emoji.
    var illustrationAssetName: String? {
        DebloatFoodIllustrationTable.byId[id]
    }
}

private enum DebloatFoodIllustrationTable {
    static let byId: [String: String] = [
        "epinards": "food_spinach",
        "concombre": "food_cucumber",
        "tomate": "food_tomato",
        "carotte": "food_carrot",
        "fraises": "food_strawberry",
        "brocoli": "food_broccoli",
        "kiwi": "food_kiwi",
        "aubergine": "food_eggplant",
        "pasteque": "food_watermelon",
        "citron": "food_lemon",
        "avocat": "food_avocado",
        "banane": "food_banana"
    ]

    /// Ordre d'affichage — les plus évidents / reconnaissables d'abord.
    private static let order: [String] = [
        "banane", "avocat", "tomate", "concombre", "carotte", "epinards",
        "brocoli", "fraises", "citron", "kiwi", "pasteque", "aubergine"
    ]

    static func displayOrder(for id: String) -> Int {
        order.firstIndex(of: id) ?? order.count
    }
}

private extension DebloatFoodCategory {
    var fallbackEmoji: String {
        switch self {
        case .legumes: return "🥦"
        case .fruits: return "🍎"
        case .potassium: return "🍌"
        case .magnesium: return "🌰"
        case .protein: return "🍳"
        case .herbs: return "🌿"
        case .drinks: return "🥤"
        case .avoidSodium: return "🧂"
        case .avoidOther: return "🍟"
        }
    }
}

private enum DebloatFoodEmojiTable {
    static let byId: [String: String] = [
        // Légumes
        "concombre": "🥒", "courgette": "🥒", "asperge": "🥦", "celeri": "🥬",
        "fenouil": "🌿", "artichaut": "🥬", "poireau": "🥬", "epinards": "🥬",
        "blettes": "🥬", "tomate": "🍅", "tomate-concentree": "🍅", "poivron": "🫑",
        "radis-noir": "🥕", "aubergine": "🍆", "carotte": "🥕", "brocoli": "🥦",
        "choux-bruxelles": "🥬", "haricots-verts": "🫛", "roquette": "🥬",
        "mache": "🥬", "betterave": "🥕", "champignons": "🍄",
        // Fruits
        "pasteque": "🍉", "melon": "🍈", "ananas": "🍍", "citron": "🍋",
        "orange": "🍊", "pamplemousse": "🍊", "citron-vert": "🍋", "kiwi": "🥝",
        "fraises": "🍓", "framboises": "🍓", "myrtilles": "🫐", "mures": "🫐",
        "banane": "🍌", "avocat": "🥑", "pomme": "🍎", "figue": "🍇",
        "abricot": "🍑", "abricots-secs": "🍑", "peche": "🍑", "raisins-secs": "🍇",
        // Potassium (féculents / légumineuses)
        "dattes": "🌴", "patate-douce": "🍠", "pomme-de-terre": "🥔",
        "lentilles": "🫘", "haricots-blancs": "🫘", "haricots-rouges": "🫘",
        "pois-chiches": "🫘", "pois-casses": "🫘",
        // Magnésium (noix / graines / céréales)
        "amandes": "🌰", "pistaches": "🌰", "graines-courge": "🌱",
        "noix-cajou": "🌰", "noix-bresil": "🌰", "chia": "🌱", "lin": "🌱",
        "sesame": "🌱", "tournesol": "🌻", "chocolat-noir": "🍫", "cacao": "🍫",
        "flocons-avoine": "🌾", "quinoa": "🌾", "sarrasin": "🌾", "noisettes": "🌰",
        // Protéines
        "poulet": "🍗", "dinde": "🦃", "oeufs": "🥚", "saumon": "🐟",
        "sardines": "🐟", "maquereau": "🐟", "thon": "🐟", "poisson-blanc": "🐟",
        "yaourt-nature": "🥛", "fromage-blanc": "🧀", "kefir": "🥛",
        "tofu": "🍳", "tempeh": "🍳",
        // Herbes / condiments
        "persil": "🌿", "gingembre": "🫚", "cumin": "🌿", "ail": "🧄",
        "oignon": "🧅", "basilic": "🌿", "thym": "🌿", "origan": "🌿",
        "menthe": "🌿", "herbes-provence": "🌿", "vinaigre-cidre": "🍏",
        // Boissons
        "eau-plate": "💧", "hepar": "💧", "contrex": "💧", "rozana": "💧",
        "courmayeur": "💧", "the-vert": "🍵", "tisane-ortie": "🍵",
        "tisane-queues-cerise": "🍵", "tisane-pissenlit": "🍵", "tisane-prele": "🍵",
        "tisane-bouleau": "🍵", "tisane-fenouil": "🍵", "tisane-hibiscus": "🍵",
        "tisane-reine-pres": "🍵", "tisane-camomille": "🍵", "eau-citronnee": "🍋",
        "eau-concombre-menthe": "🥒", "jus-ananas": "🍍", "eau-coco": "🥥"
    ]
}

extension DebloatFoodHubTab {
    var symbolName: String {
        switch self {
        case .prefer: return "hand.thumbsup.fill"
        case .avoid: return "hand.raised.fill"
        case .tastes: return "heart.fill"
        }
    }
}

/// Identité unique pour le détail catalogue (plusieurs repas / même créneau).
private struct CatalogMealSelection: Identifiable {
    let entry: PlanDayMealEntry
    var id: String { "\(entry.slot.rawValue)-\(entry.meal.name)" }
}

// MARK: - Row

struct DebloatFoodRow: View {
    @Environment(\.appTheme) private var theme
    @Bindable private var prefs = DebloatFoodPreferenceStore.shared
    let food: DebloatFoodItem
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                tierIndicator

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(food.localizedName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                        Text(food.tier.badgeLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(badgeColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(badgeColor.opacity(0.14), in: Capsule())
                    }
                    Text(food.localizedWhyItHelpsOrHurts)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text("\(food.debloatScore)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                    .monospacedDigit()
                Button {
                    prefs.toggleLike(food.id)
                } label: {
                    Image(systemName: prefs.isLiked(food.id) ? "heart.fill" : "heart")
                        .foregroundStyle(prefs.isLiked(food.id) ? Color.pink : theme.secondaryText)
                }
                .buttonStyle(.processPlain)
            }
            .padding(12)
            .processInteractiveGlassSurface(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.processPlain)
    }

    private var tierIndicator: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(badgeColor)
            .frame(width: 4, height: 44)
    }

    private var badgeColor: Color {
        switch food.tier {
        case .hero: return Color(red: 0.24, green: 0.70, blue: 0.46)
        case .prefer: return Color(red: 0.35, green: 0.62, blue: 0.95)
        case .moderate: return Color.orange
        case .avoid: return Color.red.opacity(0.85)
        }
    }
}

// MARK: - Detail

private struct DebloatFoodDetailSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable private var prefs = DebloatFoodPreferenceStore.shared
    @Bindable private var store = WelcomePlanStore.shared
    let food: DebloatFoodItem

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(food.tier.badgeLabel)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                        Spacer()
                        Text(AppCopy.t("Score ≈\(food.debloatScore)", en: "Score ≈\(food.debloatScore)"))
                            .font(.title2.weight(.bold).monospacedDigit())
                    }

                    Text(food.localizedWhyItHelpsOrHurts)
                        .font(.body)
                        .foregroundStyle(theme.primaryText)

                    metricsRow

                    if let portion = food.localizedPortionHint {
                        Label(portion, systemImage: "scalemass")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    if food.exceedsSaltLabelThreshold {
                        Text(AppCopy.t(
                            "Seuil dépassé : > 1,5 g de sel / 100 g — à éviter pour le visage.",
                            en: "Over threshold: > 1.5 g salt / 100 g — avoid for your face."
                        ))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.orange)
                    }

                    let swaps = DebloatFoodCatalog.swapItems(for: food)
                    if !swaps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(AppCopy.t("Alternatives visage", en: "Face-friendly swaps"))
                                .font(.headline)
                            ForEach(swaps) { swap in
                                Text("→ \(swap.localizedName)")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button(
                            prefs.isLiked(food.id)
                                ? AppCopy.t("Liked", en: "Liked")
                                : AppCopy.t("Like", en: "Like")
                        ) {
                            prefs.toggleLike(food.id)
                        }
                        .processGlassButton(in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button(
                            prefs.hasAtHome(food.id)
                                ? AppCopy.t("Chez moi", en: "At home")
                                : AppCopy.t("J’ai chez moi", en: "I have this")
                        ) {
                            prefs.toggleHaveAtHome(food.id)
                        }
                        .processGlassButton(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if food.tier != .avoid {
                        Button(AppCopy.t("Ajouter aux courses", en: "Add to groceries")) {
                            store.mergeShoppingItems([
                                MealShoppingItem(
                                    name: food.name,
                                    quantity: food.portionHint ?? "1"
                                )
                            ])
                            dismiss()
                        }
                        .processGlassButton(in: Capsule())
                        .processInvertedGlassEffect(in: Capsule())
                    } else if let swap = swaps.first {
                        Button(AppCopy.t(
                            "Remplacer par \(swap.localizedName)",
                            en: "Replace with \(swap.localizedName)"
                        )) {
                            store.mergeShoppingItems([
                                MealShoppingItem(name: swap.name, quantity: swap.portionHint ?? "1")
                            ])
                            dismiss()
                        }
                        .processGlassButton(in: Capsule())
                        .processInvertedGlassEffect(in: Capsule())
                    }

                    Text(AppCopy.t(
                        "Valeurs approximatives pour 100 g. Ce n’est pas un avis médical.",
                        en: "Approximate values per 100 g. This is not medical advice."
                    ))
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(20)
            }
            .navigationTitle(food.localizedName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.close) { dismiss() }
                }
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metric("K", food.potassiumMgPer100g.map { "≈\(Int($0)) mg" } ?? "—")
            metric("Na", food.sodiumMgPer100g.map { "≈\(Int($0)) mg" } ?? "—")
            metric("Mg", food.magnesiumMgPer100g.map { "≈\(Int($0)) mg" } ?? "—")
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .processGlassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous), interactive: false)
    }
}
