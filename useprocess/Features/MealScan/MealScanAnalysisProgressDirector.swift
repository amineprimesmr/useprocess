import Foundation
import Observation

/// Orchestre les étapes checklist pendant l’analyse repas (loading → check).
@MainActor
@Observable
final class MealScanAnalysisProgressDirector {
    enum StepStatus: Equatable {
        case pending
        case loading
        case completed
    }

    struct Step: Identifiable, Equatable {
        let id: String
        let title: String
        let systemImage: String
    }

    private(set) var steps: [Step] = []
    private(set) var statuses: [StepStatus] = []
    private(set) var activeStepIndex: Int = 0
    private(set) var isRevealReady = false
    private(set) var isRunning = false

    private var tickTask: Task<Void, Never>?
    private var analysisComplete = false

    /// Délai avant de cocher chaque étape (attente réseau).
    private let stepHold: TimeInterval = 0.85
    /// Dernière étape reste en loading tant que l’API n’a pas répondu.
    private var lastStepIndex: Int { max(steps.count - 1, 0) }

    var completedCount: Int {
        statuses.filter { $0 == .completed }.count
    }

    init() {
        rebuildSteps()
    }

    func start() {
        tickTask?.cancel()
        rebuildSteps()
        statuses = Array(repeating: .pending, count: steps.count)
        if !statuses.isEmpty {
            statuses[0] = .loading
        }
        activeStepIndex = 0
        isRevealReady = false
        analysisComplete = false
        isRunning = true

        tickTask = Task { [weak self] in
            await self?.runChecklist()
        }
    }

    func markAnalysisComplete() {
        analysisComplete = true
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        isRunning = false
    }

    // MARK: - Checklist

    private func runChecklist() async {
        guard !steps.isEmpty else {
            isRevealReady = true
            return
        }

        for index in steps.indices {
            guard !Task.isCancelled else { return }

            activeStepIndex = index
            withStatusUpdate {
                // Coche les précédentes, met la courante en loading.
                for i in statuses.indices {
                    if i < index {
                        statuses[i] = .completed
                    } else if i == index {
                        statuses[i] = .loading
                    } else {
                        statuses[i] = .pending
                    }
                }
            }

            if index == lastStepIndex {
                // Dernière étape : attend la fin réelle de l’analyse (min. un beat).
                try? await Task.sleep(for: .milliseconds(Int(stepHold * 1000)))
                while !analysisComplete, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(120))
                }
            } else {
                try? await Task.sleep(for: .milliseconds(Int(stepHold * 1000)))
                // Si l’API a déjà fini, on accélère le reste.
                if analysisComplete {
                    try? await Task.sleep(for: .milliseconds(180))
                }
            }

            guard !Task.isCancelled else { return }
            withStatusUpdate {
                statuses[index] = .completed
            }
            HapticManager.shared.selection()
        }

        isRunning = false
        try? await Task.sleep(for: .milliseconds(320))
        guard !Task.isCancelled else { return }
        isRevealReady = true
    }

    private func withStatusUpdate(_ update: () -> Void) {
        update()
    }

    private func rebuildSteps() {
        steps = [
            Step(
                id: "ingredients",
                title: AppCopy.t("Récolte des ingrédients", en: "Collecting ingredients"),
                systemImage: "leaf.fill"
            ),
            Step(
                id: "potassium",
                title: AppCopy.t("Analyse du potassium", en: "Analyzing potassium"),
                systemImage: "bolt.fill"
            ),
            Step(
                id: "sodium",
                title: AppCopy.t("Analyse du sodium", en: "Analyzing sodium"),
                systemImage: "drop.fill"
            ),
            Step(
                id: "magnesium",
                title: AppCopy.t("Analyse du magnésium", en: "Analyzing magnesium"),
                systemImage: "sparkles"
            ),
            Step(
                id: "balance",
                title: AppCopy.t("Équilibre K / Na", en: "K / Na balance"),
                systemImage: "arrow.left.arrow.right"
            ),
            Step(
                id: "score",
                title: AppCopy.t("Calcul du score debloat", en: "Computing debloat score"),
                systemImage: "chart.bar.fill"
            )
        ]
        statuses = Array(repeating: .pending, count: steps.count)
    }
}
