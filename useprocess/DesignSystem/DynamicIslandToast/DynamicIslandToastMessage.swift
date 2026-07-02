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
        DynamicIslandToastMessage(
            symbol: "flame.fill",
            symbolFont: .system(size: 32, weight: .semibold),
            symbolForegroundStyle: (.white, ProcessStreakPalette.flame),
            title: snapshot.streakTitle,
            message: snapshot.encouragement(firstName: firstName)
        )
    }
}
