import SwiftUI

// MARK: - Modèle

struct PlanStepsProgress: Equatable {
    let current: Int
    let target: Int

    var fraction: Double {
        guard target > 0 else { return 0 }
        return Double(current) / Double(target)
    }
}

struct PlanProtocolCarouselItem: Identifiable, Equatable {
    let id: String
    let title: String
    let repBadge: String?
    /// Texte complet — affiché uniquement au tap sur la carte.
    let detailText: String
    let assetName: String?
    let fallbackSystemImage: String
    var stepsProgress: PlanStepsProgress? = nil
}

enum PlanProtocolLineParser {
    static func splitTitleAndDetail(_ line: String) -> (title: String, detail: String) {
        for separator in [" — ", " – ", " - "] {
            if let range = line.range(of: separator) {
                let title = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let detail = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                return (title, detail)
            }
        }
        return (line.trimmingCharacters(in: .whitespaces), "")
    }

    static func repBadge(from text: String) -> String? {
        let patterns = [
            #"\d+\s*[×x]\s*\d+(?:\s*[–\-]\s*\d+)?"#,
            #"\d+\s*min(?:utes?)?"#,
            #"\d+\s*s(?:ec)?(?:ondes?)?"#
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: "x", with: "×")
            }
        }
        return nil
    }
}

enum PlanProtocolCarouselBuilder {
    enum SummaryID {
        static let seeAllTraining = "training-see-all"
    }

    static let compactPostureItemLimit = 4

    static func compactPostureItems(
        from plan: FaceOriginPlan,
        stepsToday: Int
    ) -> [PlanProtocolCarouselItem] {
        let hasWalking = PlanPostureCircuitContent.hasWalkingTarget(for: plan)
        let lineLimit = hasWalking ? compactPostureItemLimit - 1 : compactPostureItemLimit
        var items = PlanPostureCircuitContent.compactLines(
            for: plan,
            limit: lineLimit,
            includeWalking: false
        )
        .enumerated()
        .map { index, line in
            lineItem(
                line,
                id: "posture-\(index)",
                fallback: postureFallback(for: line),
                category: "Circuit posture"
            )
        }

        if hasWalking {
            items.append(walkingStepsItem(
                current: stepsToday,
                target: PlanPostureCircuitContent.dailyStepTarget(for: plan),
                plan: plan
            ))
        }

        return items
    }

    static func trainingDayCarouselItems(
        training: OriginDayTraining,
        plan: FaceOriginPlan,
        stepsToday: Int
    ) -> [PlanProtocolCarouselItem] {
        let items = trainingItems(from: training) + compactPostureItems(from: plan, stepsToday: stepsToday)
        return items + [seeAllTrainingCard(training: training, plan: plan, previewItemCount: items.count)]
    }

    static func restDayCarouselItems(
        plan: FaceOriginPlan,
        stepsToday: Int
    ) -> [PlanProtocolCarouselItem] {
        let hasWalking = PlanPostureCircuitContent.hasWalkingTarget(for: plan)
        var items: [PlanProtocolCarouselItem] = []

        if hasWalking {
            items.append(walkingStepsItem(
                current: stepsToday,
                target: PlanPostureCircuitContent.dailyStepTarget(for: plan),
                plan: plan
            ))
        }

        let lineLimit = hasWalking ? compactPostureItemLimit - 1 : compactPostureItemLimit
        items += PlanPostureCircuitContent.compactLines(
            for: plan,
            limit: lineLimit,
            isRestDay: true,
            includeWalking: false
        )
        .enumerated()
        .map { index, line in
            lineItem(
                line,
                id: "rest-\(index)",
                fallback: postureFallback(for: line),
                category: "Circuit posture"
            )
        }

        return items + [seeAllTrainingCard(training: nil, plan: plan, previewItemCount: items.count)]
    }

    static func walkingStepsItem(
        current: Int,
        target: Int,
        plan: FaceOriginPlan
    ) -> PlanProtocolCarouselItem {
        let detail = PlanPostureCircuitContent.walkingTarget(for: plan)
            ?? "Objectif \(PlanStepsProgressFormatter.formatted(target)) pas aujourd'hui — HealthKit"

        return PlanProtocolCarouselItem(
            id: "walking-steps",
            title: "Marche",
            repBadge: nil,
            detailText: detail,
            assetName: TrainingAssetCatalog.blockAsset(for: "Marche"),
            fallbackSystemImage: "figure.walk",
            stepsProgress: PlanStepsProgress(current: current, target: target)
        )
    }

