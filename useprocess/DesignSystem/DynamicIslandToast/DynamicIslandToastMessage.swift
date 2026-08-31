import SwiftUI

struct DynamicIslandToastMessage: Equatable {
    private(set) var id: String = UUID().uuidString
    var symbol: String
    var symbolFont: Font
    var symbolForegroundStyle: (Color, Color)
    var title: String
    var message: String
    /// Streak avant / après — anime le compteur X → Y quand renseigné.
    var streakBefore: Int? = nil
    var streakAfter: Int? = nil
    /// Progression 0...1 vers le prochain palier de série.
    var streakProgress: Double? = nil

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension DynamicIslandToastMessage {
    static func streak(snapshot: ProcessStreakSnapshot, firstName: String?) -> DynamicIslandToastMessage {
        let validatedToday = snapshot.isTodayComplete
        return DynamicIslandToastMessage(
            symbol: validatedToday ? "checkmark.circle.fill" : "flame.fill",
            symbolFont: .system(size: 32, weight: .semibold),
            symbolForegroundStyle: (.white, ProcessStreakPalette.flame),
            title: validatedToday
                ? snapshot.streakTitle
                : AppCopy.t("Check du jour", en: "Today's Check-In"),
            message: validatedToday
                ? snapshot.encouragement(firstName: firstName)
                : AppCopy.t("Valide ton check pour compter ce jour.", en: "Complete your check-in to count this day.")
        )
    }

    /// Scan du jour enregistré — compteur de série animé + barre de progression vers le prochain palier.
    static func scanCompleted(
        streakBefore: Int,
        streakAfter: Int,
        nextMilestoneDays: Int?
    ) -> DynamicIslandToastMessage {
        let isFirstDay = streakBefore == 0 && streakAfter > 0
        let progress: Double = {
            guard let nextMilestoneDays, nextMilestoneDays > 0 else { return 1 }
            return min(1, max(0, Double(streakAfter) / Double(nextMilestoneDays)))
        }()

        return DynamicIslandToastMessage(
            symbol: "flame.fill",
            symbolFont: .system(size: 32, weight: .semibold),
            symbolForegroundStyle: (.white, ProcessStreakPalette.flame),
            title: AppCopy.t("Scan enregistré", en: "Scan saved"),
            message: isFirstDay
                ? AppCopy.t("Premier jour de ta série !", en: "First day of your streak!")
                : AppCopy.t(
                    "\(streakAfter) jours de série d'affilée",
                    en: "\(streakAfter)-day streak"
                ),
            streakBefore: streakBefore,
            streakAfter: streakAfter,
            streakProgress: progress
        )
    }
}
