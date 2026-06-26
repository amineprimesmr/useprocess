import SwiftUI

// MARK: - Modèle

struct PlanProtocolCarouselItem: Identifiable, Equatable {
    let id: String
    let title: String
    let repBadge: String?
    /// Texte complet — affiché uniquement au tap sur la carte.
    let detailText: String
    let assetName: String?
    let fallbackSystemImage: String
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

    private static func lineItem(
        _ line: String,
        id: String,
        fallback: String,
        category: String? = nil
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
            assetName: TrainingAssetCatalog.blockAsset(for: line),
            fallbackSystemImage: fallback
        )
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
}

// MARK: - Carousel

struct PlanDayProtocolCarousel: View {
    let items: [PlanProtocolCarouselItem]
    var onTap: ((PlanProtocolCarouselItem) -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PlanProtocolCarouselLayout.spacing) {
                ForEach(items) { item in
                    PlanProtocolCarouselCard(
                        item: item,
                        onTap: onTap.map { handler in { handler(item) } }
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
    }
}

// MARK: - Carte

struct PlanProtocolCarouselCard: View {
    let item: PlanProtocolCarouselItem
    var onTap: (() -> Void)? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if let onTap {
                Button {
                    HapticManager.shared.impact(.light)
                    onTap()
                } label: {
                    cardBody
                }
                .buttonStyle(PlanTrainingCard3DPressStyle(restTilt: 4))
            } else {
                cardBody
            }
        }
        .shadow(color: .black.opacity(theme.isDark ? 0.45 : 0.12), radius: 2, y: 2)
        .shadow(color: .black.opacity(theme.isDark ? 0.38 : 0.14), radius: 12, y: 7)
    }

    private var cardBody: some View {
        ZStack(alignment: .bottomLeading) {
            previewImage

            LinearGradient(
                colors: [
                    .black.opacity(0.06),
                    .clear,
                    .black.opacity(0.35),
                    .black.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
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
                            .padding(10)
                    }
                }

                Spacer(minLength: 0)

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
            }
        }
        .frame(width: PlanProtocolCarouselLayout.cardWidth, height: PlanProtocolCarouselLayout.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: PlanProtocolCarouselLayout.cornerRadius, style: .continuous))
        .overlay {
            PlanTrainingCardReliefOverlay(
                cornerRadius: PlanProtocolCarouselLayout.cornerRadius,
                isDark: theme.isDark
            )
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        let size = CGSize(
            width: PlanProtocolCarouselLayout.cardWidth,
            height: PlanProtocolCarouselLayout.cardHeight
        )

        Group {
            if let assetName = item.assetName, ProcessAssetCatalog.contains(assetName) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height, alignment: .top)
            } else {
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
        .frame(width: size.width, height: size.height)
        .clipped()
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
                            if let assetName = item.assetName, ProcessAssetCatalog.contains(assetName) {
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
                            if let repBadge = item.repBadge {
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
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
