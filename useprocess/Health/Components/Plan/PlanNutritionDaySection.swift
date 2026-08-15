import SwiftUI
import UIKit

struct PlanDayMealEntry: Identifiable, Equatable {
    let slot: MealTimeSlot
    let meal: MealSuggestionContent
    let isValidated: Bool
    let planType: NutritionPlanType
    let dayIndex: Int
    let resolvedImageAssetName: String
    let assessment: MealDebloatAssessment

    var id: String { slot.rawValue }

    var carouselTitle: String { PlanMealSlotLabel.carouselTitle(for: slot, planType: planType) }
    var imageAssetName: String { resolvedImageAssetName }
    var scheduleTargetLabel: String? { PlanMealSchedule.targetLabel(for: slot, planType: planType) }
    var scheduleWindowLabel: String? { PlanMealSchedule.windowLabel(for: slot, planType: planType) }
    var scheduleNote: String? { PlanMealSchedule.timing(for: slot, planType: planType)?.debloatNote }

    /// Entrée catalogue — hors carousel des idées du jour.
    static func catalog(
        meal: MealSuggestionContent,
        slot: MealTimeSlot,
        plan: FaceOriginPlan,
        day: OriginProgramDay
    ) -> PlanDayMealEntry {
        let mealSlots = WelcomePlanStore.shared.plan?.progress.validatedMealsBySlot[day.id]
        let validated = mealSlots?[slot.rawValue] != nil
        return PlanDayMealEntry(
            slot: slot,
            meal: meal,
            isValidated: validated,
            planType: plan.nutritionPlanType,
            dayIndex: day.globalDayIndex,
            resolvedImageAssetName: MealNutritionCatalog.resolvedImageAsset(
                for: meal,
                slot: slot,
                dayIndex: day.globalDayIndex,
                planType: plan.nutritionPlanType
            ),
            assessment: MealNutritionCatalog.debloatAssessment(for: meal)
        )
    }
}

enum PlanDayMealsProvider {
    static func entries(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        store: WelcomePlanStore
    ) -> [PlanDayMealEntry] {
        plan.configuredMealSlots.map { slot in
            let meal = resolvedMeal(plan: plan, day: day, slot: slot, store: store)
            let validated = store.plan?.progress.validatedMealsBySlot[day.id]?[slot.rawValue] != nil
            return PlanDayMealEntry(
                slot: slot,
                meal: meal,
                isValidated: validated,
                planType: plan.nutritionPlanType,
                dayIndex: day.globalDayIndex,
                resolvedImageAssetName: MealNutritionCatalog.resolvedImageAsset(
                    for: meal,
                    slot: slot,
                    dayIndex: day.globalDayIndex,
                    planType: plan.nutritionPlanType
                ),
                assessment: MealNutritionCatalog.debloatAssessment(for: meal)
            )
        }
    }

    static func resolvedMeal(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        slot: MealTimeSlot,
        store: WelcomePlanStore
    ) -> MealSuggestionContent {
        if let validated = store.validatedMealContent(for: day.id, slot: slot) {
            return validated
        }
        if let draft = store.draftMealContent(for: day.id, slot: slot) {
            return draft
        }
        return ProcessDebloatMealLibrary.meal(
            for: slot,
            dayIndex: day.globalDayIndex,
            planType: plan.nutritionPlanType
        )
    }

    @MainActor
    static func ensureDefaultDrafts(
        plan: FaceOriginPlan,
        day: OriginProgramDay,
        store: WelcomePlanStore
    ) {
        guard OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: plan) else { return }

        var defaults: [MealTimeSlot: MealSuggestionContent] = [:]
        for slot in plan.configuredMealSlots {
            defaults[slot] = ProcessDebloatMealLibrary.meal(
                for: slot,
                dayIndex: day.globalDayIndex,
                planType: plan.nutritionPlanType
            )
        }
        store.saveMissingDraftMeals(dayId: day.id, mealsBySlot: defaults)
    }
}

// MARK: - Section nutrition page Plan

