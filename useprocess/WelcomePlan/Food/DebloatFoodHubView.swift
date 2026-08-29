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

    @State private var mode: DebloatFoodHubMode = .recipes
    @State private var tab: DebloatFoodHubTab = .prefer
    @State private var foodSearchQuery = ""
    @State private var selectedFood: DebloatFoodItem?
    @State private var selectedCatalogMeal: CatalogMealSelection?
    @State private var showGrocery = false
    @State private var showGeneratedRecipes = false
    @State private var groceryRequest = DebloatGroceryRequest()
    @State private var groceryPlan: DebloatGroceryPlan?
    @State private var recipeSeed = 0

    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var recipeSections: [ProcessDebloatMealLibrary.CatalogSection] {
        ProcessDebloatMealLibrary.fullCatalogSections()
    }

    private var totalRecipeCount: Int {
        ProcessDebloatMealLibrary.fullCatalogMealCount()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                hubSummaryStrip
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                modePicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                if mode == .foods {
                    foodTabPicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    if tab != .tastes {
                        foodSearchField
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                    }
                }

                ScrollView(showsIndicators: false) {
                    Group {
                        if mode == .foods {
                            foodsContent
                        } else {
                            recipesCatalogContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, mode == .foods ? 120 : 40)
                }
                .processTransparentScrollSurface()
            }
            .safeAreaInset(edge: .bottom) {
                if mode == .foods {
                    bottomCTA
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isTabRoot {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppCopy.close) { dismiss() }
                    }
                }
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
            .sheet(isPresented: $showGrocery) {
                grocerySheet
            }
            .sheet(isPresented: $showGeneratedRecipes) {
                recipesSheet
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: mode)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: tab)
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .processStackedToasts(bottomInset: 28)
        .onAppear { prefs.reload() }
    }

    // MARK: - Header

    private var navigationTitle: String {
        switch mode {
        case .recipes:
            return AppCopy.t("Catalogue de recettes", en: "Recipe catalog")
        case .foods:
            return AppCopy.t("Aliments Debloat", en: "Debloat Foods")
        }
    }

    private var hubSummaryStrip: some View {
        HStack(spacing: 10) {
            summaryChip(
                value: "\(totalRecipeCount)",
                label: AppCopy.t("recettes", en: "recipes"),
                symbol: "fork.knife",
                isActive: mode == .recipes
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    mode = .recipes
                }
            }

            summaryChip(
                value: "\(DebloatFoodCatalog.totalFoodCount)",
                label: AppCopy.t("aliments", en: "foods"),
                symbol: "leaf.fill",
                isActive: mode == .foods
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    mode = .foods
                }
            }
        }
    }

    private func summaryChip(
        value: String,
        label: String,
        symbol: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isActive ? (theme.isDark ? Color.black : Color.white) : theme.secondaryText)

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? (theme.isDark ? Color.black : Color.white) : theme.primaryText)
                        .monospacedDigit()
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isActive ? (theme.isDark ? Color.black.opacity(0.72) : Color.white.opacity(0.82)) : theme.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background {
                if isActive {
                    Capsule().fill(theme.primaryText)
                } else {
                    Capsule().fill(theme.primaryText.opacity(theme.isDark ? 0.08 : 0.05))
                }
            }
        }
        .buttonStyle(.processPlain)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(DebloatFoodHubMode.allCases) { item in
                hubSegmentButton(
                    title: item.title,
                    symbol: item.symbolName,
                    isSelected: mode == item
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        mode = item
                    }
                }
            }
        }
    }

    private var foodTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(DebloatFoodHubTab.allCases) { item in
                hubSegmentButton(
                    title: item.title,
                    symbol: item.symbolName,
                    isSelected: tab == item,
                    compact: true
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        tab = item
                    }
                }
            }
        }
    }

    private func hubSegmentButton(
        title: String,
        symbol: String,
        isSelected: Bool,
        compact: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                Text(title)
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? (theme.isDark ? Color.black : Color.white) : theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 9 : 11)
            .background {
                if isSelected {
                    Capsule().fill(theme.primaryText)
                }
            }
        }
        .buttonStyle(.processPlain)
        .overlay {
            if !isSelected {
                Capsule()
                    .strokeBorder(theme.primaryText.opacity(theme.isDark ? 0.12 : 0.08), lineWidth: 0.5)
            }
        }
    }

    private var foodSearchField: some View {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .processGlassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: false)
    }

    // MARK: - Contents

    @ViewBuilder
    private var foodsContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if tab == .prefer {
                protocolRulesCard
            }

            if tab == .tastes {
                tastesContent
            } else if tab == .avoid {
                avoidFoodsContent
            } else {
                preferFoodsContent
            }
        }
    }

    private var preferFoodsContent: some View {
        let sections = DebloatFoodCatalog.filteredSections(
            DebloatFoodCatalog.preferSections(),
            query: foodSearchQuery
        )
        return Group {
            if sections.isEmpty {
                emptyFoodSearch
            } else {
                ForEach(sections) { section in
                    sectionBlock(section)
                }
            }
        }
    }

    private var avoidFoodsContent: some View {
        let avoidBlocks = DebloatFoodCatalog.filteredSections(
            DebloatFoodCatalog.avoidSections(),
            query: foodSearchQuery
        )
        let moderateBlocks = DebloatFoodCatalog.filteredSections(
            DebloatFoodCatalog.moderateSections(),
            query: foodSearchQuery
        )

        return Group {
            if avoidBlocks.isEmpty && moderateBlocks.isEmpty {
                emptyFoodSearch
            } else {
                if !avoidBlocks.isEmpty {
                    tierIntroBlock(
                        title: AppCopy.t("À éviter", en: "Avoid"),
                        subtitle: AppCopy.t(
                            "Sodium, rétention et inflammation — impact direct sur le visage.",
                            en: "Sodium, retention, and inflammation — direct face impact."
                        ),
                        count: DebloatFoodCatalog.avoidFoodCount,
                        tint: Color.red.opacity(0.85)
                    )
                    ForEach(avoidBlocks) { section in
                        sectionBlock(section)
                    }
                }

                if !moderateBlocks.isEmpty {
                    tierIntroBlock(
                        title: AppCopy.t("Avec modération", en: "In moderation"),
                        subtitle: AppCopy.t(
                            "OK parfois — pas en base quotidienne si tu vises un visage net.",
                            en: "OK sometimes — not as a daily base if you want a sharper face."
                        ),
                        count: DebloatFoodCatalog.moderateFoodCount,
                        tint: Color.orange
                    )
                    ForEach(moderateBlocks) { section in
                        sectionBlock(section)
                    }
                }
            }
        }
    }

    private func tierIntroBlock(title: String, subtitle: String, count: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14), in: Capsule())
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 4)
    }

    private var protocolRulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                AppCopy.t("Règles du protocole", en: "Protocol rules"),
                systemImage: "checkmark.seal.fill"
            )
            .font(.headline)
            .foregroundStyle(theme.primaryText)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(ProcessDebloatMealLibrary.rules.enumerated()), id: \.offset) { _, rule in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color(red: 0.24, green: 0.70, blue: 0.46))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(rule)
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .processInteractiveGlassSurface(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recipesCatalogContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            todayMealsCatalogSection

            ForEach(recipeSections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(localizedCatalogSectionTitle(section))
                            .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                        Text("\(section.meals.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(theme.primaryText.opacity(theme.isDark ? 0.10 : 0.06))
                            )
                    }

                    PlanMealCatalogCarousel(
                        meals: section.meals,
                        slot: section.slot,
                        plan: livePlan,
                        day: day,
                        onOpen: { meal in
                            selectedCatalogMeal = CatalogMealSelection(
                                entry: PlanDayMealEntry.catalog(
                                    meal: meal,
                                    slot: section.slot,
                                    plan: livePlan,
                                    day: day
                                )
                            )
                        }
                    )
                    .padding(.horizontal, -20)
                    .padding(.leading, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var todayMealsCatalogSection: some View {
        let todayEntries = PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
        if !todayEntries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(AppCopy.t("Repas du jour", en: "Today's meals"))
                    .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                    .foregroundStyle(theme.primaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PlanMealCatalogLayout.spacing) {
                        ForEach(todayEntries) { entry in
                            PlanMealCatalogCard(
                                meal: entry.meal,
                                slot: entry.slot,
                                plan: livePlan,
                                day: day,
                                onTap: {
                                    selectedCatalogMeal = CatalogMealSelection(entry: entry)
                                }
                            )
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.78)
                            }
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
        }
    }

    // MARK: - Lists

    private func sectionBlock(_ section: DebloatFoodCatalogSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            VStack(spacing: 8) {
                ForEach(section.items) { food in
                    DebloatFoodRow(food: food) {
                        selectedFood = food
                    }
                }
            }
        }
    }

    private var tastesContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if prefs.likedFoods.isEmpty {
                emptyTastes
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(AppCopy.t("Tes likes", en: "Your likes"))
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                    ForEach(prefs.likedFoods) { food in
                        DebloatFoodRow(food: food) { selectedFood = food }
                    }
                }
            }

            if !prefs.haveAtHomeFoods.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(AppCopy.t("Déjà chez toi", en: "Already at home"))
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                    ForEach(prefs.haveAtHomeFoods) { food in
                        DebloatFoodRow(food: food) { selectedFood = food }
                    }
                }
            }
        }
    }

    private var emptyTastes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Aucun like pour l’instant", en: "No likes yet"))
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            Text(AppCopy.t(
                "Like des aliments dans Privilégier pour générer courses et recettes visage dégonflé.",
                en: "Like foods in Prefer to generate groceries and debloat face recipes."
            ))
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .processInteractiveGlassSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyFoodSearch: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Aucun résultat", en: "No results"))
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            Text(AppCopy.t(
                "Essaie un autre mot — ex. concombre, saumon, charcuterie.",
                en: "Try another word — e.g. cucumber, salmon, deli meat."
            ))
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .processInteractiveGlassSurface(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - CTA

    @ViewBuilder
    private var bottomCTA: some View {
        VStack(spacing: 10) {
            Button {
                switch tab {
                case .prefer, .tastes:
                    showGrocery = true
                case .avoid:
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        tab = .prefer
                    }
                }
            } label: {
                Text(
                    tab == .avoid
                        ? AppCopy.t("Voir les aliments à privilégier", en: "See foods to prefer")
                        : AppCopy.t("Générer ma liste de courses", en: "Generate my grocery list")
                )
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .processGlassButton(in: Capsule())
            .processInvertedGlassEffect(in: Capsule())

            if tab != .avoid {
                Button(AppCopy.t("Créer des recettes avec mes likes", en: "Create recipes from my likes")) {
                    showGeneratedRecipes = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Grocery sheet

    private var grocerySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(AppCopy.t("Budget", en: "Budget"))
                        .font(.headline)
                    Picker(AppCopy.t("Budget", en: "Budget"), selection: $groceryRequest.budget) {
                        ForEach(DebloatGroceryBudget.allCases) { budget in
                            Text(budget.title).tag(budget)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(groceryRequest.budget.subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)

                    Stepper(
                        AppCopy.t(
                            "Durée : \(groceryRequest.dayCount) jours",
                            en: "Duration: \(groceryRequest.dayCount) days"
                        ),
                        value: $groceryRequest.dayCount,
                        in: 3...7
                    )

                    Toggle(
                        AppCopy.t("Inclure boissons drainantes", en: "Include draining drinks"),
                        isOn: $groceryRequest.includeDrinks
                    )
                    Toggle(
                        AppCopy.t("Inclure herbes anti-sel", en: "Include anti-salt herbs"),
                        isOn: $groceryRequest.includeHerbs
                    )

                    Button(AppCopy.t("Générer la liste visage dégonflé", en: "Generate debloat face list")) {
                        groceryPlan = DebloatGroceryGenerator.generate(request: groceryRequest)
                    }
                    .processGlassButton(in: Capsule())
                    .processInvertedGlassEffect(in: Capsule())

                    if let groceryPlan {
                        ForEach(groceryPlan.groupedByAisle, id: \.aisle.id) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.aisle.title)
                                    .font(.subheadline.weight(.bold))
                                ForEach(group.lines) { line in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(line.localizedName)
                                                .font(.subheadline.weight(.semibold))
                                            Text(line.localizedQuantity)
                                                .font(.caption)
                                                .foregroundStyle(theme.secondaryText)
                                            if line.isAvoidWarning, let swap = line.localizedSuggestedSwapName {
                                                Text(AppCopy.t(
                                                    "Piège Na — préfère \(swap)",
                                                    en: "Sodium trap — prefer \(swap)"
                                                ))
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(Color.orange)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .processInteractiveGlassSurface(
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                }
                            }
                        }

                        Button(AppCopy.t("Ajouter à ma liste de courses", en: "Add to my grocery list")) {
                            store.mergeShoppingItems(DebloatGroceryGenerator.shoppingItems(from: groceryPlan))
                            showToast("Liste ajoutée", en: "List added")
                            showGrocery = false
                        }
                        .processGlassButton(in: Capsule())
                        .processInvertedGlassEffect(in: Capsule())
                    }
                }
                .padding(20)
            }
            .navigationTitle(AppCopy.t("Courses Debloat", en: "Debloat Groceries"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.close) { showGrocery = false }
                }
            }
        }
        .processAppPageBackground()
    }

    // MARK: - Recipes sheet

    private var recipesSheet: some View {
        let slots = livePlan.configuredMealSlots.isEmpty
            ? [MealTimeSlot.lunch, .dinner]
            : livePlan.configuredMealSlots
        let meals = DebloatRecipeComposer.composeDay(
            slots: slots,
            likes: rotatedLikes(seed: recipeSeed)
        )
        let orderedSlots = slots

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(AppCopy.t("Recettes à partir de tes likes", en: "Recipes from your likes"))
                        .font(.title3.weight(.bold))
                    Text(AppCopy.t(
                        "Générateur offline — priorité potassium, zéro aliment à éviter.",
                        en: "Offline generator — potassium first, zero avoid foods."
                    ))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)

                    ForEach(orderedSlots, id: \.self) { slot in
                        if let meal = meals[slot] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(slot.displayTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(theme.secondaryText)
                                Text(meal.localizedDisplayName)
                                    .font(.headline)
                                ForEach(meal.foodItems) { item in
                                    Text("• \(item.ingredientDisplayLine)")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .processInteractiveGlassSurface(
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                        }
                    }

                    Button(AppCopy.t("Injecter dans mes repas du jour", en: "Add to today’s meals")) {
                        guard isEditable else {
                            showToast("Jour non modifiable", en: "Day can't be edited")
                            return
                        }
                        for (slot, meal) in meals {
                            store.saveDraftMeal(dayId: day.id, meal: meal, slot: slot)
                        }
                        showToast("Repas du jour mis à jour", en: "Today's meals updated")
                        showGeneratedRecipes = false
                    }
                    .processGlassButton(in: Capsule())
                    .processInvertedGlassEffect(in: Capsule())

                    Button(AppCopy.t("Autre suggestion", en: "Another suggestion")) {
                        recipeSeed += 1
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(20)
            }
            .navigationTitle(AppCopy.t("Recettes likes", en: "Liked recipes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.close) { showGeneratedRecipes = false }
                }
            }
            .id(recipeSeed)
        }
        .processAppPageBackground()
    }

    private func localizedCatalogSectionTitle(_ section: ProcessDebloatMealLibrary.CatalogSection) -> String {
        if section.sectionKey == "omad" {
            return AppCopy.t("Repas OMAD", en: "OMAD meal")
        }
        return section.slot.displayTitle
    }

    private func rotatedLikes(seed: Int) -> [DebloatFoodItem] {
        let likes = prefs.likedFoods
        guard !likes.isEmpty else { return likes }
        let offset = abs(seed) % likes.count
        return Array(likes[offset...]) + Array(likes[..<offset])
    }

    private func showToast(_ messageFR: String, en messageEN: String) {
        ProcessToastCenter.shared.show(messageFR, en: messageEN, symbol: "checkmark.circle.fill")
    }
}

// MARK: - Hub enums (symbols)

private extension DebloatFoodHubMode {
    var symbolName: String {
        switch self {
        case .foods: return "leaf.fill"
        case .recipes: return "fork.knife"
        }
    }
}

private extension DebloatFoodHubTab {
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

private struct DebloatFoodRow: View {
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
