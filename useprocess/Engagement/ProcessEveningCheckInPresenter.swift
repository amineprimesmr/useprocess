import Foundation
import SwiftUI

/// Session de bilan présentée en overlay Dynamic Island (requis ou volontaire).
struct ProcessEveningCheckInPresentation: Identifiable, Equatable {
    let id: String
    let targetDate: Date
    let isRequired: Bool

    init(targetDate: Date, isRequired: Bool = false, calendar: Calendar = .current) {
        self.targetDate = calendar.startOfDay(for: targetDate)
        self.isRequired = isRequired
        let dayKey = ProcessStreakStore.dayKey(for: targetDate, calendar: calendar)
        self.id = "\(dayKey)-\(isRequired ? "required" : "optional")"
    }
}

@MainActor
@Observable
final class ProcessEveningCheckInPresenter {
    static let shared = ProcessEveningCheckInPresenter()

    private(set) var presentation: ProcessEveningCheckInPresentation?
    var onCompleted: (() -> Void)?

    private init() {}

    func present(targetDate: Date, isRequired: Bool = false, onCompleted: (() -> Void)? = nil) {
        self.onCompleted = onCompleted
        let next = ProcessEveningCheckInPresentation(targetDate: targetDate, isRequired: isRequired)
        if presentation?.id != next.id {
            presentation = next
        }
    }

    func present(_ value: ProcessEveningCheckInPresentation, onCompleted: (() -> Void)? = nil) {
        self.onCompleted = onCompleted
        if presentation?.id != value.id {
            presentation = value
        }
    }

    func clear() {
        presentation = nil
        onCompleted = nil
    }

    func markCompleted() {
        onCompleted?()
        onCompleted = nil
    }
}
