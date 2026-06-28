import SwiftUI

/// Guide debloat unifié — une seule page, leviers classés par impact.
struct HealthDebloatGuideView: View {
    var showsOuterCard: Bool = true

    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL

    @State private var expandedTopicIDs: Set<String> = ["mechanism"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            introBlock

            priorityLegend

            rankedTopicList

            sourcesFooter
        }
        .padding(showsOuterCard ? 14 : 0)
        .background {
            if showsOuterCard {
                HealthHubDesign.surfaceCard(theme: theme)
            }
        }
    }

    private var introBlock: some View {
        Text(HealthDebloatGuide.pageIntro)
            .font(.subheadline)
            .foregroundStyle(theme.primaryText.opacity(0.92))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var priorityLegend: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.onboardingAccent)
            Text("Du plus impactant (#1) au complémentaire — tout sur une page.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.onboardingAccent.opacity(theme.isDark ? 0.12 : 0.08))
        )
    }

    private var rankedTopicList: some View {
        VStack(spacing: 8) {
            ForEach(HealthDebloatGuide.rankedTopics) { ranked in
                rankedTopicCard(ranked)
            }
        }
    }

    private func rankedTopicCard(_ ranked: HealthDebloatGuide.RankedTopic) -> some View {
        let topic = ranked.topic
        let isExpanded = expandedTopicIDs.contains(topic.id)
        let isHighPriority = ranked.rank <= 4

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
                    priorityBadge(rank: ranked.rank, emphasized: isHighPriority)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: topic.pillar.icon)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                            Text(topic.pillar.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                        }

                        Text(topic.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                            .multilineTextAlignment(.leading)

                        Text(topic.summary)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .padding(.top, 4)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().opacity(0.35)

                    HStack(alignment: .top, spacing: 10) {
                        topicIcon(topic.accent)
                        Text(topic.body)
                            .font(.caption)
                            .foregroundStyle(theme.primaryText.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if topic.id == "continuous-habits" {
                        continuousHabitsDetailBlock
                    } else if !topic.bullets.isEmpty {
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
                .fill(
                    isHighPriority
                        ? theme.onboardingAccent.opacity(theme.isDark ? 0.10 : 0.06)
                        : theme.coachUserBubble.opacity(theme.isDark ? 0.22 : 0.32)
                )
        )
        .overlay {
            if isHighPriority {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.onboardingAccent.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private func priorityBadge(rank: Int, emphasized: Bool) -> some View {
        Text("\(rank)")
            .font(.system(size: emphasized ? 15 : 13, weight: .bold, design: .rounded))
            .foregroundStyle(emphasized ? theme.primaryText : theme.secondaryText)
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(
                        emphasized
                            ? theme.onboardingAccent.opacity(theme.isDark ? 0.35 : 0.22)
                            : theme.coachUserBubble.opacity(0.5)
                    )
            }
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

    private var continuousHabitsDetailBlock: some View {
        VStack(spacing: 8) {
            ForEach(Array(ProcessContinuousHabits.all.enumerated()), id: \.offset) { _, habit in
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(habit.detail)
                        .font(.caption)
                        .foregroundStyle(theme.primaryText.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.coachUserBubble.opacity(theme.isDark ? 0.28 : 0.4))
                )
            }
        }
    }

    private var sourcesFooter: some View {
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
