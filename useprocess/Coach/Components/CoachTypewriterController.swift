import SwiftUI

@MainActor
@Observable
final class CoachTypewriterController {
    private(set) var displayedText = ""
    private(set) var isRunning = false
    private(set) var isComplete = false

    private var task: Task<Void, Never>?

    func reset() {
        task?.cancel()
        task = nil
        displayedText = ""
        isRunning = false
        isComplete = false
    }

    func showImmediately(text: String) {
        task?.cancel()
        task = nil
        displayedText = text
        isRunning = false
        isComplete = true
    }

    func run(text: String) async {
        reset()
        guard !text.isEmpty else {
            isComplete = true
            return
        }

        isRunning = true
        try? await Task.sleep(nanoseconds: 260_000_000)
        guard !Task.isCancelled else { return }

        task = Task {
            var buffer = ""
            for character in Array(text) {
                guard !Task.isCancelled else { return }

                try? await Task.sleep(nanoseconds: delay(for: character))
                guard !Task.isCancelled else { return }

                buffer.append(character)
                displayedText = buffer

                if character != " " && character != "\n" {
                    HapticManager.shared.impact(.soft)
                }
                if character == "!" || character == "." || character == "?" {
                    HapticManager.shared.impact(.light)
                }
            }
        }

        await task?.value
        isRunning = false
        isComplete = true
    }

    private func delay(for character: Character) -> UInt64 {
        switch character {
        case " ", "\n", "\t":
            return 20_000_000
        case ".", "!", "?", "…":
            return 90_000_000
        case ",", ";", ":":
            return 60_000_000
        default:
            return 36_000_000
        }
    }
}
