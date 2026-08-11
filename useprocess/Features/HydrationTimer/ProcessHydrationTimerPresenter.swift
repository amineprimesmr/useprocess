import Foundation
import SwiftUI

struct ProcessHydrationTimerPresentation: Identifiable, Equatable {
    let id: String
    let source: ProcessHydrationTimerDueSource
    let createdAt: Date

    init(source: ProcessHydrationTimerDueSource) {
        self.source = source
        self.createdAt = Date()
        self.id = "\(source.rawValue)-\(Int(createdAt.timeIntervalSince1970))"
    }
}

@MainActor
@Observable
final class ProcessHydrationTimerPresenter {
    static let shared = ProcessHydrationTimerPresenter()

    private(set) var presentation: ProcessHydrationTimerPresentation?

    private init() {}

    func present(source: ProcessHydrationTimerDueSource) {
        if presentation != nil { return }
        presentation = ProcessHydrationTimerPresentation(source: source)
    }

    func clear() {
        presentation = nil
    }
}
