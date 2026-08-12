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

    @State private var selectedEntry: PlanDayMealEntry?
    @State private var showMealIdeasCatalog = false
    @State private var scrollPosition: PlanMealCarouselScrollTarget?
    @Bindable private var planBridge = CoachPlanNavigationBridge.shared
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

    private var focusedMealSlot: MealTimeSlot {
        PlanMealSlotLabel.preferredSlot(
            in: livePlan.configuredMealSlots,
            planType: livePlan.nutritionPlanType,
            validated: Set(entries.filter(\.isValidated).map(\.slot))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if tutorialStore.showsNutritionSectionTitle {
                headerRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            nutritionCarouselBody
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: tutorialStore.currentStepIndex)
        .task(id: day.id) {
            PlanDayMealsProvider.ensureDefaultDrafts(plan: livePlan, day: day, store: store)
            reloadMealEntries()
            let target = PlanMealCarouselScrollTarget.meal(focusedMealSlot)
            if scrollPosition != target {
                scrollPosition = target
            }
        }
        .onChange(of: mealEntriesRefreshToken) { _, _ in
            reloadMealEntries()
        }
        .onChange(of: entriesValidationToken) { _, _ in
            let target = PlanMealCarouselScrollTarget.meal(focusedMealSlot)
            guard scrollPosition != target else { return }
            scrollPosition = target
        }
        .onChange(of: planBridge.focusHydrationCarouselNonce) { _, _ in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                scrollPosition = .hydration
            }
        }
        .onChange(of: tutorialStore.currentStepIndex) { _, _ in
            guard tutorialStore.isActive else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.88)) {
                switch tutorialStore.currentStep {
                case .hydration:
                    scrollPosition = .hydration
                case .nutrition:
                    scrollPosition = .meal(focusedMealSlot)
                default:
                    break
                }
            }
        }
        .onChange(of: store.plan?.progress.draftMealsBySlot[day.id]) { _, _ in
            refreshSelectedEntryIfNeeded()
        }
        .onChange(of: store.plan?.progress.validatedMealsBySlot[day.id]) { _, _ in
            refreshSelectedEntryIfNeeded()
        }
        .fullScreenCover(item: $selectedEntry) { entry in
            PlanMealDetailView(
                entry: refreshedEntry(entry),
                plan: livePlan,
                day: day,
                isEditable: isEditable,
                onDismiss: { selectedEntry = nil }
            )
            .environmentObject(profileService)
            .processZoomTransition(id: .mealDetail(entry.slot), namespace: mealZoomNamespace)
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

    private var entriesValidationToken: String {
        entries.map { "\($0.slot.rawValue):\($0.isValidated)" }.joined(separator: "|")
    }

    private var headerRow: some View {
        Text(PlanHomeSectionKind.nutrition.title)
            .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
            .foregroundStyle(theme.primaryText)
    }

    @ViewBuilder
    private var nutritionCarouselBody: some View {
        if tutorialStore.isFocused(.hydration) {
            PlanHomeTutorialFocusChrome(focus: .hydration) {
                hydrationCard
            }
            .padding(.horizontal, PlanHomeSectionDesign.homeScrollPadding)
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else if tutorialStore.isFocused(.meals) {
            PlanHomeTutorialFocusChrome(
                focus: .meals,
                cornerRadius: PlanMealCarouselLayout.cornerRadius
            ) {
                mealCarousel(displayMode: .tutorialMealsFocus)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else {
            mealCarousel(displayMode: .standard)
                .opacity(tutorialStore.isRevealed(.hydration) || tutorialStore.isRevealed(.meals) ? 0.88 : 1)
        }
    }

    private var hydrationCard: some View {
        PlanHydrationCarouselCard(
            targetMilliliters: ProcessDailyTargets.hydrationTargetMilliliters,
            selectedDate: selectedDate,
            dayId: day.id,
            healthKitWaterLiters: healthKitWaterLiters
        )
    }

    private func mealCarousel(displayMode: PlanMealCarouselDisplayMode = .standard) -> some View {
        let showsMeals: Bool = switch displayMode {
        case .standard:
            !tutorialStore.isActive || tutorialStore.showsMealCardsInCarousel
        case .tutorialMealsFocus:
            true
        }

        return PlanMealCoverFlowCarousel(
            entries: entries,
            previewImageAssets: ProcessDebloatMealLibrary.homeCatalogPreviewImageAssets,
            hydrationTargetMilliliters: ProcessDailyTargets.hydrationTargetMilliliters,
            selectedDate: selectedDate,
            dayId: day.id,
            healthKitWaterLiters: healthKitWaterLiters,
            scrollPosition: $scrollPosition,
            mealZoomNamespace: mealZoomNamespace,
            showsHydration: true,
            showsMealCards: showsMeals,
            highlightsMealStrip: displayMode == .tutorialMealsFocus,
            onSelect: {
                ProcessPerformanceTrace.beginMealOpen()
                selectedEntry = $0
            },
            onBrowseCatalog: { showMealIdeasCatalog = true }
        )
        .padding(.horizontal, -PlanHomeSectionDesign.homeScrollPadding)
    }

    private func refreshedEntry(_ entry: PlanDayMealEntry) -> PlanDayMealEntry {
        entries.first(where: { $0.slot == entry.slot }) ?? entry
    }

    private func refreshSelectedEntryIfNeeded() {
        guard let current = selectedEntry else { return }
        selectedEntry = refreshedEntry(current)
    }

    private func reloadMealEntries() {
        mealEntries = PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
    }
}

// MARK: - Carousel repas

private enum PlanMealCarouselDisplayMode {
    case standard
    case tutorialMealsFocus
}

private enum PlanMealCarouselScrollTarget: Hashable {
    case hydration
    case meal(MealTimeSlot)
}

private struct PlanMealCoverFlowCarousel: View {
    let entries: [PlanDayMealEntry]
    let previewImageAssets: [String]
    let hydrationTargetMilliliters: Int
    let selectedDate: Date
    let dayId: String
    let healthKitWaterLiters: Double
    @Binding var scrollPosition: PlanMealCarouselScrollTarget?
    let mealZoomNamespace: Namespace.ID
    var showsHydration: Bool = true
    var showsMealCards: Bool = true
    var highlightsMealStrip: Bool = false
    var onSelect: (PlanDayMealEntry) -> Void
    var onBrowseCatalog: () -> Void

    private let cardSpacing: CGFloat = 10

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            carouselContent
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .frame(height: PlanMealCarouselLayout.cardHeight + 16)
    }

    private var carouselContent: some View {
        LazyHStack(spacing: cardSpacing) {
            if showsHydration {
                mealCardScrollTransition(
                    PlanHydrationCarouselCard(
                        targetMilliliters: hydrationTargetMilliliters,
                        selectedDate: selectedDate,
                        dayId: dayId,
                        healthKitWaterLiters: healthKitWaterLiters
                    )
                )
                .id(PlanMealCarouselScrollTarget.hydration)
            }

            if showsMealCards {
                Group {
                    if highlightsMealStrip {
                        mealCardsStrip
                    } else {
                        mealCardsRow
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: showsMealCards)
        .scrollTargetLayout()
        .padding(.horizontal, PlanHomeSectionDesign.homeScrollPadding)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func mealCardScrollTransition<Content: View>(_ content: Content) -> some View {
        if highlightsMealStrip {
            content
        } else {
            content.scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view
                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                    .opacity(phase.isIdentity ? 1 : 0.78)
            }
        }
    }

    @ViewBuilder
    private var mealCardsRow: some View {
        ForEach(entries) { entry in
            mealCardScrollTransition(
                PlanMealCarouselCard(
                    entry: entry,
                    zoomNamespace: mealZoomNamespace,
                    onTap: { onSelect(entry) }
                )
            )
            .id(PlanMealCarouselScrollTarget.meal(entry.slot))
        }

        mealCardScrollTransition(
            PlanMealCatalogBrowseCard(
                previewImageAssets: previewImageAssets,
                zoomNamespace: mealZoomNamespace,
                onTap: onBrowseCatalog
            )
        )
    }

    private var mealCardsStrip: some View {
        HStack(spacing: cardSpacing) {
            mealCardsRow
        }
        .padding(2)
    }
}

// MARK: - Carte hydratation (début de carousel)

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

    private var bottleSquareSide: CGFloat { 272 }
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
            Image(systemName: "plus")
                .font(.system(size: addButtonIconSize, weight: .bold))
                .foregroundStyle(theme.primaryText)
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

// MARK: - Carte catalogue (fin de carousel)

private struct PlanMealCatalogBrowseCard: View {
    let previewImageAssets: [String]
    var zoomNamespace: Namespace.ID? = nil
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            VStack(spacing: 12) {
                Text(AppCopy.t("Recettes Debloat", en: "Debloat recipes"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                ZStack {
                    previewCollage

                    catalogCountPill
                        .padding(.bottom, 2)
                }
                .frame(height: PlanMealCarouselLayout.imageDiameter + 10)

                Spacer(minLength: 0)
            }
            .frame(
                width: PlanMealCarouselLayout.cardWidth,
                height: PlanMealCarouselLayout.cardHeight
            )
        }
        .buttonStyle(.processPlain)
        .frame(
            width: PlanMealCarouselLayout.cardWidth,
            height: PlanMealCarouselLayout.cardHeight
        )
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .mealCatalog, namespace: zoomNamespace)
        .accessibilityLabel(AppCopy.t(
            "Ouvrir le catalogue d’aliments pour un visage dégonflé",
            en: "Open the food catalog for a less puffy face"
        ))
    }

    @ViewBuilder
    private var previewCollage: some View {
        let assets = Array(previewImageAssets.prefix(3))
        if assets.isEmpty {
            Circle()
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
                .overlay {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                }
        } else if assets.count == 1 {
            singlePreviewImage(assets[0])
        } else {
            ZStack {
                if assets.count >= 2 {
                    singlePreviewImage(assets[1])
                        .frame(width: 88, height: 88)
                        .offset(x: -36, y: 12)
                        .opacity(0.82)
                }
                if assets.count >= 3 {
                    singlePreviewImage(assets[2])
                        .frame(width: 88, height: 88)
                        .offset(x: 36, y: 12)
                        .opacity(0.82)
                }
                singlePreviewImage(assets[0])
            }
            .frame(
                width: PlanMealCarouselLayout.imageDiameter,
                height: PlanMealCarouselLayout.imageDiameter
            )
        }
    }

    private func singlePreviewImage(_ asset: String) -> some View {
        Group {
            if ProcessAssetCatalog.contains(asset) {
                Image(asset)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "fork.knife")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(theme.onboardingAccent.opacity(0.8))
            }
        }
        .frame(width: PlanMealCarouselLayout.imageDiameter, height: PlanMealCarouselLayout.imageDiameter)
    }

    private var catalogCountPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.onboardingAccent)

            Text(AppCopy.t("Voir tout", en: "See all"))
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .processGlassEffect(in: Capsule(style: .continuous), interactive: false)
        }
    }
}

