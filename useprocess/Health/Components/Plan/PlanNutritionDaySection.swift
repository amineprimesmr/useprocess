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
    var mealZoomNamespace: Namespace.ID

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager

    @State private var selectedEntry: PlanDayMealEntry?
    @State private var showMealIdeasCatalog = false
    @State private var showHydrationHub = false
    @State private var scrollPosition: MealTimeSlot?

    private var store: WelcomePlanStore { WelcomePlanStore.shared }
    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    private var entries: [PlanDayMealEntry] {
        PlanDayMealsProvider.entries(plan: livePlan, day: day, store: store)
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
            headerRow
            mealCarousel
        }
        .task(id: day.id) {
            PlanDayMealsProvider.ensureDefaultDrafts(plan: livePlan, day: day, store: store)
            let target = focusedMealSlot
            if scrollPosition != target {
                scrollPosition = target
            }
        }
        .onChange(of: entries.map(\.isValidated)) { _, _ in
            let target = focusedMealSlot
            guard scrollPosition != target else { return }
            withAnimation(.smooth(duration: 0.42)) {
                scrollPosition = target
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
        .fullScreenCover(isPresented: $showHydrationHub) {
            PlanHydrationExperienceView(
                plan: livePlan,
                day: day,
                selectedDate: selectedDate
            )
            .environmentObject(profileService)
            .environmentObject(healthManager)
            .processZoomTransition(id: .hydrationHub, namespace: mealZoomNamespace)
        }
    }

    private var headerRow: some View {
        Text("Repas debloat du jour")
            .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
            .foregroundStyle(theme.primaryText)
    }

    private var mealCarousel: some View {
        PlanMealCoverFlowCarousel(
            entries: entries,
            previewImageAssets: ProcessDebloatMealLibrary.fullCatalogPreviewImageAssets(),
            hydrationTargetMilliliters: livePlan.resolvedDailyTargets.hydrationLitersPerDay * 1000,
            selectedDate: selectedDate,
            dayId: day.id,
            healthKitWaterLiters: healthManager.todaySnapshot.nutrition.waterLiters,
            scrollPosition: $scrollPosition,
            mealZoomNamespace: mealZoomNamespace,
            onOpenHydration: { showHydrationHub = true },
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
}

// MARK: - Carousel repas

private struct PlanMealCoverFlowCarousel: View {
    let entries: [PlanDayMealEntry]
    let previewImageAssets: [String]
    let hydrationTargetMilliliters: Int
    let selectedDate: Date
    let dayId: String
    let healthKitWaterLiters: Double
    @Binding var scrollPosition: MealTimeSlot?
    let mealZoomNamespace: Namespace.ID
    var onOpenHydration: () -> Void
    var onSelect: (PlanDayMealEntry) -> Void
    var onBrowseCatalog: () -> Void

    private let cardSpacing: CGFloat = 10

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            carouselContent
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .frame(height: PlanMealCarouselLayout.cardHeight + 8)
    }

    private var carouselContent: some View {
        LazyHStack(spacing: cardSpacing) {
            PlanHydrationCarouselCard(
                targetMilliliters: hydrationTargetMilliliters,
                selectedDate: selectedDate,
                dayId: dayId,
                healthKitWaterLiters: healthKitWaterLiters,
                zoomNamespace: mealZoomNamespace,
                onOpenHydration: onOpenHydration
            )
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                    .opacity(phase.isIdentity ? 1 : 0.78)
            }

            ForEach(entries) { entry in
                PlanMealCarouselCard(
                    entry: entry,
                    zoomNamespace: mealZoomNamespace,
                    onTap: { onSelect(entry) }
                )
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1 : 0.9)
                        .opacity(phase.isIdentity ? 1 : 0.78)
                }
                .id(entry.slot)
            }

            PlanMealCatalogBrowseCard(
                previewImageAssets: previewImageAssets,
                zoomNamespace: mealZoomNamespace,
                onTap: onBrowseCatalog
            )
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                content
                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                    .opacity(phase.isIdentity ? 1 : 0.78)
            }
        }
        .scrollTargetLayout()
        .padding(.horizontal, PlanHomeSectionDesign.homeScrollPadding)
        .padding(.vertical, 4)
    }
}

// MARK: - Carte hydratation (début de carousel)

private struct PlanHydrationCarouselCard: View {
    let targetMilliliters: Int
    let selectedDate: Date
    let dayId: String
    let healthKitWaterLiters: Double
    let zoomNamespace: Namespace.ID
    var onOpenHydration: () -> Void

