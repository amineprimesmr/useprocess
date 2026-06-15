import Foundation

/// Lisse les landmarks Vision — mode live réactif ou capture stable.
nonisolated final class LandmarkSmoother: @unchecked Sendable {

    private var state: [String: BodyLandmark] = [:]
    private let alpha: Double
    private let keepMissingJoints: Bool

    init(liveMode: Bool) {
        self.alpha = liveMode ? 0.78 : 0.22
        self.keepMissingJoints = !liveMode
    }

    nonisolated func apply(_ incoming: [BodyLandmark]) -> [BodyLandmark] {
        guard !incoming.isEmpty else {
            if keepMissingJoints {
                return Array(state.values).filter { $0.confidence >= 0.2 }
            }
            return []
        }

        var result: [BodyLandmark] = []
        let incomingNames = Set(incoming.map(\.name))

        for lm in incoming where lm.confidence >= 0.2 {
            if let prev = state[lm.name] {
                let smoothed = BodyLandmark(
                    name: lm.name,
                    x: alpha * lm.x + (1 - alpha) * prev.x,
                    y: alpha * lm.y + (1 - alpha) * prev.y,
                    confidence: max(lm.confidence, prev.confidence * 0.95)
                )
                state[lm.name] = smoothed
                result.append(smoothed)
            } else {
                state[lm.name] = lm
                result.append(lm)
            }
        }

        if keepMissingJoints {
            for (name, prev) in state where !incomingNames.contains(name) {
                let decayed = BodyLandmark(
                    name: name,
                    x: prev.x,
                    y: prev.y,
                    confidence: prev.confidence * 0.85
                )
                if decayed.confidence >= 0.18 {
                    state[name] = decayed
                    result.append(decayed)
                } else {
                    state.removeValue(forKey: name)
                }
            }
        } else {
            for name in state.keys where !incomingNames.contains(name) {
                state.removeValue(forKey: name)
            }
        }

        return result
    }

    nonisolated func reset() {
        state.removeAll()
    }
}

/// Stabilise le statut « prêt » avec hystérésis (évite les bascules rapides).
nonisolated final class ReadyStateStabilizer: @unchecked Sendable {
    private var readyFrames = 0
    private var notReadyFrames = 0
    private(set) var isStableReady = false

    private let readyThreshold = 10
    private let notReadyThreshold = 5

    func update(isReady: Bool) -> Bool {
        if isReady {
            readyFrames += 1
            notReadyFrames = 0
            if readyFrames >= readyThreshold {
                isStableReady = true
            }
        } else {
            notReadyFrames += 1
            if notReadyFrames >= notReadyThreshold {
                readyFrames = 0
                isStableReady = false
            }
        }
        return isStableReady
    }

    func reset() {
        readyFrames = 0
        notReadyFrames = 0
        isStableReady = false
    }

    var shouldStartCountdown: Bool {
        readyFrames == readyThreshold && isStableReady
    }
}
