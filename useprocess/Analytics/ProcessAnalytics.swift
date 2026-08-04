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
        config.captureElementInteractions = true
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

    static func capture(
        _ event: String,
        properties: [String: Any] = [:],
        userProperties: [String: Any]? = nil
    ) {
        guard isReady else { return }
        var props = properties
        props["app"] = "process"
        if let userProperties, !userProperties.isEmpty {
            PostHogSDK.shared.capture(event, properties: props, userProperties: userProperties)
        } else {
            PostHogSDK.shared.capture(event, properties: props)
        }
    }

    static func setPersonProperties(_ properties: [String: Any]) {
        guard isReady, !properties.isEmpty else { return }
        PostHogSDK.shared.capture(
            "$set",
            properties: ["app": "process"],
            userProperties: properties
        )
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

    /// Expose last step name for richer completion payloads.
    static var currentOnboardingStepName: String? { lastOnboardingStepName }

    static func trackOnboardingFailed(error: String) {
        var props: [String: Any] = ["error": error]
        if let lastOnboardingStepName { props["last_step"] = lastOnboardingStepName }
        capture("onboarding_failed", properties: props)
    }

    // MARK: - Main paywall

    static func trackPaywallViewed(source: String = "unknown") {
        capture("paywall_viewed", properties: ["source": source])
        screen("paywall")
    }

    static func trackPaywallPlanSelected(plan: String, source: String = "paywall") {
        capture("paywall_plan_selected", properties: [
            "plan": plan,
            "source": source
        ])
    }

    static func trackPaywallCloseTapped(source: String = "paywall") {
        capture("paywall_close_tapped", properties: ["source": source])
    }

    static func trackPaywallStayPopupShown(trigger: String = "home_swipe") {
        capture("paywall_stay_popup_shown", properties: ["trigger": trigger])
    }

    static func trackPaywallStayPopupAction(_ action: String) {
        capture("paywall_stay_popup_action", properties: ["action": action])
    }

    static func trackPaywallCTATapped(plan: String, source: String = "paywall") {
        capture("paywall_cta_tapped", properties: [
            "plan": plan,
            "source": source
        ])
    }

    // MARK: - Spin / winback funnel (lifetime 19 €)

    static func trackSpinWheelViewed(source: String = "paywall_cancel_or_exit") {
        capture("spin_wheel_viewed", properties: [
            "source": source,
            "offer_price": SubscriptionConfiguration.winbackLifetimePrice,
            "compare_at": SubscriptionConfiguration.winbackCompareAtPrice,
            "offer_id": SubscriptionConfiguration.winbackOfferID
        ])
        screen("spin_wheel")
    }

    static func trackSpinStarted(attempt: Int) {
        capture("spin_started", properties: [
            "attempt": attempt,
            "is_first": attempt == 1
        ])
    }

    static func trackSpinFinished(attempt: Int, result: String) {
        // result: lost_5_percent | won_jackpot
        capture("spin_finished", properties: [
            "attempt": attempt,
            "result": result,
            "is_first": attempt == 1
        ])
    }

    static func trackSpinAgainSheetShown() {
        capture("spin_again_sheet_shown")
    }

    static func trackSpinAgainTapped() {
        capture("spin_again_tapped")
    }

    static func trackSpinWinRevealShown(jackpotTitle: String) {
        capture("spin_win_reveal_shown", properties: [
            "jackpot_title": jackpotTitle,
            "offer_price": SubscriptionConfiguration.winbackLifetimePrice
        ])
    }

    static func trackSpinOfferShown(source: String = "spin_wheel") {
        capture("spin_offer_shown", properties: [
            "source": source,
            "plan": "winback_lifetime",
            "offer_price": SubscriptionConfiguration.winbackLifetimePrice,
            "compare_at": SubscriptionConfiguration.winbackCompareAtPrice,
            "offer_id": SubscriptionConfiguration.winbackOfferID,
            "jackpot_title": SubscriptionConfiguration.winbackJackpotTitle
        ])
        screen("spin_offer_19")
    }

    static func trackSpinOfferCTATapped(source: String = "spin_wheel") {
        capture("spin_offer_cta_tapped", properties: [
            "source": source,
            "plan": "winback_lifetime",
            "offer_price": SubscriptionConfiguration.winbackLifetimePrice
        ])
    }

    // MARK: - Purchases

    static func trackPurchaseStarted(
        plan: String,
        offer: String? = nil,
        source: String? = nil
    ) {
        var props: [String: Any] = ["plan": plan]
        if let offer { props["offer"] = offer }
        if let source { props["source"] = source }
        capture("purchase_started", properties: props)
    }

    static func trackPurchaseCompleted(
        plan: String,
        offer: String? = nil,
        source: String? = nil
    ) {
        var props: [String: Any] = ["plan": plan]
        if let offer { props["offer"] = offer }
        if let source { props["source"] = source }
        capture("purchase_completed", properties: props)
    }

    static func trackPurchaseCancelled(
        plan: String,
        offer: String? = nil,
        source: String? = nil
    ) {
        var props: [String: Any] = ["plan": plan]
        if let offer { props["offer"] = offer }
        if let source { props["source"] = source }
        capture("purchase_cancelled", properties: props)
    }

    static func trackPurchaseFailed(
        plan: String,
        error: String,
        offer: String? = nil,
        source: String? = nil
    ) {
        var props: [String: Any] = [
            "plan": plan,
            "error": error
        ]
        if let offer { props["offer"] = offer }
        if let source { props["source"] = source }
        capture("purchase_failed", properties: props)
    }

    static func trackRestoreCompleted(isActive: Bool) {
        capture("restore_completed", properties: ["is_active": isActive])
    }

    static func trackQuickActionOpened(kind: String) {
        capture("quick_action_opened", properties: ["kind": kind])
    }

    static func trackTrialRetentionDismissed(source: String) {
        capture("trial_retention_dismissed", properties: ["source": source])
    }

    // MARK: - Product

    static func trackFaceScanCompleted(source: String) {
        capture("face_scan_completed", properties: ["source": source])
    }

    static func trackMealScanCompleted(slot: String, optimized: Bool) {
        capture("meal_scan_completed", properties: [
            "slot": slot,
            "optimized": optimized
        ])
    }

    static func trackMealScanFailed(error: String) {
        capture("meal_scan_failed", properties: ["error": error])
    }

    static func trackHydrationLogged(milliliters: Int, totalMilliliters: Int) {
        capture("hydration_logged", properties: [
            "milliliters": milliliters,
            "total_milliliters": totalMilliliters
        ])
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