    static func seeAllTrainingCard(
        training: OriginDayTraining?,
        plan: FaceOriginPlan,
        previewItemCount: Int
    ) -> PlanProtocolCarouselItem {
        let postureCount = PlanPostureCircuitContent.mobilityBlocks(for: plan).count
        let sessionCount = TrainingProgramCatalog.allSessionTemplates().count

        let detailText: String
        if let training {
            detailText = "Programme complet · \(sessionCount) séances · \(postureCount) blocs posture · \(training.sessionName) aujourd'hui."
        } else {
            detailText = "Programme complet · \(sessionCount) séances · \(postureCount) blocs posture · repos actif aujourd'hui."
        }

        return PlanProtocolCarouselItem(
            id: SummaryID.seeAllTraining,
            title: "Voir tout",
            repBadge: training.map { "\($0.durationMinutes) min" },
            detailText: detailText,
            assetName: TrainingAssetCatalog.seeAllTrainingAssetName,
            fallbackSystemImage: "square.grid.2x2.fill"
        )
    }

    static func trainingItems(from training: OriginDayTraining) -> [PlanProtocolCarouselItem] {
        var items: [PlanProtocolCarouselItem] = []

        for (index, line) in training.warmup.enumerated() {
            items.append(lineItem(
                line,
                id: "warmup-\(index)",
                fallback: "flame.fill",
                category: "Échauffement"
            ))
        }

        for exercise in training.exercises {
            items.append(exerciseItem(exercise))
        }

        for (index, line) in training.cooldown.enumerated() {
            items.append(lineItem(
                line,
                id: "cooldown-\(index)",
                fallback: "figure.cooldown",
                category: "Retour au calme"
            ))
        }

        return items
    }

    static func lineItems(
        from lines: [String],
        idPrefix: String,
        fallback: String,
        category: String? = nil
    ) -> [PlanProtocolCarouselItem] {
        lines.enumerated().map { index, line in
            lineItem(line, id: "\(idPrefix)-\(index)", fallback: fallback, category: category)
        }
    }

    static func lineItem(
        _ line: String,
        id: String,
        fallback: String,
        category: String? = nil,
        assetName: String? = nil
    ) -> PlanProtocolCarouselItem {
        let parts = PlanProtocolLineParser.splitTitleAndDetail(line)
        let badge = PlanProtocolLineParser.repBadge(from: line)
            ?? PlanProtocolLineParser.repBadge(from: parts.detail)

        let detailText: String
        if parts.detail.isEmpty {
            detailText = line
        } else if let category {
            detailText = "\(category)\n\n\(parts.detail)"
        } else {
            detailText = parts.detail
        }

        return PlanProtocolCarouselItem(
            id: id,
            title: parts.title,
            repBadge: badge,
            detailText: detailText,
            assetName: assetName ?? TrainingAssetCatalog.blockAsset(for: line),
            fallbackSystemImage: fallback
        )
    }

    private static func postureFallback(for line: String) -> String {
        let lower = line.lowercased()
        if lower.contains("buteyko") || lower.contains("respiration") { return "wind" }
        if lower.contains("marche") || lower.contains("pas") { return "figure.walk" }
        return "figure.mind.and.body"
    }

    private static func exerciseItem(_ exercise: OriginExercise) -> PlanProtocolCarouselItem {
        let badge = "\(exercise.sets)×\(exercise.reps)"
        var detailParts: [String] = ["\(exercise.sets) séries × \(exercise.reps) reps"]
        if exercise.restSeconds > 0 {
            detailParts.append("Repos \(exercise.restSeconds) s entre les séries")
        }
        if !exercise.muscleGroup.isEmpty {
            detailParts.append(exercise.muscleGroup.capitalized)
        }
        if !exercise.coachingCue.isEmpty {
            detailParts.append(exercise.coachingCue)
        }

        return PlanProtocolCarouselItem(
            id: exercise.id,
            title: exercise.name,
            repBadge: badge,
            detailText: detailParts.joined(separator: "\n\n"),
            assetName: TrainingAssetCatalog.exerciseAsset(for: exercise.name),
            fallbackSystemImage: "figure.strengthtraining.traditional"
        )
    }
}

