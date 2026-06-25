import SwiftUI

@MainActor
@Observable
final class CoachTypewriterController {
    private(set) var displayedText = ""
    private(set) var isRunning = false
    private(set) var isComplete = false

    func cancel() {
        isRunning = false
        HapticManager.shared.endTypewriterSession()
    }

    func reset() {
        cancel()
        displayedText = ""
        isComplete = false
    }

    func showImmediately(text: String) {
        cancel()
        displayedText = text
        isComplete = true
    }

    func run(text: String, leadingDelayNanoseconds: UInt64 = 260_000_000) async {
        reset()
        guard !text.isEmpty else {
            isComplete = true
            return
        }

        isRunning = true
        defer {
            isRunning = false
            if !Task.isCancelled {
                isComplete = true
            }
            HapticManager.shared.endTypewriterSession()
        }

        if leadingDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: leadingDelayNanoseconds)
            guard !Task.isCancelled else { return }
        }

        var buffer = ""
        for character in Array(text) {
            try? await Task.sleep(nanoseconds: delay(for: character))
            guard !Task.isCancelled else { return }

            buffer.append(character)
            displayedText = buffer
            HapticManager.shared.typewriterCharacter(character)
        }
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
