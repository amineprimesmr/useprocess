import SwiftUI

// MARK: - Layout

enum PlanBreakfastBuilderLayout {
    /// `fondpetitdej.png` — 1040×1512, affiché en entier sans crop.
    static let heroBackgroundAspectRatio: CGFloat = 1040 / 1512
    static let heroCornerRadius: CGFloat = 32
    static let optionCardWidth: CGFloat = 188
    static let optionCardHeight: CGFloat = 272
    static let optionCornerRadius: CGFloat = 28
    static let optionSpacing: CGFloat = 14
}

// MARK: - Section

struct PlanBreakfastBuilderSection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool
    var onOpenDetail: (PlanDayMealEntry) -> Void
    var onValidated: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var selections = BreakfastMealBuilderCatalog.defaultSelections

    private var builtMeal: MealSuggestionContent {
        BreakfastMealBuilderCatalog.buildMeal(from: selections)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: PlanHomeSectionDesign.headerContentSpacing) {
            PlanProtocolSectionHeader(
                title: "Petit-déjeuner",
                trailing: "~\(selections.estimatedCalories) kcal"
            )

            Text("Compose ton assiette — fond fixe + aliments PNG. Swipe pour changer chaque catégorie.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            PlanBreakfastBuilderHeroCard(
                selections: selections,
                isEditable: isEditable,
                onOpenDetail: {
                    onOpenDetail(
                        PlanDayMealEntry.catalog(
                            meal: builtMeal,
                            slot: .breakfast,
                            plan: plan,
                            day: day
                        )
                    )
                },
                onValidate: validateBreakfast
            )

            ForEach(BreakfastMealBuilderCatalog.categories) { category in
                categoryBlock(category)
            }
        }
        .onAppear(perform: loadPersistedSelections)
    }

    @ViewBuilder
    private func categoryBlock(_ category: BreakfastBuilderCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Spacer(minLength: 4)
                Text(category.subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            PlanBreakfastOptionCarousel(
                options: BreakfastMealBuilderCatalog.options(for: category),
                selections: selections,
                isEditable: isEditable,
                onToggle: { option in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selections.toggle(option)
                        persistDraft()
                    }
                }
            )
        }
    }

    private func validateBreakfast() {
        guard isEditable else { return }
        let meal = builtMeal
        WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: meal, slot: .breakfast)
        WelcomePlanStore.shared.saveValidatedMeal(dayId: day.id, meal: meal, slot: .breakfast)
        HapticManager.shared.notification(.success)
        onValidated()
    }

    private func persistDraft() {
        guard isEditable else { return }
        let meal = builtMeal
        WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: meal, slot: .breakfast)
    }

    private func loadPersistedSelections() {
        if let draft = WelcomePlanStore.shared.draftMealContent(for: day.id, slot: .breakfast) {
            selections = selectionsFromMeal(draft)
            return
        }
        if let validated = WelcomePlanStore.shared.validatedMealContent(for: day.id, slot: .breakfast) {
            selections = selectionsFromMeal(validated)
        }
    }

    private func selectionsFromMeal(_ meal: MealSuggestionContent) -> BreakfastBuilderSelections {
        var result = BreakfastMealBuilderCatalog.defaultSelections
        for item in meal.items {
            guard let match = BreakfastMealBuilderCatalog.option(matching: item) else { continue }
            switch match.category {
            case .hydration: result.hydration = match.id
            case .protein: result.protein = match.id
            case .fruit: result.fruits.insert(match.id)
            case .vegetable: result.vegetables.insert(match.id)
            case .finish: result.finishes.insert(match.id)
            }
        }
        return result
    }
}

// MARK: - Hero (fond + calques PNG)

struct PlanBreakfastBuilderHeroCard: View {
    let selections: BreakfastBuilderSelections
    var isEditable: Bool
    var onOpenDetail: () -> Void
    var onValidate: () -> Void

    @Environment(\.appTheme) private var theme

