import SwiftUI

/// Page détail repas — une proposition à la fois, changement via bouton sticky.
struct PlanMealDetailView: View {
    let entry: PlanDayMealEntry
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var isEditable: Bool = true
    var onDismiss: () -> Void

    @Environment(\.appTheme) private var theme

    @State private var displayedMeal: MealSuggestionContent
    @State private var assessment: MealDebloatAssessment
    @State private var preparationPresentation: MealPreparationPresentation
    @State private var draftSaveTask: Task<Void, Never>?
    private let alternatives: [MealSuggestionContent]

    init(
        entry: PlanDayMealEntry,
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        isEditable: Bool = true,
        onDismiss: @escaping () -> Void
    ) {
        self.entry = entry
        self.plan = plan
        self.day = day
        self.isEditable = isEditable
        self.onDismiss = onDismiss
        _displayedMeal = State(initialValue: entry.meal)
        var pool = ProcessDebloatMealLibrary.catalogMeals(for: entry.slot)
        if !pool.contains(where: { $0.name == entry.meal.name }) {
            pool.insert(entry.meal, at: 0)
        }
        alternatives = pool
        _assessment = State(initialValue: entry.assessment)
        _preparationPresentation = State(
            initialValue: MealPreparationStepsParser.presentation(
                from: entry.meal.localizedPrep,
                prepMinutes: entry.meal.prepMinutes
            )
        )
    }

    private var showsChangeMealButton: Bool {
        isEditable && alternatives.count > 1
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        mealHeroHeader

                        Text(displayedMeal.localizedDisplayName)
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 4)
                            .id("meal-title-\(displayedMeal.name)")

                        let summary = displayedMeal.localizedSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !summary.isEmpty {
                            Text(summary)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(theme.secondaryText)
                                .padding(.horizontal, 8)
                                .id("meal-summary-\(displayedMeal.name)")
                        }

                        MealDebloatScoreDetailCard(assessment: assessment)
                            .id("meal-score-\(displayedMeal.name)")

                        ingredientsSection

                        preparationSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, showsChangeMealButton ? 96 : 32)
                    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: displayedMeal.name)
                }
                .processTransparentScrollSurface()

                if showsChangeMealButton {
                    changeMealStickyButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppCopy.close, action: onDismiss)
                }
            }
            .onAppear {
                ProcessPerformanceTrace.endMealOpen()
                CoachPresentationTracker.shared.beginMealDetailPresentation()
            }
            .onDisappear {
                draftSaveTask?.cancel()
                persistDraftIfNeeded()
                CoachPresentationTracker.shared.endMealDetailPresentation()
            }
            .onChange(of: displayedMeal.name) { _, _ in
                refreshDerivedPresentation()
                scheduleDraftPersistence()
            }
        }
        .processAppPageBackground()
    }

    private var mealHeroHeader: some View {
        let imageAsset = MealNutritionCatalog.resolvedImageAsset(
            for: displayedMeal,
            slot: entry.slot,
            dayIndex: day.globalDayIndex,
            planType: plan.nutritionPlanType
        )

        return ZStack(alignment: .bottom) {
            Group {
                if ProcessAssetCatalog.contains(imageAsset) {
                    // PNG tels quels — pas de clip circulaire (évite le « rond noir » autour).
                    Image(imageAsset)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: entry.slot.icon)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                }
            }
            .frame(width: 152, height: 152)

            MealDebloatScoreGlassPill(assessment: assessment)
                .offset(y: 10)
        }
        .padding(.top, 4)
        .id("meal-hero-\(displayedMeal.name)")
    }

    private var changeMealStickyButton: some View {
        Button(action: cycleToNextMeal) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                Text(AppCopy.t("Changez de repas", en: "Change meal"))
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(theme.primaryText.opacity(0.92))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .processGlassButton(in: Capsule())
            .shadow(color: Color.black.opacity(theme.isDark ? 0.42 : 0.14), radius: 18, y: 10)
        }
        .buttonStyle(ProcessGlassPressStyle())
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .accessibilityLabel(AppCopy.t("Changez de repas", en: "Change meal"))
        .accessibilityHint(AppCopy.t("Affiche une autre proposition du catalogue pour ce créneau", en: "Shows another catalog suggestion for this slot"))
    }

    private func cycleToNextMeal() {
        guard alternatives.count > 1 else { return }
        HapticManager.shared.impact(.light)

        let currentIndex = alternatives.firstIndex(where: { $0.name == displayedMeal.name }) ?? 0
        let nextIndex = (currentIndex + 1) % alternatives.count

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            displayedMeal = alternatives[nextIndex]
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(AppCopy.t("Ingrédients", en: "Ingredients"), systemImage: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            VStack(spacing: 8) {
                ForEach(displayedMeal.foodItems) { item in
                    ingredientRow(item)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
        .id("meal-ingredients-\(displayedMeal.name)")
    }

    private func ingredientRow(_ item: MealSuggestionItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.roleIcon)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 22)

            Text(item.ingredientDisplayLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.cardBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Label(AppCopy.t("Préparation", en: "Preparation"), systemImage: "list.number")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)

                Spacer(minLength: 0)

                if let minutes = preparationPresentation.estimatedMinutes {
                    Text("~\(minutes) min")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.cardBackground.opacity(0.55), in: Capsule())
                }
            }

            if !preparationPresentation.steps.isEmpty {
                VStack(spacing: 10) {
                    ForEach(preparationPresentation.steps) { step in
                        preparationStepRow(step)
                    }
                }
            } else if let prose = preparationPresentation.proseFallback {
                Text(prose)
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(AppCopy.t("Aucune étape de préparation pour ce repas.", en: "No preparation steps for this meal."))
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }

            let tip = displayedMeal.localizedCoachTip.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tip.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.onboardingAccent)
                        .padding(.top, 2)

                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(theme.primaryText.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.onboardingAccent.opacity(theme.isDark ? 0.14 : 0.10))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(mealSurfaceCard)
        .id("meal-prep-\(displayedMeal.name)")
    }

    private func preparationStepRow(_ step: MealPreparationStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step.index)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.inverseText)
                .frame(width: 28, height: 28)
                .background(Circle().fill(theme.primaryText))

            Text(step.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var mealSurfaceCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.isDark ? theme.cardBackgroundStrong : theme.coachUserBubble)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
            .shadow(color: theme.primaryText.opacity(theme.isDark ? 0.12 : 0.04), radius: 10, y: 3)
    }

    private func persistDraftIfNeeded() {
        guard isEditable else { return }
        guard OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: plan) else { return }
        WelcomePlanStore.shared.saveDraftMeal(dayId: day.id, meal: displayedMeal, slot: entry.slot)
    }

    private func scheduleDraftPersistence() {
        draftSaveTask?.cancel()
        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            persistDraftIfNeeded()
        }
    }

    private func refreshDerivedPresentation() {
        assessment = MealNutritionCatalog.debloatAssessment(for: displayedMeal)
        preparationPresentation = MealPreparationStepsParser.presentation(
            from: displayedMeal.localizedPrep,
            prepMinutes: displayedMeal.prepMinutes
        )
    }
}
