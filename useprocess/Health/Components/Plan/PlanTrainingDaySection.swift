import SwiftUI
import UIKit

// MARK: - Visuels

enum PlanTrainingVisuals {
    static let placeholderAsset = "dossport"
    /// Ratio largeur / hauteur de dossport (941×1672).
    static let fallbackAspectRatio: CGFloat = 941.0 / 1672.0
    static let heroMaxHeight: CGFloat = 296

    static func resolvedAssetName(for entry: TrainingSessionCatalogEntry) -> String {
        TrainingAssetCatalog.resolvedHeroAsset(for: entry)
    }

    static func aspectRatio(for assetName: String) -> CGFloat {
        guard ProcessAssetCatalog.contains(assetName),
              let image = UIImage(named: assetName),
              image.size.height > 0 else {
            return fallbackAspectRatio
        }
        return image.size.width / image.size.height
    }
}

// MARK: - Section entraînement (page Plan)

struct PlanTrainingDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay
    var selectedDate: Date = Date()
    var isEditable: Bool = true

    @Environment(\.appTheme) private var theme

    @Namespace private var trainingZoomNamespace
    @State private var detailTarget: PlanTrainingDetailTarget?
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?

    private var training: OriginDayTraining? { day.training }

    var body: some View {
        if let training {
            let items = PlanProtocolCarouselBuilder.trainingItems(from: training)

            VStack(alignment: .leading, spacing: 14) {
                PlanProtocolSectionHeader(
                    title: "Entraînement du jour",
                    trailing: trainingHeaderTrailing(for: training, itemCount: items.count)
                )

                if items.isEmpty {
                    Text("Aucun exercice planifié pour cette séance.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                } else {
                    PlanDayProtocolCarousel(items: items) { item in
                        selectedProtocolItem = item
                    }
                    .processZoomSource(id: .trainingDay, namespace: trainingZoomNamespace)
                }
            }
            .sheet(item: $selectedProtocolItem) { item in
                PlanProtocolItemDetailSheet(
                    item: item,
                    sessionActionTitle: "Voir toute la séance",
                    onOpenSession: {
                        selectedProtocolItem = nil
                        openSessionDetail()
                    }
                )
            }
            .fullScreenCover(item: $detailTarget) { target in
                PlanTrainingDetailSheet(training: target.training, dayTitle: target.dayTitle)
                    .processZoomTransition(id: .trainingDay, namespace: trainingZoomNamespace)
            }
        }
    }

    private func trainingHeaderTrailing(for training: OriginDayTraining, itemCount: Int) -> String {
        var parts: [String] = []
        if training.durationMinutes > 0 {
            parts.append("\(training.durationMinutes) min")
        }
        if itemCount > 0 {
            parts.append("\(itemCount) ex.")
        }
        return parts.joined(separator: " · ")
    }

    private func openSessionDetail() {
        guard let training else { return }
        HapticManager.shared.impact(.light)
        detailTarget = PlanTrainingDetailTarget(
            dayId: day.id,
            training: training,
            dayTitle: day.title
        )
    }
}

// MARK: - Détail séance

struct PlanTrainingDetailTarget: Identifiable, Equatable {
    let dayId: String
    let training: OriginDayTraining
    let dayTitle: String

    var id: String { dayId }
}

struct PlanTrainingFullBleedCard: View {
    let assetName: String
    let headline: String
    let muscleTags: String
    var durationMinutes: Int?
    var footerLine: String?
    var isBookmarked: Bool
    var cardWidth: CGFloat? = nil
    var cardMaxHeight: CGFloat? = nil
    var cornerRadius: CGFloat = 28
    var showsBookmark: Bool = true
    var titleFontSize: CGFloat = 18
    var onBookmark: (() -> Void)? = nil
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var imageAspectRatio: CGFloat {
        PlanTrainingVisuals.aspectRatio(for: assetName)
    }

    var body: some View {
        Button {
            HapticManager.shared.impact(.light)
            onTap()
        } label: {
            cardFrame
                .overlay { cardContent }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay { PlanTrainingCardReliefOverlay(cornerRadius: cornerRadius, isDark: theme.isDark) }
        }
        .buttonStyle(PlanTrainingCard3DPressStyle())
        .shadow(color: .black.opacity(theme.isDark ? 0.55 : 0.14), radius: 2, x: 0, y: 2)
        .shadow(color: .black.opacity(theme.isDark ? 0.42 : 0.16), radius: 16, x: 0, y: 10)
        .shadow(color: theme.onboardingAccent.opacity(theme.isDark ? 0.14 : 0.08), radius: 24, x: 0, y: 14)
    }

    private var cardContent: some View {
        ZStack(alignment: .bottomLeading) {
            PlanTrainingCardImage(assetName: assetName, imageScale: 1.14)

            VStack {
                HStack(alignment: .top) {
                    if showsBookmark {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(.black.opacity(0.32))
                                    .overlay {
                                        Circle()
                                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                                    }
                            }
                            .contentShape(Circle())
                            .onTapGesture {
                                HapticManager.shared.selection()
                                onBookmark?()
                            }
                    }

                    Spacer(minLength: 0)

                    if let durationMinutes {
                        Text("\(durationMinutes) min")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.94))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background {
                                Capsule()
                                    .fill(.black.opacity(0.36))
                                    .overlay {
                                        Capsule()
                                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                                    }
                            }
                    }
                }
                .padding(16)

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(headline)
                    .font(.system(size: titleFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(muscleTags)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .lineLimit(2)

                if let footerLine, !footerLine.isEmpty {
                    Text(footerLine)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.42), .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private var cardFrame: some View {
        if let cardMaxHeight {
            let maxCardWidth = max(UIScreen.main.bounds.width - 28, 240)
            let cardWidth = min(cardMaxHeight * imageAspectRatio, maxCardWidth)
            let cardHeight = cardWidth / max(imageAspectRatio, 0.1)

            Color.clear
                .frame(width: cardWidth, height: cardHeight)
        } else if let cardWidth {
            Color.clear
                .aspectRatio(imageAspectRatio, contentMode: .fit)
                .frame(width: cardWidth)
        } else {
            Color.clear
                .aspectRatio(imageAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
    }
}

struct PlanTrainingCardImage: View {
    let assetName: String
    var imageScale: CGFloat = 1.08

    var body: some View {
        Group {
            if ProcessAssetCatalog.contains(assetName) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(imageScale)
            } else {
                Color(red: 0.09, green: 0.09, blue: 0.10)
            }
        }
        .overlay {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.08),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Favoris locaux

enum PlanTrainingBookmarks {
    private static var storageKey: String {
        UserScopedStorage.key("plan.training.bookmarks", userId: UserScopedStorage.currentUserId() ?? "local-user")
    }

    static func load() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    static func save(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: storageKey)
    }
}