    private var calories: Int { selections.estimatedCalories }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onOpenDetail()
        } label: {
            ZStack {
                heroBackground
                layerStack
                heroChrome
            }
            .aspectRatio(PlanBreakfastBuilderLayout.heroBackgroundAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PlanBreakfastBuilderLayout.heroCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                PlanTrainingCardReliefOverlay(
                    cornerRadius: PlanBreakfastBuilderLayout.heroCornerRadius,
                    isDark: theme.isDark
                )
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(theme.isDark ? 0.42 : 0.12), radius: 16, y: 8)
    }

  @ViewBuilder
    private var heroBackground: some View {
        if ProcessAssetCatalog.contains(BreakfastMealBuilderCatalog.backgroundAsset) {
            Image(BreakfastMealBuilderCatalog.backgroundAsset)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.91, blue: 0.86),
                    Color(red: 0.78, green: 0.90, blue: 0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    @ViewBuilder
    private var layerStack: some View {
        GeometryReader { geo in
            let layers = BreakfastMealBuilderCatalog.layerOptions(from: selections)
            ForEach(layers) { option in
                if let asset = option.layerAsset,
                   let placement = option.placement,
                   ProcessAssetCatalog.contains(asset) {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width * placement.scale)
                        .position(
                            x: geo.size.width * placement.x,
                            y: geo.size.height * placement.y
                        )
                        .allowsHitTesting(false)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var heroChrome: some View {
        VStack(spacing: 0) {
            Text("\(calories) kcal")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.96))
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(.black.opacity(0.38))
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                        }
                }
                .padding(.top, 16)

            Spacer(minLength: 0)

            if isEditable {
                heroActionBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
    }

    private var heroActionBar: some View {
        HStack(spacing: 0) {
            Text("\(calories) kcal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 18)

            Button {
                onValidate()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Valider ce petit-déjeuner")
        }
        .frame(height: 52)
        .background {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.38, green: 0.58, blue: 0.98),
                            Color(red: 0.52, green: 0.44, blue: 0.96)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - Carousel options

struct PlanBreakfastOptionCarousel: View {
    let options: [BreakfastBuilderOption]
    let selections: BreakfastBuilderSelections
    var isEditable: Bool
    var onToggle: (BreakfastBuilderOption) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PlanBreakfastBuilderLayout.optionSpacing) {
                ForEach(options) { option in
                    PlanBreakfastOptionCard(
                        option: option,
                        isSelected: selections.isSelected(option),
                        isEditable: isEditable,
                        onTap: { onToggle(option) }
                    )
                    .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.94)
                            .opacity(phase.isIdentity ? 1 : 0.82)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 4)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }
}

// MARK: - Carte option (style produit)

struct PlanBreakfastOptionCard: View {
    let option: BreakfastBuilderOption
    let isSelected: Bool
    var isEditable: Bool
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button {
            guard isEditable else { return }
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            ZStack {
                cardVisual
                cardChrome
            }
            .frame(
                width: PlanBreakfastBuilderLayout.optionCardWidth,
                height: PlanBreakfastBuilderLayout.optionCardHeight
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: PlanBreakfastBuilderLayout.optionCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: PlanBreakfastBuilderLayout.optionCornerRadius,
                    style: .continuous
                )
                .strokeBorder(
                    isSelected ? theme.onboardingAccent : Color.clear,
                    lineWidth: isSelected ? 2.5 : 0
                )
            }
            .overlay {
                PlanTrainingCardReliefOverlay(
                    cornerRadius: PlanBreakfastBuilderLayout.optionCornerRadius,
                    isDark: theme.isDark
                )
            }
        }
        .buttonStyle(PlanTrainingCard3DPressStyle(restTilt: 3))
        .shadow(color: .black.opacity(theme.isDark ? 0.4 : 0.12), radius: 12, y: 6)
        .opacity(isEditable ? 1 : 0.92)
    }

    @ViewBuilder
    private var cardVisual: some View {
        if let preview = option.cardPreviewAsset, ProcessAssetCatalog.contains(preview) {
            Image(preview)
                .resizable()
                .scaledToFill()
                .frame(
                    width: PlanBreakfastBuilderLayout.optionCardWidth,
                    height: PlanBreakfastBuilderLayout.optionCardHeight
                )
                .clipped()
        } else if let layer = option.layerAsset, ProcessAssetCatalog.contains(layer) {
            ZStack {
                optionPlaceholderGradient
                Image(layer)
                    .resizable()
                    .scaledToFit()
                    .padding(24)
            }
        } else {
            ZStack {
                optionPlaceholderGradient
                VStack(spacing: 8) {
                    Image(systemName: option.category.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.85))
                    Text(option.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
            }
        }
    }

    private var optionPlaceholderGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.93, green: 0.95, blue: 0.98),
                Color(red: 0.82, green: 0.90, blue: 0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardChrome: some View {
        VStack(spacing: 0) {
            Text(option.badge)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.96))
                .monospacedDigit()
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(.black.opacity(0.40))
                }
                .padding(.top, 12)

            Spacer(minLength: 0)

            Text(option.cardTitle)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .italic()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)

            Spacer(minLength: 0)

            HStack(spacing: 0) {
                Text("\(option.calories) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)

                Image(systemName: isSelected ? "checkmark" : "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .frame(height: 46)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.38, green: 0.58, blue: 0.98),
                                Color(red: 0.52, green: 0.44, blue: 0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background {
            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}
