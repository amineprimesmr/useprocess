import StoreKit
import SwiftUI

/// Moments où StoreKit peut afficher le prompt natif — jamais pendant l’onboarding.
enum ProcessAppStoreReviewOpportunity: String {
    case improvedScan = "improved_scan"
    case streak7 = "streak_7"
}

/// Prompt App Store aligné HIG + StoreKit `RequestReviewAction`.
///
/// Apple affiche au plus 3 fois / 365 jours. On ne demande qu’après un win
/// (scan quotidien en hausse, ou série 7 jours), une fois par version, avec
/// 14 jours de cooldown.
@MainActor
enum ProcessAppStoreReviewPrompt {
    static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id\(ProcessAppUpdateChecker.appStoreID)?action=write-review"
    )!

    private static let lastVersionKey = "process.appStoreReview.lastVersionPrompted"
    private static let lastDateKey = "process.appStoreReview.lastPromptAt"
    private static let lastSourceKey = "process.appStoreReview.lastSource"
    private static let legacyOnboardingKey = "onboarding.faceScan.appStoreRating.shown"

    private static let cooldown: TimeInterval = 14 * 24 * 60 * 60
    private static let streakMilestone = 7
    private static let minimumScanCount = 2
    private static let minimumScoreLift = 2
    private static let presentDelay: Duration = .seconds(2)

    private static var isPresenting = false

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    static func consider(
        _ opportunity: ProcessAppStoreReviewOpportunity,
        requestReview: RequestReviewAction
    ) {
        Task { await presentIfEligible(opportunity, requestReview: requestReview) }
    }

    static func presentIfEligible(
        _ opportunity: ProcessAppStoreReviewOpportunity,
        requestReview: RequestReviewAction
    ) async {
        migrateLegacyOnboardingPromptIfNeeded()
        guard !isPresenting, isEligible(opportunity) else { return }

        isPresenting = true
        defer { isPresenting = false }

        try? await Task.sleep(for: presentDelay)
        guard !Task.isCancelled else { return }
        guard isEligible(opportunity) else { return }

        markPresented(source: opportunity.rawValue)
        ProcessAnalytics.trackAppStoreReviewPrompted(source: opportunity.rawValue)
        requestReview()
    }

    static func isEligible(_ opportunity: ProcessAppStoreReviewOpportunity) -> Bool {
        guard AppSession.shared.hasCompletedOnboarding else { return false }
        guard lastVersionPrompted.isEmpty || lastVersionPrompted != currentVersion else { return false }
        if let last = lastPromptDate, Date().timeIntervalSince(last) < cooldown {
            return false
        }

        switch opportunity {
        case .improvedScan:
            return hasImprovedDailyScan()
        case .streak7:
            return ProcessStreakStore.shared.displayStreak >= streakMilestone
        }
    }

    // MARK: - Persistence

    private static var lastVersionPrompted: String {
        UserDefaults.standard.string(forKey: lastVersionKey) ?? ""
    }

    private static var lastPromptDate: Date? {
        let interval = UserDefaults.standard.double(forKey: lastDateKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func markPresented(source: String) {
        UserDefaults.standard.set(currentVersion, forKey: lastVersionKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastDateKey)
        UserDefaults.standard.set(source, forKey: lastSourceKey)
    }

    /// L’ancien prompt onboarding a déjà consommé un slot. On attend 14 jours,
    /// puis un vrai win peut redemander — sans bloquer toute la version en cours.
    private static func migrateLegacyOnboardingPromptIfNeeded() {
        guard UserDefaults.standard.bool(forKey: legacyOnboardingKey) else { return }
        guard lastPromptDate == nil else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastDateKey)
        UserDefaults.standard.set("onboarding_face_scan_results", forKey: lastSourceKey)
    }

    private static func hasImprovedDailyScan() -> Bool {
        let history = FaceScanHistoryStore.shared.history
            .sorted { $0.createdAt > $1.createdAt }
        guard history.count >= minimumScanCount else { return false }
        let latest = history[0]
        guard latest.source == .daily else { return false }
        let previous = history[1]
        return latest.displayWellnessScore >= previous.displayWellnessScore + minimumScoreLift
    }
}

// MARK: - Listener (app principale uniquement)

private struct ProcessAppStoreReviewPromptsModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var historyStore = FaceScanHistoryStore.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: streakStore.snapshot.currentStreak) { oldValue, newValue in
                guard newValue >= 7, oldValue < 7 else { return }
                ProcessAppStoreReviewPrompt.consider(.streak7, requestReview: requestReview)
            }
            .onChange(of: historyStore.latestResult?.id) { _, _ in
                ProcessAppStoreReviewPrompt.consider(.improvedScan, requestReview: requestReview)
            }
    }
}

extension View {
    func processAppStoreReviewPrompts() -> some View {
        modifier(ProcessAppStoreReviewPromptsModifier())
    }
}
