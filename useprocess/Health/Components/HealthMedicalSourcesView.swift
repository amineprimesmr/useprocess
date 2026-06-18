import SwiftUI

enum HealthMedicalSources {
    struct Reference: Identifiable {
        let id: String
        let title: String
        let url: URL
    }

    static let disclaimer =
        "Les scores, rapports et recommandations Process AI sont des estimations bien-être. Ils ne remplacent pas un avis médical, kinésithérapique ou dermatologique."

    static let references: [Reference] = [
        .init(
            id: "apple_health",
            title: "Apple Santé — données et confidentialité",
            url: URL(string: "https://www.apple.com/fr/health/")!
        ),
        .init(
            id: "who_activity",
            title: "OMS — activité physique et santé",
            url: URL(string: "https://www.who.int/fr/news-room/fact-sheets/detail/physical-activity")!
        ),
        .init(
            id: "cdc_activity",
            title: "CDC — bases de l'activité physique",
            url: URL(string: "https://www.cdc.gov/physical-activity-basics/?CDC_AAref_Val=https://www.cdc.gov/physicalactivity/basics/index.htm")!
        ),
        .init(
            id: "aha_fitness",
            title: "American Heart Association — fitness",
            url: URL(string: "https://www.heart.org/en/healthy-living/fitness")!
        ),
        .init(
            id: "nih_sleep",
            title: "NIH — sommeil et santé",
            url: URL(string: "https://www.nhlbi.nih.gov/health/sleep")!
        )
    ]
}

struct HealthMedicalSourcesView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.appTheme) private var theme

    var style: Style = .full
    var showsDisclaimer: Bool = true

    enum Style {
        case compact
        case full
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? 8 : 12) {
            if showsDisclaimer {
                Text(HealthMedicalSources.disclaimer)
                    .font(style == .compact ? .caption2 : .caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Sources et références")
                .font(style == .compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            ForEach(HealthMedicalSources.references) { reference in
                Button {
                    openURL(reference.url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.onboardingAccent)
                        Text(reference.title)
                            .font(style == .compact ? .caption : .subheadline)
                            .foregroundStyle(theme.onboardingAccent)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