// MARK: - Layout

enum PlanProtocolCarouselLayout {
    static let cardWidth: CGFloat = 156
    static let cardHeight: CGFloat = 272
    static let cornerRadius: CGFloat = 22
    static let spacing: CGFloat = 12

    private static var widthToHeightRatio: CGFloat { cardWidth / cardHeight }

    /// Largeur utile des carousels Accueil (padding scroll 16 pt de chaque côté).
    static var homeCarouselContentWidth: CGFloat {
        UIScreen.main.bounds.width - 2 * PlanHomeSectionDesign.homeScrollPadding
    }

    static func fittedCardSize(itemCount: Int, containerWidth: CGFloat) -> CGSize {
        let count = max(1, itemCount)
        let totalSpacing = spacing * CGFloat(count - 1)
        let width = (containerWidth - totalSpacing) / CGFloat(count)
        let height = width / widthToHeightRatio
        return CGSize(width: width, height: height)
    }
}

// MARK: - Carousel

struct PlanDayProtocolCarousel: View {
    let items: [PlanProtocolCarouselItem]
    /// Deux cartes côte à côte qui remplissent la largeur (section entraînement).
    var fillsAvailableWidth: Bool = false
    var zoomNamespace: Namespace.ID? = nil
    var zoomIDForItem: ((PlanProtocolCarouselItem) -> ProcessZoomTransitionID)? = nil
    var onTap: ((PlanProtocolCarouselItem) -> Void)? = nil
    /// Maintien 5 s pour valider une routine du jour (journal éditable).
    var routineDayId: String? = nil
    var isRoutineItemCompleted: ((PlanProtocolCarouselItem) -> Bool)? = nil
    var onRoutineValidate: ((PlanProtocolCarouselItem) -> Void)? = nil

    private var routineValidationEnabled: Bool {
        routineDayId != nil && onRoutineValidate != nil
    }

    private var defaultCardSize: CGSize {
        CGSize(
            width: PlanProtocolCarouselLayout.cardWidth,
            height: PlanProtocolCarouselLayout.cardHeight
        )
    }

    private var pairedRowEstimatedHeight: CGFloat {
        let size = PlanProtocolCarouselLayout.fittedCardSize(
            itemCount: max(items.count, 1),
            containerWidth: PlanProtocolCarouselLayout.homeCarouselContentWidth
        )
        return size.height + 8
    }

