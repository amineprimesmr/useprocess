import SwiftUI
import UIKit

// MARK: - Visuels temporaires (même asset partout en attendant le catalogue complet)

private enum PlanTrainingVisuals {
    static let placeholderAsset = "dossport"
    /// Ratio largeur / hauteur de dossport (941×1672).
    static let fallbackAspectRatio: CGFloat = 941.0 / 1672.0
    static let heroMaxHeight: CGFloat = 280

    static func resolvedAssetName(for entry: TrainingSessionCatalogEntry) -> String {
        if ProcessAssetCatalog.contains(placeholderAsset) {
            return placeholderAsset
        }
        if ProcessAssetCatalog.contains(entry.imageAssetName) {
            return entry.imageAssetName
        }
        return placeholderAsset
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

    @State private var detailTarget: PlanTrainingDetailTarget?
    @State private var bookmarkedSessionIDs: Set<String> = PlanTrainingBookmarks.load()

    private var training: OriginDayTraining? { day.training }

    var body: some View {
        let entry = catalogEntry(for: day, training: training)

        VStack(alignment: .leading, spacing: 12) {
            Text("Entraînement du jour")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.primaryText)

            if let training {
                sessionHeroCard(training: training, entry: entry)
            } else {
                restDayCard(entry: entry)
            }
        }
        .sheet(item: $detailTarget) { target in
            PlanTrainingDetailSheet(training: target.training, dayTitle: target.dayTitle)
        }
    }

    private func sessionHeroCard(training: OriginDayTraining, entry: TrainingSessionCatalogEntry) -> some View {
        let isBookmarked = bookmarkedSessionIDs.contains(entry.id.rawValue)

        return PlanTrainingFullBleedCard(
            assetName: PlanTrainingVisuals.resolvedAssetName(for: entry),
            headline: entry.headline,
            muscleTags: entry.muscleTagsLabel,
            durationMinutes: training.durationMinutes,
            footerLine: "\(training.exercises.count) exercices · \(day.weekdayLabel)",
            isBookmarked: isBookmarked,
            cardMaxHeight: PlanTrainingVisuals.heroMaxHeight,
            onBookmark: { toggleBookmark(entry.id.rawValue) },
            onTap: openSessionDetail
        )
    }

    private func restDayCard(entry: TrainingSessionCatalogEntry) -> some View {
        PlanTrainingFullBleedCard(
            assetName: PlanTrainingVisuals.resolvedAssetName(for: entry),
            headline: entry.headline,
            muscleTags: entry.muscleTagsLabel,
            durationMinutes: nil,
            footerLine: "Marche \(formattedSteps)+ pas · mobilité légère",
            isBookmarked: false,
            cardMaxHeight: PlanTrainingVisuals.heroMaxHeight,
            showsBookmark: false,
            onTap: {}
        )
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

    private var formattedSteps: String {
        let target = plan.personalizedTargets?.dailySteps ?? ProcessDailyTargets.dailySteps
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "fr_FR")
        nf.numberStyle = .decimal
        nf.groupingSeparator = " "
        return nf.string(from: NSNumber(value: target)) ?? "\(target)"
    }

    private func toggleBookmark(_ id: String) {
        if bookmarkedSessionIDs.contains(id) {
            bookmarkedSessionIDs.remove(id)
        } else {
            bookmarkedSessionIDs.insert(id)
        }
        PlanTrainingBookmarks.save(bookmarkedSessionIDs)
    }

    @MainActor
    private func catalogEntry(for day: OriginProgramDay, training: OriginDayTraining?) -> TrainingSessionCatalogEntry {
        if let training {
            return TrainingSessionCatalog.entry(for: training)
        }
        return TrainingSessionCatalog.entry(for: .restDay)
    }
}

// MARK: - Détail séance

struct PlanTrainingDetailTarget: Identifiable, Equatable {
    let dayId: String
    let training: OriginDayTraining
    let dayTitle: String

    var id: String { dayId }
}

private struct PlanTrainingFullBleedCard: View {
    let assetName: String
    let headline: String
    let muscleTags: String
    var durationMinutes: Int?
    var footerLine: String?
    var isBookmarked: Bool
    var cardWidth: CGFloat? = nil
    var cardMaxHeight: CGFloat? = nil
    var cornerRadius: CGFloat = 26
    var showsBookmark: Bool = true
    var titleFontSize: CGFloat = 17
    var onBookmark: (() -> Void)? = nil
    var onTap: () -> Void

    @Environment(\.appTheme) private var theme

    private var imageAspectRatio: CGFloat {
        PlanTrainingVisuals.aspectRatio(for: assetName)
    }

    var body: some View {
        cardFrame
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    PlanTrainingCardImage(assetName: assetName)

                    VStack {
                        HStack(alignment: .top) {
                            if showsBookmark {
                                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.black.opacity(0.28)))
                                    .contentShape(Circle())
                                    .onTapGesture {
                                        onBookmark?()
                                    }
                            }

                            Spacer(minLength: 0)

                            if let durationMinutes {
                                Text("\(durationMinutes) min")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.black.opacity(0.32)))
                            }
                        }
                        .padding(14)

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
                            .foregroundStyle(Color.white.opacity(0.58))
                            .lineLimit(2)

                        if let footerLine, !footerLine.isEmpty {
                            Text(footerLine)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.55), .black.opacity(0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(theme.isDark ? 0.42 : 0.16), radius: 18, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onTapGesture(perform: onTap)
    }

    @ViewBuilder
    private var cardFrame: some View {
        if let cardMaxHeight {
            Color.clear
                .aspectRatio(imageAspectRatio, contentMode: .fit)
                .frame(height: cardMaxHeight)
                .frame(maxWidth: .infinity)
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

private struct PlanTrainingCardImage: View {
    let assetName: String

    var body: some View {
        Group {
            if ProcessAssetCatalog.contains(assetName) {
                Image(assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(red: 0.09, green: 0.09, blue: 0.10)
            }
        }
        .overlay {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.48)
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
