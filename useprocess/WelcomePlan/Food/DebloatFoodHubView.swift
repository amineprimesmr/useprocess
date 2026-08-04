import SwiftUI

/// Hub Debloat — recettes Process (section Aliments masquée temporairement).
struct DebloatFoodHubView: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool

    /// Remettre `true` pour réafficher le catalogue aliments + picker Aliments/Recettes.
    private static let showsFoodsSectionTemporarily = false

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store = WelcomePlanStore.shared
    @Bindable private var prefs = DebloatFoodPreferenceStore.shared

    @State private var mode: DebloatFoodHubMode = .recipes
    @State private var tab: DebloatFoodHubTab = .prefer
    @State private var selectedFood: DebloatFoodItem?
    @State private var selectedCatalogMeal: CatalogMealSelection?
    @State private var showGrocery = false
    @State private var showGeneratedRecipes = false
    @State private var groceryRequest = DebloatGroceryRequest()
    @State private var groceryPlan: DebloatGroceryPlan?
    @State private var recipeSeed = 0
    @State private var toastMessage: String?

    private var livePlan: FaceOriginPlan { store.plan ?? plan }
    private var recipeSections: [ProcessDebloatMealLibrary.CatalogSection] {
        // OMAD + collation masqués temporairement dans le hub catalogue.
        ProcessDebloatMealLibrary.fullCatalogSections()
            .filter { $0.sectionKey != "omad" && $0.sectionKey != "snack" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if Self.showsFoodsSectionTemporarily {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }

                if Self.showsFoodsSectionTemporarily {
                    modePicker
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    if mode == .foods {
                        foodTabPicker
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                    }
                }

                ScrollView(showsIndicators: false) {
                    Group {
                        if Self.showsFoodsSectionTemporarily, mode == .foods {
                            foodsContent
                        } else {
                            recipesCatalogContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, Self.showsFoodsSectionTemporarily ? 0 : 8)
                    .padding(.bottom, Self.showsFoodsSectionTemporarily && mode == .foods ? 120 : 40)
                }
                .processTransparentScrollSurface()
            }
            .safeAreaInset(edge: .bottom) {
                if Self.showsFoodsSectionTemporarily {
                    bottomCTA
                }
            }
            .navigationTitle(
                Self.showsFoodsSectionTemporarily && mode == .foods
                    ? "Aliments Debloat"
                    : "Recettes Debloat"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
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
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    Text(toastMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: mode)
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .onAppear { prefs.reload() }
    }

    // MARK: - Header / pickers

    private var header: some View {
        Text("Aliments pour un visage dégonflé")
            .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
            .foregroundStyle(theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(DebloatFoodHubMode.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        mode = item
                    }
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(mode == item ? (theme.isDark ? Color.black : Color.white) : theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            Capsule().fill(
                                mode == item
                                    ? theme.primaryText
                                    : theme.primaryText.opacity(theme.isDark ? 0.10 : 0.06)
                            )
                        }
                }
                .buttonStyle(.processPlain)
            }
        }
    }

    private var foodTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(DebloatFoodHubTab.allCases) { item in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        tab = item
                    }
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tab == item ? theme.primaryText : theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if tab == item {
                                Capsule().fill(theme.primaryText.opacity(theme.isDark ? 0.14 : 0.08))
                            }
                        }
                }
                .buttonStyle(.processPlain)
            }
        }
    }

    // MARK: - Contents

    @ViewBuilder
    private var foodsContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            if tab == .tastes {
                tastesContent
            } else {
                ForEach(DebloatFoodCatalog.sections(for: tab)) { section in
                    sectionBlock(section)
                }
            }
        }
    }

    private var recipesCatalogContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(recipeSections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section.title)
                        .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                        .foregroundStyle(theme.primaryText)

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
                    Text("Tes likes")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                    ForEach(prefs.likedFoods) { food in
                        DebloatFoodRow(food: food) { selectedFood = food }
                    }
                }
            }

            if !prefs.haveAtHomeFoods.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Déjà chez toi")
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
            Text("Aucun like pour l’instant")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            Text("Like des aliments dans Privilégier pour générer courses et recettes visage dégonflé.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.7))
        )
    }

    // MARK: - CTA

    @ViewBuilder
    private var bottomCTA: some View {
        if mode == .foods {
            VStack(spacing: 10) {
                Button {
                    switch tab {
                    case .prefer, .tastes:
                        showGrocery = true
                    case .avoid:
                        tab = .prefer
                    }
                } label: {
                    Text(tab == .avoid ? "Voir les aliments à privilégier" : "Générer ma liste de courses")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryText)
                .foregroundStyle(theme.isDark ? Color.black : Color.white)

                if tab != .avoid {
                    Button("Créer des recettes avec mes likes") {
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
    }

    // MARK: - Grocery sheet

    private var grocerySheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Budget")
                        .font(.headline)
                    Picker("Budget", selection: $groceryRequest.budget) {
                        ForEach(DebloatGroceryBudget.allCases) { budget in
                            Text(budget.title).tag(budget)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(groceryRequest.budget.subtitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)

                    Stepper(
                        "Durée : \(groceryRequest.dayCount) jours",
                        value: $groceryRequest.dayCount,
                        in: 3...7
                    )

                    Toggle("Inclure boissons drainantes", isOn: $groceryRequest.includeDrinks)
                    Toggle("Inclure herbes anti-sel", isOn: $groceryRequest.includeHerbs)

                    Button("Générer la liste visage dégonflé") {
                        groceryPlan = DebloatGroceryGenerator.generate(request: groceryRequest)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primaryText)

                    if let groceryPlan {
                        ForEach(groceryPlan.groupedByAisle, id: \.aisle.id) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.aisle.title)
                                    .font(.subheadline.weight(.bold))
                                ForEach(group.lines) { line in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(line.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text(line.quantity)
                                                .font(.caption)
                                                .foregroundStyle(theme.secondaryText)
                                            if line.isAvoidWarning, let swap = line.suggestedSwapName {
                                                Text("Piège Na — préfère \(swap)")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(Color.orange)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(theme.isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.72))
                                    )
                                }
                            }
                        }

                        Button("Ajouter à ma liste de courses") {
                            store.mergeShoppingItems(DebloatGroceryGenerator.shoppingItems(from: groceryPlan))
                            showToast("Liste ajoutée")
                            showGrocery = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primaryText)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Courses Debloat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { showGrocery = false }
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
                    Text("Recettes à partir de tes likes")
                        .font(.title3.weight(.bold))
                    Text("Générateur offline — priorité potassium, zéro aliment à éviter.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)

                    ForEach(orderedSlots, id: \.self) { slot in
                        if let meal = meals[slot] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(slot.rawValue)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(theme.secondaryText)
                                Text(meal.name)
                                    .font(.headline)
                                ForEach(meal.foodItems) { item in
                                    Text("• \(item.ingredientDisplayLine)")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.secondaryText)
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(theme.isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.72))
                            )
                        }
                    }

                    Button("Injecter dans mes repas du jour") {
                        guard isEditable else {
                            showToast("Jour non modifiable")
                            return
                        }
                        for (slot, meal) in meals {
                            store.saveDraftMeal(dayId: day.id, meal: meal, slot: slot)
                        }
                        showToast("Repas du jour mis à jour")
                        showGeneratedRecipes = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primaryText)

                    Button("Autre suggestion") {
                        recipeSeed += 1
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(20)
            }
            .navigationTitle("Recettes likes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { showGeneratedRecipes = false }
                }
            }
            .id(recipeSeed)
        }
        .processAppPageBackground()
    }

    private func rotatedLikes(seed: Int) -> [DebloatFoodItem] {
        let likes = prefs.likedFoods
        guard !likes.isEmpty else { return likes }
        let offset = abs(seed) % likes.count
        return Array(likes[offset...]) + Array(likes[..<offset])
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            toastMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.25)) {
                toastMessage = nil
            }
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(food.name)
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
                    Text(food.whyItHelpsOrHurts)
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
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.72))
            )
        }
        .buttonStyle(.processPlain)
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
                        Text("Score ≈\(food.debloatScore)")
                            .font(.title2.weight(.bold).monospacedDigit())
                    }

                    Text(food.whyItHelpsOrHurts)
                        .font(.body)
                        .foregroundStyle(theme.primaryText)

                    metricsRow

                    if let portion = food.portionHint {
                        Label(portion, systemImage: "scalemass")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    if food.exceedsSaltLabelThreshold {
                        Text("Seuil dépassé : > 1,5 g de sel / 100 g — à éviter pour le visage.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.orange)
                    }

                    let swaps = DebloatFoodCatalog.swapItems(for: food)
                    if !swaps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Alternatives visage")
                                .font(.headline)
                            ForEach(swaps) { swap in
                                Text("→ \(swap.name)")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button(prefs.isLiked(food.id) ? "Liked" : "Like") {
                            prefs.toggleLike(food.id)
                        }
                        .buttonStyle(.bordered)
                        Button(prefs.hasAtHome(food.id) ? "Chez moi" : "J’ai chez moi") {
                            prefs.toggleHaveAtHome(food.id)
                        }
                        .buttonStyle(.bordered)
                    }

                    if food.tier != .avoid {
                        Button("Ajouter aux courses") {
                            store.mergeShoppingItems([
                                MealShoppingItem(
                                    name: food.name,
                                    quantity: food.portionHint ?? "1"
                                )
                            ])
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primaryText)
                    } else if let swap = swaps.first {
                        Button("Remplacer par \(swap.name)") {
                            store.mergeShoppingItems([
                                MealShoppingItem(name: swap.name, quantity: swap.portionHint ?? "1")
                            ])
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.primaryText)
                    }

                    Text("Valeurs approximatives pour 100 g. Ce n’est pas un avis médical.")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(20)
            }
            .navigationTitle(food.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
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
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
        )
    }
}