    @Environment(\.appTheme) private var theme
    @StateObject private var waterEngine = ProcessFluidWaterMotionEngine()
    @Bindable private var hydrationStore = ProcessHydrationLogStore.shared

    private var effectiveMilliliters: Int {
        max(
            hydrationStore.milliliters(for: selectedDate),
            Int((healthKitWaterLiters * 1000).rounded())
        )
    }

    private var progress: CGFloat {
        guard targetMilliliters > 0 else { return 0 }
        return min(1, CGFloat(effectiveMilliliters) / CGFloat(targetMilliliters))
    }

    private var millilitersLabel: String {
        "\(formattedMilliliters(effectiveMilliliters)) / \(formattedMilliliters(targetMilliliters)) ML"
    }

    private var percentageLabel: String {
        guard targetMilliliters > 0 else { return "0%" }
        let value = Int((Double(effectiveMilliliters) / Double(targetMilliliters) * 100).rounded())
        return "\(min(999, max(0, value)))%"
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: PlanMealCarouselLayout.cornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardBackground

            amountLabelLayer

            bottomMillilitersLabel

            waterLayer

            cardTapLayer

            addButton
                .padding(.top, 14)
                .padding(.trailing, 14)
        }
        .frame(
            width: PlanMealCarouselLayout.cardWidth,
            height: PlanMealCarouselLayout.cardHeight
        )
        .processGlassButton(in: cardShape)
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .hydrationHub, namespace: zoomNamespace)
        .onAppear { waterEngine.start() }
        .onDisappear { waterEngine.stop() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Hydratation \(millilitersLabel). Ajouter 500 millilitres ou ouvrir la page hydratation.")
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: theme.isDark
                ? [
                    Color(red: 0.02, green: 0.16, blue: 0.32),
                    Color(red: 0.00, green: 0.34, blue: 0.58)
                ]
                : [
                    Color(red: 0.86, green: 0.97, blue: 1.0),
                    Color(red: 0.38, green: 0.78, blue: 0.98)
                ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardTapLayer: some View {
        Color.clear
            .contentShape(cardShape)
            .onTapGesture {
                HapticManager.shared.impact(.light)
                onOpenHydration()
            }
    }

    private var amountLabelLayer: some View {
        GeometryReader { proxy in
            Text(percentageLabel)
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(amountTextColor)
                .shadow(color: amountShadowColor, radius: 10, y: 4)
                .contentTransition(.numericText())
                .padding(.horizontal, 14)
                .position(
                    x: proxy.size.width * 0.5,
                    y: amountLabelY(in: proxy.size)
                )
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: effectiveMilliliters)
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: progress)
    }

    private var bottomMillilitersLabel: some View {
        VStack {
            Spacer()

            Text(millilitersLabel)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(bottomTextColor)
                .shadow(color: amountShadowColor, radius: 8, y: 3)
                .contentTransition(.numericText())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    Capsule(style: .continuous)
                        .fill(theme.isDark ? Color.black.opacity(0.18) : Color.white.opacity(0.22))
                }
                .padding(.bottom, 16)
        }
        .allowsHitTesting(false)
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: effectiveMilliliters)
    }

    @ViewBuilder
    private var waterLayer: some View {
        GeometryReader { proxy in
            let shape = PlanHydrationCardWaterShape(
                fillLevel: max(0.08, progress),
                roll: waterEngine.roll,
                pitch: waterEngine.pitch,
                wavePhase: waterEngine.wavePhase
            )

            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    shape
                        .fill(.clear)
                        .glassEffect(ProcessGlass.waterSurface, in: shape)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            } else {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.44, green: 0.88, blue: 0.98, opacity: 0.34),
                                Color(red: 0.12, green: 0.64, blue: 0.82, opacity: 0.48)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .allowsHitTesting(false)
        .transaction { $0.animation = nil }
        .animation(.spring(response: 0.56, dampingFraction: 0.82), value: progress)
    }

    private var amountTextColor: Color {
        theme.isDark
            ? Color.white.opacity(0.96)
            : Color(red: 0.02, green: 0.24, blue: 0.32)
    }

    private var amountShadowColor: Color {
        theme.isDark
            ? Color.black.opacity(0.42)
            : Color.white.opacity(0.72)
    }

    private var bottomTextColor: Color {
        theme.isDark
            ? Color.white.opacity(0.90)
            : Color(red: 0.02, green: 0.24, blue: 0.32).opacity(0.88)
    }

    private var addButton: some View {
        Button {
            addWater()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.primaryText)
                .frame(width: 36, height: 36)
        }
        .processGlassIconButtonStyle()
        .accessibilityLabel("Ajouter 500 millilitres d'eau")
    }

    private func addWater() {
        HapticManager.shared.impact(.medium)
        ProcessSoundPlayer.playPouringWater()
        hydrationStore.addWater(
            milliliters: 500,
            for: selectedDate,
            dayId: dayId,
            targetMilliliters: targetMilliliters
        )
        waterEngine.bumpWave()
    }

    private func formattedMilliliters(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func amountLabelY(in size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return PlanMealCarouselLayout.cardHeight * 0.5 }

        let fill = max(0.08, progress)
        let depth = fill * size.height
        let restY = size.height - depth
        let clampedPitch = max(-1, min(1, waterEngine.pitch))
        let centerX = size.width * 0.5
        let wave = CGFloat(sin(Double(waterEngine.wavePhase) + Double(centerX) * 0.035)) * 1.2
        let surfaceY = min(size.height - 1, max(1, restY - clampedPitch * depth * 0.08 + wave))
        return min(size.height - 34, max(42, surfaceY + 30))
    }
}

