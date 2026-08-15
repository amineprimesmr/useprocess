import SwiftUI

struct DynamicIslandToastMessage: Equatable {
    private(set) var id: String = UUID().uuidString
    var symbol: String
    var symbolFont: Font
    var symbolForegroundStyle: (Color, Color)
    var title: String
    var message: String

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
}