struct PlanNutritionDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var selectedDate: Date
    var isEditable: Bool = true
    var healthKitWaterLiters: Double = 0
    var mealZoomNamespace: Namespace.ID

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var showMealIdeasCatalog = false
    @Bindable private var tutorialStore = PlanHomeTutorialStore.shared
    @State private var mealEntries: [PlanDayMealEntry] = []

    private var store: WelcomePlanStore { WelcomePlanStore.shared }
    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var entries: [PlanDayMealEntry] { mealEntries }

    private var mealEntriesRefreshToken: String {
        let validated = store.plan?.progress.validatedMealsBySlot[day.id] ?? [:]
        let drafts = store.plan?.progress.draftMealsBySlot[day.id] ?? [:]
        let validatedKey = validated.keys.sorted().map { "\($0)=\(validated[$0] ?? "")" }.joined(separator: ",")
        let draftsKey = drafts.keys.sorted().map { "\($0)=\(drafts[$0] ?? "")" }.joined(separator: ",")
        return "\(day.id)|\(livePlan.nutritionPlanType.rawValue)|\(validatedKey)|\(draftsKey)"
    }

    private var showsMealCard: Bool {
        !tutorialStore.isActive || tutorialStore.showsMealCardsInCarousel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if tutorialStore.showsNutritionSectionTitle {
                headerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            nutritionStripBody
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: tutorialStore.currentStepIndex)
        .task(id: day.id) {
            PlanDayMealsProvider.ensureDefaultDrafts(plan: livePlan, day: day, store: store)
            reloadMealEntries()
        }
        .onChange(of: mealEntriesRefreshToken) { _, _ in
            reloadMealEntries()
        }
        .fullScreenCover(isPresented: $showMealIdeasCatalog) {
            PlanMealIdeasCatalogSheet(
                plan: livePlan,
                day: day,
                isEditable: isEditable,
                mealZoomNamespace: mealZoomNamespace
            )
            .environmentObject(profileService)
            .processZoomTransition(id: .mealCatalog, namespace: mealZoomNamespace)
        }
    }

    private var headerRow: some View {
        Text(AppCopy.t("Alimentation debloat", en: "Debloat nutrition"))
            .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
            .foregroundStyle(theme.primaryText)
    }

    @ViewBuilder
    private var nutritionStripBody: some View {
        if tutorialStore.isFocused(.hydration) {
            PlanHomeTutorialFocusChrome(focus: .hydration) {
                hydrationCard
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if tutorialStore.isFocused(.meals) {
            PlanHomeTutorialFocusChrome(
                focus: .meals,
                cornerRadius: PlanNutritionStripLayout.cornerRadius
            ) {
                dayMealsCard
                    .frame(maxWidth: .infinity)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else {
            nutritionStrip
                .opacity(tutorialStore.isRevealed(.hydration) || tutorialStore.isRevealed(.meals) ? 0.88 : 1)
        }
    }

    private var nutritionStrip: some View {
        HStack(alignment: .center, spacing: 12) {
            hydrationCard

            if showsMealCard {
                dayMealsCard
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .frame(height: PlanNutritionStripLayout.rowHeight)
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: showsMealCard)
    }

    private var hydrationCard: some View {
        PlanHydrationCarouselCard(
            targetMilliliters: ProcessDailyTargets.hydrationTargetMilliliters,
            selectedDate: selectedDate,
            dayId: day.id,
            healthKitWaterLiters: healthKitWaterLiters
        )
    }

    private var dayMealsCard: some View {
        PlanDayMealsMarketCard(
            entries: entries,
            zoomNamespace: mealZoomNamespace,
            onTap: {
                HapticManager.shared.impact(.light)
                showMealIdeasCatalog = true
            }
        )
    }

    private func reloadMealEntries() {
        mealEntries = PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
    }
}

// MARK: - Carte hydratation

private struct PlanHydrationCarouselCard: View {
    let targetMilliliters: Int
    let selectedDate: Date
    let dayId: String
    let healthKitWaterLiters: Double

    @Environment(\.appTheme) private var theme
    @Bindable private var hydrationStore = ProcessHydrationLogStore.shared
    @Bindable private var timerStore = ProcessHydrationTimerStore.shared
    @Bindable private var sipCelebration = ProcessHydrationSipCelebrationCoordinator.shared
    @State private var animatedFill: CGFloat = 0.08
    @State private var bottleCelebrationScale: CGFloat = 1
    @State private var plusButtonScale: CGFloat = 1
    @State private var pourFlashOpacity: Double = 0
    @State private var pendingPourFromMilliliters: Int?
    @State private var showHydrationTimer = false
    @State private var celebrationTask: Task<Void, Never>?
    @State private var goalReachedHapticTask: Task<Void, Never>?

    private var healthKitMilliliters: Int {
        Int((healthKitWaterLiters * 1000).rounded())
    }

    /// Si l'utilisateur a déjà ajusté dans l'app, on suit le journal local (pour pouvoir descendre).
    private var effectiveMilliliters: Int {
        if hydrationStore.hasLocalAdjustments(for: selectedDate) {
            return max(0, hydrationStore.milliliters(for: selectedDate))
        }
        return max(
            hydrationStore.milliliters(for: selectedDate),
            healthKitMilliliters
        )
    }

    private var targetFill: CGFloat {
        guard targetMilliliters > 0 else { return 0.08 }
        return max(0.08, min(1, CGFloat(effectiveMilliliters) / CGFloat(targetMilliliters)))
    }

    private var goalWatermarkLabel: String {
        if targetMilliliters >= 1000, targetMilliliters.isMultiple(of: 1000) {
            return "\(targetMilliliters / 1000)L"
        }
        return "\(formatLiters(targetMilliliters))L"
    }

    private var accessibilityHydrationLabel: String {
        AppCopy.t(
            "Hydratation \(formatLiters(effectiveMilliliters)) sur \(formatLiters(targetMilliliters)) litres",
            en: "Hydration \(formatLiters(effectiveMilliliters)) of \(formatLiters(targetMilliliters)) liters"
        )
    }

    private var canRemoveWater: Bool { effectiveMilliliters > 0 }

    private var bottleSquareSide: CGFloat { PlanNutritionStripLayout.rowHeight }
    private var bottleCanvasHeight: CGFloat { bottleSquareSide }
    private var bottleTrimmedWidth: CGFloat {
        bottleSquareSide * ProcessHydrationBottleMetrics.contentWidthFraction
    }
    private var bottleLeadingPadding: CGFloat { 26 }
    private var bottleTrailingPadding: CGFloat { 4 }
    private var goalWatermarkFontSize: CGFloat { 52 }
    private var addButtonSize: CGFloat { 36 }
    private var addButtonIconSize: CGFloat { 14 }
    private var addButtonTopOffset: CGFloat {
        bottleCanvasHeight * ProcessHydrationBottleMetrics.bodyMinY - 4
    }
    private var addButtonSpacing: CGFloat { 8 }

    var body: some View {
        HStack(alignment: .top, spacing: addButtonSpacing) {
            bottleStack

            addButton
                .padding(.top, addButtonTopOffset)
        }
        .padding(.leading, bottleLeadingPadding)
        .padding(.trailing, bottleTrailingPadding)
        .frame(height: bottleCanvasHeight)
        .fullScreenCover(isPresented: $showHydrationTimer) {
            ProcessHydrationTimerView(
                dayId: dayId,
                targetMilliliters: targetMilliliters,
                onDismiss: { showHydrationTimer = false }
            )
        }
        .onAppear {
            if sipCelebration.peekFromMilliliters() != nil {
                scheduleHomeCelebration()
            } else {
                animatedFill = targetFill
            }
        }
        .onChange(of: effectiveMilliliters) { oldValue, newValue in
            guard sipCelebration.peekFromMilliliters() == nil else { return }

            if let pourFrom = pendingPourFromMilliliters {
                pendingPourFromMilliliters = nil
                runHydrationPourCelebration(fromMilliliters: pourFrom, toMilliliters: newValue)
            } else if newValue > oldValue {
                runHydrationPourCelebration(
                    fromMilliliters: oldValue,
                    toMilliliters: newValue,
                    playFeedback: false
                )
            } else {
                animateFill(to: targetFill, celebrate: false)
            }

            Task { await timerStore.syncLiveActivityHydration() }
        }
        .onChange(of: sipCelebration.requestID) { _, requestID in
            guard requestID != nil else { return }
            scheduleHomeCelebration()
        }
        .onDisappear {
            celebrationTask?.cancel()
            goalReachedHapticTask?.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityHydrationLabel)
        .accessibilityHint(AppCopy.t(
            "Toucher pour ouvrir le timer. Appui long pour ajuster le niveau d'eau",
            en: "Tap to open the timer. Long press to adjust water level"
        ))
    }

    private var pourFlashBodyWidth: CGFloat {
        bottleSquareSide * (ProcessHydrationBottleMetrics.bodyMaxX - ProcessHydrationBottleMetrics.bodyMinX)
    }

    private var pourFlashBodyHeight: CGFloat {
        bottleSquareSide * (ProcessHydrationBottleMetrics.bodyMaxY - ProcessHydrationBottleMetrics.bodyMinY)
    }

    private var bottleStack: some View {
        ZStack {
            bottleVisualLayer

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: openTimer)
                .contextMenu {
                    hydrationAdjustMenu
                    Button {
                        openTimer()
                    } label: {
                        Label(AppCopy.t("Ouvrir le timer", en: "Open timer"), systemImage: "timer")
                    }
                } preview: {
                    hydrationBottleContextMenuPreview
                }
        }
        .frame(width: bottleTrimmedWidth, height: bottleCanvasHeight)
        .scaleEffect(bottleCelebrationScale)
    }

    private var bottleVisualLayer: some View {
        ZStack {
            ProcessHydrationBottleView(
                fillLevel: animatedFill,
                goalWatermarkLabel: goalWatermarkLabel,
                goalWatermarkFontSize: goalWatermarkFontSize
            )
            .frame(width: bottleSquareSide, height: bottleSquareSide)

            RoundedRectangle(cornerRadius: pourFlashBodyWidth * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.72, green: 0.90, blue: 0.92, opacity: pourFlashOpacity),
                            Color(red: 0.58, green: 0.80, blue: 0.84, opacity: pourFlashOpacity * 0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: pourFlashBodyWidth * 0.92, height: pourFlashBodyHeight * 0.55)
                .offset(y: bottleSquareSide * ProcessHydrationBottleMetrics.bodyMinY + pourFlashBodyHeight * 0.06)
                .blur(radius: 10)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: bottleSquareSide, height: bottleSquareSide)
        .frame(width: bottleTrimmedWidth, height: bottleCanvasHeight, alignment: .center)
        .clipped()
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private var hydrationBottleContextMenuPreview: some View {
        ProcessHydrationBottleView(
            fillLevel: animatedFill,
            goalWatermarkLabel: goalWatermarkLabel,
            goalWatermarkFontSize: goalWatermarkFontSize,
            showsGlassWater: false
        )
        .frame(width: bottleSquareSide, height: bottleSquareSide)
        .frame(width: bottleTrimmedWidth, height: bottleCanvasHeight, alignment: .center)
        .clipped()
        .padding(8)
    }

    private func openTimer() {
        HapticManager.shared.impact(.light)
        showHydrationTimer = true
    }

    private func scheduleHomeCelebration() {
        celebrationTask?.cancel()
        celebrationTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            guard !Task.isCancelled else { return }
            guard let fromMilliliters = sipCelebration.consumeFromMilliliters() else { return }
            runHomeCelebration(fromMilliliters: fromMilliliters)
        }
    }

    private func runHomeCelebration(fromMilliliters: Int) {
        runHydrationPourCelebration(fromMilliliters: fromMilliliters, toMilliliters: effectiveMilliliters)
    }

    private func runHydrationPourCelebration(
        fromMilliliters: Int,
        toMilliliters: Int,
        playFeedback: Bool = true
    ) {
        guard toMilliliters > fromMilliliters else {
            animateFill(to: targetFill, celebrate: false)
            return
        }

        if playFeedback {
            HapticManager.shared.impact(.medium)
            ProcessSoundPlayer.playPouringWater()
        }

        animatedFill = fillLevel(for: fromMilliliters)
        triggerPourFlash()
        animateFill(to: fillLevel(for: toMilliliters), celebrate: true)
        scheduleGoalReachedHaptic(from: fromMilliliters, to: toMilliliters)
    }

    private func triggerPourFlash() {
        pourFlashOpacity = 0.42
        withAnimation(.easeOut(duration: 0.78)) {
            pourFlashOpacity = 0
        }
    }

    private func scheduleGoalReachedHaptic(from fromMilliliters: Int, to toMilliliters: Int) {
        guard fromMilliliters < targetMilliliters, toMilliliters >= targetMilliliters else { return }
        goalReachedHapticTask?.cancel()
        goalReachedHapticTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            HapticManager.shared.notification(.success)
            ProcessToastCenter.shared.show(
                "Objectif hydratation",
                en: "Hydration goal",
                description: "Tu as atteint ton objectif du jour.",
                en: "You hit today's goal.",
                symbol: "drop.fill",
                tintColor: Color(red: 0.36, green: 0.72, blue: 0.98)
            )
        }
    }

    private func animateFill(to newFill: CGFloat, celebrate: Bool) {
        if celebrate {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.48)) {
                bottleCelebrationScale = 1.07
                plusButtonScale = 1.18
            }
            withAnimation(.spring(response: 0.64, dampingFraction: 0.74).delay(0.14)) {
                bottleCelebrationScale = 1
                plusButtonScale = 1
            }
        }

        withAnimation(.spring(response: 0.92, dampingFraction: 0.74)) {
            animatedFill = newFill
        }
    }

    private func fillLevel(for milliliters: Int) -> CGFloat {
        guard targetMilliliters > 0 else { return 0.08 }
        return max(0.08, min(1, CGFloat(milliliters) / CGFloat(targetMilliliters)))
    }

    @ViewBuilder
    private var hydrationAdjustMenu: some View {
        Button {
            addWater()
        } label: {
            Label(AppCopy.t("Ajouter 500 ml", en: "Add 500 ml"), systemImage: "plus.circle")
        }

        if canRemoveWater {
            Button {
                removeWater()
            } label: {
                Label(AppCopy.t("Retirer 500 ml", en: "Remove 500 ml"), systemImage: "minus.circle")
            }

            Button(role: .destructive) {
                resetWater()
            } label: {
                Label(AppCopy.t("Remettre à zéro", en: "Reset to zero"), systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var addButton: some View {
        Button {
            addWater()
        } label: {
            ProcessHydrationDropIcon.image(side: addButtonIconSize + 8)
                .frame(width: addButtonSize, height: addButtonSize)
                .scaleEffect(plusButtonScale)
        }
        .processGlassIconButtonStyle()
        .accessibilityLabel(AppCopy.t("Ajouter 500 millilitres d'eau", en: "Add 500 milliliters of water"))
    }

    private func addWater() {
        let before = effectiveMilliliters
        pendingPourFromMilliliters = before
        if hydrationStore.hasLocalAdjustments(for: selectedDate) {
            hydrationStore.addWater(
                milliliters: 500,
                for: selectedDate,
                dayId: dayId,
                targetMilliliters: targetMilliliters
            )
        } else {
            hydrationStore.setMilliliters(
                before + 500,
                for: selectedDate,
                dayId: dayId,
                targetMilliliters: targetMilliliters
            )
        }
    }

    private func removeWater() {
        guard canRemoveWater else { return }
        HapticManager.shared.impact(.light)
        let baseline = effectiveMilliliters
        hydrationStore.setMilliliters(
            max(0, baseline - 500),
            for: selectedDate,
            dayId: dayId,
            targetMilliliters: targetMilliliters
        )
    }

    private func resetWater() {
        HapticManager.shared.selection()
        hydrationStore.resetToday(for: selectedDate, dayId: dayId)
    }

    private func formatLiters(_ milliliters: Int) -> String {
        let liters = Double(milliliters) / 1000.0
        let formatter = NumberFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: liters)) ?? String(format: "%.1f", liters)
    }
}

// MARK: - Strip alimentation (liquid glass)

private enum PlanNutritionStripLayout {
    static let rowHeight: CGFloat = 248
    static let marketImageSide: CGFloat = 96
    static let cornerRadius: CGFloat = 26
}

/// Une carte « marché » : les 3 plats du jour en collage, ouvre le catalogue.
private struct PlanDayMealsMarketCard: View {
    let entries: [PlanDayMealEntry]
    let zoomNamespace: Namespace.ID
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanNutritionStripLayout.cornerRadius, style: .continuous)
    }

    private var marketEntries: [PlanDayMealEntry] {
        Array(entries.prefix(3))
    }

    private var globalDayAssessment: MealDebloatAssessment? {
        let assessments = marketEntries.map(\.assessment)
        guard !assessments.isEmpty else { return nil }
        let count = Double(assessments.count)
        let average: (KeyPath<MealDebloatAssessment, Int>) -> Int = { keyPath in
            Int((assessments.map { Double($0[keyPath: keyPath]) }.reduce(0, +) / count).rounded())
        }
        return MealDebloatAssessment(
            score: average(\.score),
            electrolyteScore: average(\.electrolyteScore),
            digestiveScore: average(\.digestiveScore),
            foodQualityScore: average(\.foodQualityScore),
            balance: assessments[0].balance,
            label: AppCopy.tSync("Score moyen du jour", en: "Day average score"),
            summary: AppCopy.tSync(
                "Moyenne Debloat des repas du jour.",
                en: "Average Debloat score for today's meals."
            ),
            caution: nil,
            isEstimated: assessments.contains(where: \.isEstimated)
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                Text(AppCopy.t("Repas de la journée", en: "Today's meals"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                mealMarketCollage
                    .frame(maxWidth: .infinity)
                    .frame(height: 132)

                if let globalDayAssessment {
                    MealDebloatScorePill(assessment: globalDayAssessment)
                        .padding(.bottom, 14)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: PlanNutritionStripLayout.rowHeight)
            .contentShape(cardShape)
        }
        .processGlassButton(in: cardShape)
        .frame(maxWidth: .infinity)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .mealCatalog, namespace: zoomNamespace)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityHint(AppCopy.t(
            "Ouvre le catalogue des repas",
            en: "Opens the meals catalog"
        ))
    }

    private var accessibilityTitle: String {
        if let score = globalDayAssessment?.score {
            return AppCopy.t(
                "Repas de la journée, score Debloat \(score)",
                en: "Today's meals, Debloat score \(score)"
            )
        }
        return AppCopy.t("Repas de la journée", en: "Today's meals")
    }

    private var mealMarketCollage: some View {
        ZStack {
            ForEach(Array(marketEntries.enumerated()), id: \.element.id) { index, entry in
                marketDishImage(entry)
                    .scaleEffect(index == 1 ? 1.06 : 0.92)
                    .offset(x: collageXOffset(for: index), y: collageYOffset(for: index))
                    .zIndex(index == 1 ? 2 : 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func collageXOffset(for index: Int) -> CGFloat {
        switch index {
        case 0: -48
        case 1: 0
        default: 48
        }
    }

    private func collageYOffset(for index: Int) -> CGFloat {
        switch index {
        case 0: 10
        case 1: -6
        default: 14
        }
    }

    @ViewBuilder
    private func marketDishImage(_ entry: PlanDayMealEntry) -> some View {
        if ProcessAssetCatalog.contains(entry.imageAssetName) {
            Image(entry.imageAssetName)
                .resizable()
                .scaledToFit()
                .frame(
                    width: PlanNutritionStripLayout.marketImageSide,
                    height: PlanNutritionStripLayout.marketImageSide
                )
        } else {
            Image(systemName: entry.slot.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                .frame(
                    width: PlanNutritionStripLayout.marketImageSide,
                    height: PlanNutritionStripLayout.marketImageSide
                )
        }
    }
}
