import Foundation
import PostHog

/// Product analytics facade (PostHog). No-ops safely when the API key is missing.
@MainActor
enum ProcessAnalytics {
    private static var didConfigure = false
    private static var didTrackOnboardingStarted = false
    private static var lastOnboardingStepName: String?

    // MARK: - Lifecycle

    static func configure() {
        guard !didConfigure else { return }
        guard PostHogConfiguration.isConfigured,
              let token = PostHogConfiguration.projectToken else {
            #if DEBUG
            print("[ProcessAnalytics] PostHog not configured — add Analytics/PostHogSecrets.plist")
            #endif
            return
        }

        let config = PostHogConfig(projectToken: token, host: PostHogConfiguration.host)
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        config.personProfiles = .identifiedOnly

        // Autocapture taps (helps see where people click without wiring every button).
        config.captureElementInteractions = true

        // Session replay for SwiftUI requires screenshotMode. Images/text stay masked.
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = true
        config.sessionReplayConfig.screenshotMode = true

        #if DEBUG
        config.debug = true
        #endif

        PostHogSDK.shared.setup(config)
        didConfigure = true

        capture("analytics_ready", properties: [
            "host": PostHogConfiguration.host
        ])
    }

    static var isReady: Bool { didConfigure && PostHogConfiguration.isConfigured }

    // MARK: - Identity

    static func identify(userId: String?, properties: [String: Any] = [:]) {
        guard isReady, let userId, !userId.isEmpty else { return }
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    static func reset() {
        guard isReady else { return }
        PostHogSDK.shared.reset()
        didTrackOnboardingStarted = false
        lastOnboardingStepName = nil
    }

    // MARK: - Core capture

    static func capture(_ event: String, properties: [String: Any] = [:]) {
        guard isReady else { return }
        var props = properties
        props["app"] = "process"
        PostHogSDK.shared.capture(event, properties: props)
    }

    static func screen(_ name: String, properties: [String: Any] = [:]) {
        guard isReady else { return }
        PostHogSDK.shared.screen(name, properties: properties)
    }

    // MARK: - App

    static func trackAppOpened(hasCompletedOnboarding: Bool) {
        capture("app_opened", properties: [
            "has_completed_onboarding": hasCompletedOnboarding
        ])
    }

    // MARK: - Onboarding funnel

    static func trackOnboardingStarted(step: OnboardingStep?) {
        guard !didTrackOnboardingStarted else { return }
        didTrackOnboardingStarted = true
        capture("onboarding_started", properties: stepProperties(step))
    }

    static func trackOnboardingStep(step: OnboardingStep?) {
        guard let step else { return }
        let name = step.analyticsName
        guard name != lastOnboardingStepName else { return }
        lastOnboardingStepName = name

        if !didTrackOnboardingStarted {
            trackOnboardingStarted(step: step)
        }

        capture("onboarding_step_viewed", properties: stepProperties(step))
        screen("onboarding_\(name)")
    }

    static func trackOnboardingCompleted() {
        var props: [String: Any] = [:]
        if let lastOnboardingStepName { props["last_step"] = lastOnboardingStepName }
        capture("onboarding_completed", properties: props)
    }

    static func trackOnboardingFailed(error: String) {
        var props: [String: Any] = ["error": error]
        if let lastOnboardingStepName { props["last_step"] = lastOnboardingStepName }
        capture("onboarding_failed", properties: props)
    }

    // MARK: - Paywall

    static func trackPaywallViewed(source: String = "unknown") {
        capture("paywall_viewed", properties: ["source": source])
        screen("paywall")
    }

    static func trackPurchaseStarted(plan: String) {
        capture("purchase_started", properties: ["plan": plan])
    }

    static func trackPurchaseCompleted(plan: String) {
        capture("purchase_completed", properties: ["plan": plan])
    }

    static func trackPurchaseCancelled(plan: String) {
        capture("purchase_cancelled", properties: ["plan": plan])
    }

    static func trackPurchaseFailed(plan: String, error: String) {
        capture("purchase_failed", properties: [
            "plan": plan,
            "error": error
        ])
    }

    static func trackRestoreCompleted(isActive: Bool) {
        capture("restore_completed", properties: ["is_active": isActive])
    }

    // MARK: - Product

    static func trackFaceScanCompleted(source: String) {
        capture("face_scan_completed", properties: ["source": source])
    }

    // MARK: - Helpers

    private static func stepProperties(_ step: OnboardingStep?) -> [String: Any] {
        guard let step else { return [:] }
        return [
            "step": step.analyticsName,
            "step_raw": step.rawValue,
            "step_index": step.semanticOrderIndex
        ]
    }
}

extension OnboardingStep {
    var analyticsName: String {
        String(describing: self)
    }
}