// MARK: - Carte carousel (liquid glass)

private enum PlanMealCarouselLayout {
    static let cardWidth: CGFloat = 212
    static let cardHeight: CGFloat = 268
    static let imageDiameter: CGFloat = 152
    static let cornerRadius: CGFloat = 30
}

private struct PlanMealCarouselCard: View {
    let entry: PlanDayMealEntry
    let zoomNamespace: Namespace.ID
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Text(entry.meal.localizedDisplayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                ZStack(alignment: .bottom) {
                    mealImage

                    debloatScorePill
                        .padding(.bottom, 2)
                }
                .frame(height: PlanMealCarouselLayout.imageDiameter + 10)

                Spacer(minLength: 0)
            }
            .frame(
                width: PlanMealCarouselLayout.cardWidth,
                height: PlanMealCarouselLayout.cardHeight
            )
        }
        .buttonStyle(.processPlain)
        .frame(
            width: PlanMealCarouselLayout.cardWidth,
            height: PlanMealCarouselLayout.cardHeight
        )
        .background {
            cardShape
                .fill(.clear)
                .processGlassEffect(in: cardShape)
        }
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .mealDetail(entry.slot), namespace: zoomNamespace)
    }

    @ViewBuilder
    private var mealImage: some View {
        if ProcessAssetCatalog.contains(entry.imageAssetName) {
            // PNG tels quels — pas de clip circulaire (évite le « rond noir » autour).
            Image(entry.imageAssetName)
                .resizable()
                .scaledToFit()
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
        } else {
            Image(systemName: entry.slot.icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
        }
    }

    private var debloatScorePill: some View {
        MealDebloatScorePill(assessment: entry.assessment)
    }
}