    var body: some View {
        Group {
            if fillsAvailableWidth {
                GeometryReader { geo in
                    let size = PlanProtocolCarouselLayout.fittedCardSize(
                        itemCount: max(items.count, 1),
                        containerWidth: geo.size.width
                    )

                    HStack(spacing: PlanProtocolCarouselLayout.spacing) {
                        ForEach(items) { item in
                            PlanProtocolCarouselCard(
                                item: item,
                                cardWidth: size.width,
                                cardHeight: size.height,
                                layoutStyle: .paired,
                                zoomNamespace: zoomNamespace,
                                zoomTransitionID: zoomIDForItem?(item),
                                onTap: onTap.map { handler in { handler(item) } },
                                routineValidationEnabled: routineValidationEnabled,
                                isRoutineCompleted: isRoutineItemCompleted?(item) ?? false,
                                onRoutineValidate: onRoutineValidate.map { handler in { handler(item) } }
                            )
                        }
                    }
                    .frame(width: geo.size.width, height: size.height, alignment: .leading)
                }
                .frame(height: pairedRowEstimatedHeight)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: PlanProtocolCarouselLayout.spacing) {
                        ForEach(items) { item in
                            PlanProtocolCarouselCard(
                                item: item,
                                cardWidth: defaultCardSize.width,
                                cardHeight: defaultCardSize.height,
                                layoutStyle: .carousel,
                                zoomNamespace: zoomNamespace,
                                zoomTransitionID: zoomIDForItem?(item),
                                onTap: onTap.map { handler in { handler(item) } },
                                routineValidationEnabled: routineValidationEnabled,
                                isRoutineCompleted: isRoutineItemCompleted?(item) ?? false,
                                onRoutineValidate: onRoutineValidate.map { handler in { handler(item) } }
                            )
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                    .opacity(phase.isIdentity ? 1 : 0.76)
                            }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 4)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
                .frame(height: defaultCardSize.height + 8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Carte

enum PlanProtocolCarouselCardLayoutStyle {
    /// Carousel horizontal scrollable (routine matinale…).
    case carousel
    /// Deux cartes fixes côte à côte (entraînement du jour).
    case paired
}

struct PlanProtocolCarouselCard: View {
    let item: PlanProtocolCarouselItem
    var cardWidth: CGFloat = PlanProtocolCarouselLayout.cardWidth
    var cardHeight: CGFloat = PlanProtocolCarouselLayout.cardHeight
    var layoutStyle: PlanProtocolCarouselCardLayoutStyle = .carousel
    var zoomNamespace: Namespace.ID? = nil
    var zoomTransitionID: ProcessZoomTransitionID? = nil
    var onTap: (() -> Void)? = nil
    var routineValidationEnabled: Bool = false
    var isRoutineCompleted: Bool = false
    var onRoutineValidate: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme

    private var isLargeCard: Bool {
        cardWidth > PlanProtocolCarouselLayout.cardWidth + 8
    }

    var body: some View {
        Group {
            if routineValidationEnabled, let onRoutineValidate {
                PlanRoutineHoldValidateOverlay(
                    accent: theme.onboardingAccent,
                    cornerRadius: PlanProtocolCarouselLayout.cornerRadius,
                    isCompleted: isRoutineCompleted,
                    isEnabled: true,
                    onShortTap: { onTap?() },
                    onValidate: onRoutineValidate
                ) {
                    cardBody
                }
            } else if let onTap {
                Button {
                    HapticManager.shared.impact(.light)
                    onTap()
                } label: {
                    cardBody
                }
                .modifier(PlanProtocolCarouselCardPressStyleModifier(layoutStyle: layoutStyle))
            } else {
                cardBody
            }
        }
        .shadow(
            color: .black.opacity(theme.isDark ? 0.45 : 0.12),
            radius: layoutStyle == .paired ? 3 : 2,
            y: 2
        )
        .shadow(
            color: .black.opacity(theme.isDark ? 0.38 : 0.14),
            radius: layoutStyle == .paired ? 14 : 12,
            y: layoutStyle == .paired ? 8 : 7
        )
        .processZoomSource(id: zoomTransitionID, namespace: zoomNamespace)
    }

    private var isSeeAllCard: Bool {
        item.id == PlanProtocolCarouselBuilder.SummaryID.seeAllTraining
    }

    private var cardBody: some View {
        ZStack {
            previewImage

            LinearGradient(
                colors: layoutStyle == .paired
                    ? [.clear, .black.opacity(0.22), .black.opacity(0.82)]
                    : [.black.opacity(0.06), .clear, .black.opacity(0.35), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            if isSeeAllCard {
                seeAllCardChrome
            } else {
                standardCardChrome
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: PlanProtocolCarouselLayout.cornerRadius, style: .continuous))
        .overlay {
            if layoutStyle == .carousel {
                PlanTrainingCardReliefOverlay(
                    cornerRadius: PlanProtocolCarouselLayout.cornerRadius,
                    isDark: theme.isDark
                )
            } else {
                RoundedRectangle(cornerRadius: PlanProtocolCarouselLayout.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(theme.isDark ? 0.14 : 0.22), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
        }
    }

    private var seeAllCardChrome: some View {
        ZStack {
            seeAllCenterGlassLabel

            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    if let repBadge = item.repBadge {
                        Text(repBadge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.96))
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(.black.opacity(0.45))
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                                    }
                            }
                    }
                }
                .padding(10)

                Spacer(minLength: 0)
            }
        }
    }

    private var seeAllCenterGlassLabel: some View {
        Text("Voir tout")
            .font(.system(size: isLargeCard ? 15 : 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.96))
            .padding(.horizontal, isLargeCard ? 22 : 18)
            .padding(.vertical, isLargeCard ? 12 : 10)
            .processGlassEffect(in: Capsule(), interactive: false)
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.32), radius: 10, y: 5)
            .allowsHitTesting(false)
    }

    private var standardCardChrome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                if let stepsProgress = item.stepsProgress {
                    PlanStepsProgressRing(
                        progress: stepsProgress.fraction,
                        size: isLargeCard ? 38 : 34
                    )
                    .padding(10)
                } else if let repBadge = item.repBadge {
                    Text(repBadge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.96))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(.black.opacity(0.45))
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                                }
                        }
                        .padding(10)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: isLargeCard ? 16 : 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let stepsProgress = item.stepsProgress {
                    Text(PlanStepsProgressFormatter.stepsRatio(
                        current: stepsProgress.current,
                        target: stepsProgress.target
                    ))
                    .font(.system(size: isLargeCard ? 14 : 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .monospacedDigit()
                }
            }
            .padding(.horizontal, isLargeCard ? 14 : 12)
            .padding(.bottom, isLargeCard ? 16 : 14)
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        let size = CGSize(width: cardWidth, height: cardHeight)

        Group {
            if let assetName = item.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height, alignment: .top)
            } else {
                fallbackPreview(size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func fallbackPreview(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.coachUserBubble.opacity(theme.isDark ? 0.42 : 0.62),
                    theme.onboardingAccent.opacity(theme.isDark ? 0.22 : 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: item.fallbackSystemImage)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent)
        }
    }
}

