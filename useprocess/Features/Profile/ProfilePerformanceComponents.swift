import SwiftUI
import UIKit

enum ProfileAnalyticsRange: String, CaseIterable, Identifiable {
    case week = "Semaine"
    case month = "Mois"
    case all = "Tout"

    var id: String { rawValue }

    /// Fenêtre par défaut sur le profil — tout l'historique chargé (90 j).
    static let profileDefault: ProfileAnalyticsRange = .all
}

struct ProfileAnalyticsPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let value: Double
}

enum ProfilePerformancePalette {
    static let peach = Color(red: 1.0, green: 0.66, blue: 0.52)
    static let blue = Color(red: 0.33, green: 0.72, blue: 1.0)
}

// MARK: - Top bar

struct ProfilePageTopBar: View {
    @Environment(\.appTheme) private var theme
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Profil")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: 0)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paramètres")
        }
    }
}

// MARK: - Identité

struct ProfileIdentityHeader: View {
    @Environment(\.appTheme) private var theme

    let profile: SocialProfile
    let image: UIImage?
    let onPhotoTap: (CGPoint) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ProfileAvatarButton(image: image, onPhotoTap: onPhotoTap)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if !usernameTag.isEmpty {
                    Text(usernameTag)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var usernameTag: String {
        ProcessUsernameTag.display(profile.username)
    }
}

private struct ProfileAvatarButton: View {
    @Environment(\.appTheme) private var theme

    let image: UIImage?
    let onPhotoTap: (CGPoint) -> Void

    private let size: CGFloat = 72

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(theme.cardBackgroundStrong)

                    Image(systemName: "person.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(theme.cardStroke, lineWidth: 0.5)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onEnded { value in onPhotoTap(value.location) }
        )
        .accessibilityLabel("Photo de profil")
        .accessibilityHint("Touchez pour la modifier")
    }
}

// MARK: - Évolution (graphique multi-métriques)

private enum ProfileMetricChartMetrics {
    static let cardRadius: CGFloat = 30
    static let chartHeight: CGFloat = 46
    static let cardPadding: CGFloat = 16
}

struct ProfileMetricChartSection: View {
    @Environment(\.appTheme) private var theme

    let metric: ProfileChartMetric
    let points: [ProfileAnalyticsPoint]
    let latestValue: Double?
    let deltaVsPrevious: Double?

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ProfileMetricChartMetrics.cardRadius, style: .continuous)
    }

    private var showsChart: Bool {
        !points.isEmpty
    }

    var body: some View {
        cardContent
            .padding(ProfileMetricChartMetrics.cardPadding)
            .background { cardBackground }
            .clipShape(cardShape)
            .processHomeGlassCardShadow(isDark: theme.isDark)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.rawValue)
                .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            metricHeader
            if showsChart {
                ProfileWeightChart(
                    points: points,
                    metric: metric,
                    theme: theme,
                    compact: true
                )
                .frame(height: ProfileMetricChartMetrics.chartHeight)
            } else {
                Text(latestValue != nil ? metric.emptySinglePointMessage : metric.emptyNoDataMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: ProfileMetricChartMetrics.chartHeight, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        cardShape
            .fill(.clear)
            .processGlassEffect(in: cardShape, interactive: false)
    }

    private var metricHeader: some View {
        ProfileMetricSummaryHeader(
            metric: metric,
            latestValue: latestValue,
            deltaVsPrevious: deltaVsPrevious,
            theme: theme
        )
    }
}

typealias ProfileWeightSection = ProfileMetricChartSection
typealias ProfileRegularitySection = ProfileMetricChartSection

private struct ProfileMetricSummaryHeader: View {
    let metric: ProfileChartMetric
    let latestValue: Double?
    let deltaVsPrevious: Double?
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let latestValue {
                    Text(metric.axisStyle.formatSummary(latestValue))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(metric.chartLineColor(theme: theme))
                } else {
                    Text("—")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.secondaryText)
                }

                Text(metric.summarySubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }

            ProfileMetricComparisonLabel(
                metric: metric,
                deltaVsPrevious: deltaVsPrevious,
                theme: theme
            )
            .font(.system(size: 13))
            .foregroundStyle(theme.secondaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProfileMetricComparisonLabel: View {
    let metric: ProfileChartMetric
    let deltaVsPrevious: Double?
    let theme: AppTheme

    private var deltaThreshold: Double {
        switch metric {
        case .weight: return 0.1
        case .retention: return 1
        }
    }

    var body: some View {
        if let deltaVsPrevious, abs(deltaVsPrevious) >= deltaThreshold {
            HStack(spacing: 0) {
                Text("Évolution : ")
                Text(metric.axisStyle.formatDelta(deltaVsPrevious))
                    .foregroundStyle(deltaColor(deltaVsPrevious))
                    .fontWeight(.bold)
                Text(" vs période précédente.")
            }
        } else if deltaVsPrevious != nil {
            Text("Stable vs la période précédente.")
        } else {
            Text(metric.syncHint)
        }
    }

    private func deltaColor(_ delta: Double) -> Color {
        let isPositive = metric.lowerDeltaIsPositive ? delta <= 0 : delta >= 0
        return isPositive ? ProfilePerformancePalette.peach : ProfilePerformancePalette.blue
    }
}
