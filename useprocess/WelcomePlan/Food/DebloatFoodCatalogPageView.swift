import SwiftUI

/// Page "Aliments" — catalogue complet (privilégier / éviter / tes goûts), poussée depuis Zéro Rétention.
struct DebloatFoodCatalogPageView: View {
    @Binding var selectedFood: DebloatFoodItem?

    @Environment(\.appTheme) private var theme
    @Bindable private var prefs = DebloatFoodPreferenceStore.shared

    @State private var tab: DebloatFoodHubTab = .prefer
    @State private var foodSearchQuery = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                foodTabPicker

                if tab != .tastes {
                    foodSearchField
                }

                foodsContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .processTransparentScrollSurface()
        .navigationTitle(AppCopy.t("Aliments", en: "Foods"))
        .navigationBarTitleDisplayMode(.inline)
        .processAppPageBackground()
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: tab)
        .onAppear { prefs.reload() }
    }

    // MARK: - Picker

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
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .processGlassEffect(in: Capsule(), interactive: false)
    }

    // MARK: - Contents

    @ViewBuilder
    private var foodsContent: some View {
        VStack(alignment: .leading, spacing: 22) {
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
}
