import SwiftUI

/// Singleton presenter — contrôle l'overlay checklist du soir depuis n'importe quelle vue.
@MainActor
@Observable
final class ProcessEveningCheckInPresenter {
    static let shared = ProcessEveningCheckInPresenter()

    var isPresented: Bool = false
    var targetDate: Date = Date()
    var isRequired: Bool = false
    var onCompleted: (() -> Void)?

    private init() {}

    func present(
        targetDate: Date = Date(),
        isRequired: Bool = false,
        onCompleted: (() -> Void)? = nil
    ) {
        self.targetDate = targetDate
        self.isRequired = isRequired
        self.onCompleted = onCompleted
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            isPresented = true
        }
    }

    func clear() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            isPresented = false
        }
        onCompleted = nil
    }

    func markCompleted() {
        onCompleted?()
        clear()
    }
}