private struct PlanProtocolCarouselCardPressStyleModifier: ViewModifier {
    let layoutStyle: PlanProtocolCarouselCardLayoutStyle

    func body(content: Content) -> some View {
        switch layoutStyle {
        case .carousel:
            content.buttonStyle(PlanTrainingCard3DPressStyle(restTilt: 4))
        case .paired:
            content.buttonStyle(PlanTrainingCardPairedPressStyle())
        }
    }
}

// MARK: - Détail exercice / bloc

struct PlanProtocolItemDetailSheet: View {
    let item: PlanProtocolCarouselItem
    var sessionActionTitle: String?
    var onOpenSession: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack(alignment: .bottomLeading) {
                        Group {
                            if let assetName = item.assetName {
                                Image(assetName)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    theme.coachUserBubble.opacity(theme.isDark ? 0.35 : 0.55)
                                    Image(systemName: item.fallbackSystemImage)
                                        .font(.largeTitle.weight(.semibold))
                                        .foregroundStyle(theme.onboardingAccent)
                                }
                            }
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                        .allowsHitTesting(false)

                        VStack(alignment: .leading, spacing: 6) {
                            if let stepsProgress = item.stepsProgress {
                                HStack(spacing: 12) {
                                    PlanStepsProgressRing(
                                        progress: stepsProgress.fraction,
                                        lineWidth: 6,
                                        size: 44
                                    )
                                    Text(PlanStepsProgressFormatter.stepsRatio(
                                        current: stepsProgress.current,
                                        target: stepsProgress.target
                                    ))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                }
                            } else if let repBadge = item.repBadge {
                                Text(repBadge)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(.black.opacity(0.45)))
                            }
                            Text(item.title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    if !item.detailText.isEmpty {
                        Text(item.detailText)
                            .font(.body)
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let sessionActionTitle, let onOpenSession {
                        Button(action: onOpenSession) {
                            Text(sessionActionTitle)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.onboardingAccent)
                    }
                }
                .padding(20)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
    }
}

struct PlanContinuousHabitsInlineSection: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "infinity")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.onboardingAccent)
                Text("À faire 24/7")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .textCase(.uppercase)
            }

            Text("Habitudes continues — pas des exercices à timer, mais à garder toute la journée.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Array(ProcessContinuousHabits.all.enumerated()), id: \.offset) { _, habit in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(theme.onboardingAccent.opacity(0.85))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                            Text(habit.detail)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(HealthHubDesign.softCard(theme: theme))
        }
    }
}

// MARK: - En-tête section

struct PlanProtocolSectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        PlanHomeSectionHeader(title: title, trailingCaption: trailing)
    }
}

// MARK: - Pas / marche

enum PlanStepsProgressFormatter {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()

    static func formatted(_ value: Int) -> String {
        numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func stepsRatio(current: Int, target: Int) -> String {
        "\(formatted(current)) / \(formatted(target))"
    }
}

struct PlanStepsProgressRing: View {
    /// Vert pétant ultra clair — lisible sur photo sombre du carousel.
    private static let brightGreen = Color(red: 0.72, green: 1.0, blue: 0.62)

    var progress: Double
    var lineWidth: CGFloat = 5
    var size: CGFloat = 34
    var trackColor: Color = Color.white.opacity(0.28)
    var fillColor: Color = PlanStepsProgressRing.brightGreen

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .shadow(color: fillColor.opacity(0.55), radius: 4, y: 0)
    }
}