private struct PlanHydrationCardWaterShape: Shape {
    var fillLevel: CGFloat
    var roll: CGFloat
    var pitch: CGFloat
    var wavePhase: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(fillLevel, wavePhase) }
        set {
            fillLevel = newValue.first
            wavePhase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let clampedFill = min(1, max(0, fillLevel))
        let depth = clampedFill * rect.height
        let restY = rect.height - depth
        let clampedRoll = max(-1, min(1, roll))
        let clampedPitch = max(-1, min(1, pitch))
        let segmentCount = 24

        var points: [CGPoint] = []
        points.reserveCapacity(segmentCount + 1)

        for index in 0...segmentCount {
            let x = CGFloat(index) / CGFloat(segmentCount) * rect.width
            let normalizedX = (x / rect.width - 0.5) * 2
            let midY = restY - clampedPitch * depth * 0.08
            let slope = -clampedRoll * normalizedX * depth * 0.30
            let wave = CGFloat(sin(Double(wavePhase) + Double(x) * 0.035)) * 1.2
            let y = min(rect.height - 1, max(1, midY + slope + wave))
            points.append(CGPoint(x: x, y: y))
        }

        var path = Path()
        path.move(to: points[0])

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) * 0.5, y: (previous.y + current.y) * 0.5)
            path.addQuadCurve(to: current, control: mid)
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
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
                Text("Toutes les recettes")
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
        .buttonStyle(.plain)
        .frame(
            width: PlanMealCarouselLayout.cardWidth,
            height: PlanMealCarouselLayout.cardHeight
        )
        .processGlassButton(in: cardShape)
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .mealCatalog, namespace: zoomNamespace)
        .accessibilityLabel("Voir tous les repas debloat du catalogue")
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
                    .scaledToFill()
            } else {
                Circle()
                    .fill(theme.cardBackgroundStrong.opacity(0.5))
            }
        }
        .frame(width: PlanMealCarouselLayout.imageDiameter, height: PlanMealCarouselLayout.imageDiameter)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(Color.primary.opacity(theme.isDark ? 0.12 : 0.06), lineWidth: 0.5)
        }
    }

    private var catalogCountPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.onboardingAccent)

            Text("Voir tout")
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
                Text(entry.meal.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                ZStack(alignment: .bottom) {
                    mealImageCircle

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
        .buttonStyle(.plain)
        .frame(
            width: PlanMealCarouselLayout.cardWidth,
            height: PlanMealCarouselLayout.cardHeight
        )
        .processGlassButton(in: cardShape)
        .clipShape(cardShape)
        .processHomeGlassCardShadow(isDark: theme.isDark)
        .processZoomSource(id: .mealDetail(entry.slot), namespace: zoomNamespace)
    }

    @ViewBuilder
    private var mealImageCircle: some View {
        if ProcessAssetCatalog.contains(entry.imageAssetName) {
            Image(entry.imageAssetName)
                .resizable()
                .scaledToFill()
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(theme.isDark ? 0.12 : 0.06), lineWidth: 0.5)
                }
        } else {
            Circle()
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
                .frame(
                    width: PlanMealCarouselLayout.imageDiameter,
                    height: PlanMealCarouselLayout.imageDiameter
                )
                .overlay {
                    Image(systemName: entry.slot.icon)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.8))
                }
        }
    }

    private var debloatScorePill: some View {
        MealDebloatScorePill(assessment: entry.assessment)
    }
}
