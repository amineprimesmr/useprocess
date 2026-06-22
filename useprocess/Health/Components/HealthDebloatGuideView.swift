import SwiftUI

/// Hub éducatif debloat — segments Nutrition · Entraînement · Sommeil · Visage.
struct HealthDebloatGuideView: View {
    var initialPillar: HealthDebloatGuide.Pillar = .nutrition
    var showsPillarPicker: Bool = true
    var showsOuterCard: Bool = true

    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL

    @State private var selectedPillar: HealthDebloatGuide.Pillar = .nutrition
    @State private var expandedTopicIDs: Set<String> = ["mechanism"]

    init(
        initialPillar: HealthDebloatGuide.Pillar = .nutrition,
        showsPillarPicker: Bool = true,
        showsOuterCard: Bool = true
    ) {
        self.initialPillar = initialPillar
        self.showsPillarPicker = showsPillarPicker
        self.showsOuterCard = showsOuterCard
        _selectedPillar = State(initialValue: initialPillar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsPillarPicker {
                header
                pillarPicker
            }

            pillarIntro

            if selectedPillar == .nutrition {
                nutritionIntroCard
            }

            topicList

            if selectedPillar == .nutrition {
                nutritionSourcesFooter
            }
        }
        .padding(showsOuterCard ? 14 : 0)
        .background {
            if showsOuterCard {
                HealthHubDesign.surfaceCard(theme: theme)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selectedPillar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Comprendre le debloat")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            Text("Ce qui compte vraiment — expliqué simplement, à la source.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var pillarPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HealthDebloatGuide.Pillar.allCases) { pillar in
                    pillarChip(pillar)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func pillarChip(_ pillar: HealthDebloatGuide.Pillar) -> some View {
        let isSelected = selectedPillar == pillar
        return Button {
            HapticManager.shared.impact(.light)
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                selectedPillar = pillar
                expandedTopicIDs = [HealthDebloatGuide.topics(for: pillar).first?.id ?? ""]
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: pillar.icon)
                    .font(.caption.weight(.semibold))
                Text(pillar.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(isSelected
                        ? theme.onboardingAccent.opacity(theme.isDark ? 0.22 : 0.14)
                        : theme.coachUserBubble.opacity(0.35))
            }
            .overlay {
                if isSelected {
                    Capsule(style: .continuous)
                        .strokeBorder(theme.onboardingAccent.opacity(0.45), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var pillarIntro: some View {
        Text(selectedPillar.tagline)
            .font(.subheadline)
            .foregroundStyle(theme.primaryText.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nutritionIntroCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.title3)
                .foregroundStyle(theme.onboardingAccent)
                .frame(width: 28)

            Text(HealthDebloatGuide.nutritionIntro)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.onboardingAccent.opacity(theme.isDark ? 0.12 : 0.08))
        )
    }

    private var topicList: some View {
        VStack(spacing: 8) {
            ForEach(HealthDebloatGuide.topics(for: selectedPillar)) { topic in
                topicCard(topic)
            }
        }
    }

    private func topicCard(_ topic: HealthDebloatGuide.Topic) -> some View {
        let isExpanded = expandedTopicIDs.contains(topic.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.shared.impact(.light)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    if isExpanded {
                        expandedTopicIDs.remove(topic.id)
                    } else {
                        expandedTopicIDs.insert(topic.id)
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    topicIcon(topic.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                            .multilineTextAlignment(.leading)
                        Text(topic.summary)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().opacity(0.35)

                    Text(topic.body)
                        .font(.caption)
                        .foregroundStyle(theme.primaryText.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    if !topic.bullets.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(topic.bullets, id: \.self) { bullet in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("•")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme.onboardingAccent)
                                    Text(bullet)
                                        .font(.caption)
                                        .foregroundStyle(theme.primaryText.opacity(0.88))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.coachUserBubble.opacity(theme.isDark ? 0.22 : 0.32))
        )
    }

    private func topicIcon(_ accent: HealthDebloatGuide.TopicAccent) -> some View {
        let symbol: String = switch accent {
        case .sodiumPotassium: "arrow.left.arrow.right"
        case .hydration: "drop.fill"
        case .triggers: "exclamationmark.triangle.fill"
        case .action: "checkmark.circle.fill"
        case .myth: "xmark.circle.fill"
        }
        let tint: Color = switch accent {
        case .sodiumPotassium: theme.onboardingAccent
        case .hydration: .cyan
        case .triggers: .orange
        case .action: .green
        case .myth: theme.secondaryText
        }
        return Image(systemName: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 24, height: 24)
    }

    private var nutritionSourcesFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            ForEach(HealthDebloatGuide.nutritionSources, id: \.label) { source in
                if let url = URL(string: source.url) {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text(source.label)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(theme.onboardingAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(HealthMedicalSources.disclaimer)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}
