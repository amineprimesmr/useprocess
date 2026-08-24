import Foundation
import PostHog

/// Product analytics facade (PostHog). No-ops safely when the API key is missing.
@MainActor
enum ProcessAnalytics {
    private static var didConfigure = false
    private static var didTrackOnboardingStarted = false
    private static var lastOnboardingStepName: String?
    private static var lastTrackedFirstName: String?
    /// Dedupe consecutive Moss sub-page views (chat / scan / program creation).
    static var lastMossPageName: String?
    /// Dedupe du parcours réel (`onboarding_funnel_step`).
    static var lastFunnelScreenID: String?

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
        ProcessAcquisitionAttribution.bootstrap()
    }

    static var isReady: Bool { didConfigure && PostHogConfiguration.isConfigured }

    // MARK: - Identity

    static func identify(userId: String?, properties: [String: Any] = [:]) {
        guard isReady, let userId, !userId.isEmpty else { return }
        var props = properties
        // Attache le prénom au person profile dès l'identify (différencier les users dans PostHog).
        if props["first_name"] == nil,
           let name = resolvedFirstName(from: UnifiedProfileService.shared.currentProfile?.firstName) {
            props["first_name"] = name
            props["name"] = name
            registerFirstNameSuperProperties(name)
        }
        for (key, value) in ProcessAcquisitionAttribution.analyticsProperties() {
            if props[key] == nil { props[key] = value }
        }
        PostHogSDK.shared.identify(userId, userProperties: props.isEmpty ? nil : props)
        ProcessAcquisitionAttribution.syncToAnalytics(emitResolvedEvent: false)
    }

    static func reset() {
        guard isReady else { return }
        PostHogSDK.shared.unregister("first_name")
        PostHogSDK.shared.unregister("name")
        PostHogSDK.shared.reset()
        didTrackOnboardingStarted = false
        lastOnboardingStepName = nil
        lastTrackedFirstName = nil
        lastMossPageName = nil
        lastFunnelScreenID = nil
    }

    /// Enregistre le prénom pour différencier les users (event + person + super properties).
    static func trackFirstNameSet(_ raw: String, source: String = "unknown") {
        applyFirstName(raw, source: source, emitEvent: true)
    }

    /// Resync prénom depuis le profil local (app open / login) — sans nouvel event.
    static func syncFirstNameFromProfile() {
        applyFirstName(
            UnifiedProfileService.shared.currentProfile?.firstName,
            source: "profile_sync",
            emitEvent: false
        )
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
        // Fallback si les super-properties n’ont pas encore été register — pas de double surcharge lourde.
        if props["acquisition_source"] == nil {
            for (key, value) in ProcessAcquisitionAttribution.analyticsProperties(includeLastTouch: false) {
                if props[key] == nil { props[key] = value }
            }
        }
        if let userProperties, !userProperties.isEmpty {
            PostHogSDK.shared.capture(event, properties: props, userProperties: userProperties)
        } else {
            PostHogSDK.shared.capture(event, properties: props)
        }
    }

    static func registerAcquisitionSuperProperties(_ properties: [String: Any]) {
        guard isReady, !properties.isEmpty else { return }
        var supers: [String: Any] = [:]
        for (key, value) in properties {
            // Évite d’enregistrer des payloads trop larges en super-props.
            if key.hasPrefix("acquisition_") || key.hasPrefix("asa_") || key == "referral_code" || key == "has_referral_code" {
                supers[key] = value
            }
        }
        guard !supers.isEmpty else { return }
        PostHogSDK.shared.register(supers)
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
        var props: [String: Any] = [
            "has_completed_onboarding": hasCompletedOnboarding,
            "app_language": ProcessAppLanguage.shared.code.rawValue
        ]
        for (key, value) in ProcessAcquisitionAttribution.analyticsProperties() {
            props[key] = value
        }
        capture("app_opened", properties: props)
        var person: [String: Any] = [
            "app_language": ProcessAppLanguage.shared.code.rawValue,
            "has_completed_onboarding": hasCompletedOnboarding
        ]
        for (key, value) in ProcessAcquisitionAttribution.analyticsProperties() {
            person[key] = value
        }
        setPersonProperties(person)
        Task {
            await PermissionsManager.shared.refreshNotificationAuthorizationStatus()
        }
        Task {
            await ProcessAcquisitionAttribution.resolveAppleSearchAdsIfNeeded()
        }
    }

    static func trackAppUpdatePromptShown(from current: String, to available: String, forced: Bool) {
        capture("app_update_prompt_shown", properties: [
            "current_version": current,
            "available_version": available,
            "forced": forced
        ])
    }

    static func trackAppUpdateTapped(from current: String, to available: String, forced: Bool) {
        capture("app_update_tapped", properties: [
            "current_version": current,
            "available_version": available,
            "forced": forced
        ])
    }

    static func trackAppUpdateDismissed(from current: String, to available: String) {
        capture("app_update_dismissed", properties: [
            "current_version": current,
            "available_version": available
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
        // Les étapes transitoires (HealthKit, notifs…) sautent trop vite et
        // polluent le funnel avec un ordre faux.
        if step.isTransientSkippedStep { return }
        // Le chat n’est pas un écran unique : chaque question part via Moss.
        if step == .weightMotivation { return }

        let name = step.analyticsName
        if name != lastOnboardingStepName {
            lastOnboardingStepName = name

            if !didTrackOnboardingStarted {
                trackOnboardingStarted(step: step)
            }

            capture("onboarding_step_viewed", properties: stepProperties(step))
            screen("onboarding_\(name)")
        }

        if let funnelScreen = OnboardingFunnelScreen.from(step: step) {
            trackFunnelScreen(funnelScreen)
        }
    }

    /// Écran du parcours réel — une ligne PostHog = un écran utilisateur.
    static func trackFunnelScreen(
        _ funnelScreen: OnboardingFunnelScreen,
        extra: [String: Any] = [:]
    ) {
        guard funnelScreen.id != lastFunnelScreenID else { return }
        lastFunnelScreenID = funnelScreen.id

        var props: [String: Any] = [
            "screen": funnelScreen.id,
            "screen_label": funnelScreen.labelEN,
            "screen_label_fr": funnelScreen.labelFR,
            "funnel_index": funnelScreen.funnelIndex,
            "funnel_phase": funnelScreen.phase,
            "funnel_version": 2
        ]
        for (key, value) in extra {
            props[key] = value
        }
        capture("onboarding_funnel_step", properties: props)
        screen("funnel_\(funnelScreen.id)")
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

    private static func withPricingVariant(_ properties: [String: Any]) -> [String: Any] {
        var props = properties
        for (key, value) in PaywallPricingExperiment.shared.analyticsProperties {
            props[key] = value
        }
        for (key, value) in SubscriptionMarketPolicy.analyticsProperties {
            props[key] = value
        }
        return props
    }

    private static func withAcquisition(_ properties: [String: Any]) -> [String: Any] {
        var props = properties
        for (key, value) in ProcessAcquisitionAttribution.analyticsProperties() {
            props[key] = value
        }
        return props
    }

    static func trackPaywallViewed(source: String = "unknown") {
        capture("paywall_viewed", properties: withPricingVariant(["source": source]))
        screen("paywall")
        trackFunnelScreen(.paywall, extra: ["source": source])
    }

    static func trackPaywallPlanSelected(plan: String, source: String = "paywall") {
        capture("paywall_plan_selected", properties: withPricingVariant([
            "plan": plan,
            "source": source
        ]))
    }

    static func trackPaywallCloseTapped(source: String = "paywall") {
        capture("paywall_close_tapped", properties: withPricingVariant(["source": source]))
    }

    static func trackPaywallStayPopupShown(trigger: String = "home_swipe") {
        capture("paywall_stay_popup_shown", properties: withPricingVariant(["trigger": trigger]))
    }

    static func trackPaywallStayPopupAction(_ action: String) {
        capture("paywall_stay_popup_action", properties: withPricingVariant(["action": action]))
    }

    static func trackPaywallCTATapped(plan: String, source: String = "paywall") {
        capture("paywall_cta_tapped", properties: withPricingVariant([
            "plan": plan,
            "source": source
        ]))
    }

    // MARK: - Spin / winback funnel (lifetime)

    private static var spinWinbackPricingProperties: [String: Any] {
        [
            "offer_price": SubscriptionService.shared.winbackLifetimeDisplayPrice,
            "compare_at": SubscriptionService.shared.winbackCompareAtDisplayPrice,
            "offer_id": SubscriptionConfiguration.winbackOfferID
        ]
    }

    static func trackSpinWheelViewed(source: String = "paywall_cancel_or_exit") {
        capture("spin_wheel_viewed", properties: spinWinbackPricingProperties.merging(["source": source]) { _, new in new })
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
            "offer_price": SubscriptionService.shared.winbackLifetimeDisplayPrice
        ])
    }

    static func trackSpinOfferShown(source: String = "spin_wheel") {
        capture("spin_offer_shown", properties: spinWinbackPricingProperties.merging([
            "source": source,
            "plan": "winback_lifetime",
            "jackpot_title": SubscriptionConfiguration.winbackJackpotTitle
        ]) { _, new in new })
        screen("spin_offer_19")
    }

    static func trackSpinOfferCTATapped(source: String = "spin_wheel") {
        capture("spin_offer_cta_tapped", properties: [
            "source": source,
            "plan": "winback_lifetime",
            "offer_price": SubscriptionService.shared.winbackLifetimeDisplayPrice
        ])
    }

    // MARK: - HealthKit / Apple Health

    /// In-app prompt (popup onboarding, écran permission, settings…).
    static func trackHealthKitPromptShown(source: String) {
        capture("healthkit_prompt_shown", properties: ["source": source])
    }

    /// User completed the system sheet successfully (app treats Health as connected).
    static func trackHealthKitAuthorized(source: String, systemPromptShown: Bool? = nil) {
        var props: [String: Any] = ["source": source, "result": "authorized"]
        if let systemPromptShown {
            props["system_prompt_shown"] = systemPromptShown
        }
        capture("healthkit_authorized", properties: props)
        setPersonProperties(["healthkit_authorized": true])
    }

    /// Request failed, unavailable, or user denied (when detectable).
    static func trackHealthKitDenied(source: String, reason: String = "denied_or_failed") {
        capture("healthkit_denied", properties: [
            "source": source,
            "result": "denied",
            "reason": reason
        ])
        setPersonProperties(["healthkit_authorized": false])
    }

    /// User tapped “Plus tard” / skipped without opening the system sheet.
    static func trackHealthKitSkipped(source: String) {
        capture("healthkit_skipped", properties: [
            "source": source,
            "result": "skipped"
        ])
    }

    // MARK: - Notifications

    static func trackNotificationsPromptShown(source: String) {
        capture("notifications_prompt_shown", properties: ["source": source])
    }

    static func trackNotificationsAuthorized(source: String, status: String = "authorized") {
        capture("notifications_authorized", properties: [
            "source": source,
            "result": "authorized",
            "status": status
        ])
        setPersonProperties([
            "notifications_authorized": true,
            "notifications_status": status
        ])
    }

    static func trackNotificationsDenied(source: String, status: String = "denied") {
        capture("notifications_denied", properties: [
            "source": source,
            "result": "denied",
            "status": status
        ])
        setPersonProperties([
            "notifications_authorized": false,
            "notifications_status": status
        ])
    }

    static func trackNotificationsSkipped(source: String) {
        capture("notifications_skipped", properties: [
            "source": source,
            "result": "skipped"
        ])
    }

    /// Sync person props when we refresh status without a new prompt.
    static func syncNotificationsStatus(_ status: String, authorized: Bool) {
        setPersonProperties([
            "notifications_authorized": authorized,
            "notifications_status": status
        ])
    }

    // MARK: - App Store review

    /// Apple does not tell us if the user actually left a rating — only that we prompted.
    static func trackAppStoreReviewPrompted(source: String) {
        capture("app_store_review_prompted", properties: ["source": source])
        setPersonProperties(["app_store_review_prompted": true])
    }

    // MARK: - Camera

    static func trackCameraAuthorized(source: String) {
        capture("camera_authorized", properties: [
            "source": source,
            "result": "authorized"
        ])
        setPersonProperties(["camera_authorized": true])
    }

    static func trackCameraDenied(source: String) {
        capture("camera_denied", properties: [
            "source": source,
            "result": "denied"
        ])
        setPersonProperties(["camera_authorized": false])
    }

    // MARK: - Commitment (biometric hold step)

    static func trackCommitmentShown(source: String = "onboarding") {
        capture("commitment_shown", properties: ["source": source])
    }

    static func trackCommitmentCompleted(source: String = "onboarding") {
        capture("commitment_completed", properties: ["source": source])
        setPersonProperties(["commitment_completed": true])
    }

    static func trackCommitmentAbandoned(progress: Double, source: String = "onboarding") {
        capture("commitment_abandoned", properties: [
            "source": source,
            "progress": min(1, max(0, progress))
        ])
    }

    // MARK: - Apple Sign In

    static func trackAppleSignInStarted(source: String = "onboarding_post_payment") {
        capture("apple_sign_in_started", properties: ["source": source])
    }

    static func trackAppleSignInCompleted(source: String = "onboarding_post_payment") {
        capture("apple_sign_in_completed", properties: [
            "source": source,
            "result": "success"
        ])
        setPersonProperties(["apple_sign_in": true])
    }

    static func trackAppleSignInFailed(source: String = "onboarding_post_payment", error: String) {
        capture("apple_sign_in_failed", properties: [
            "source": source,
            "result": "failed",
            "error": String(error.prefix(180))
        ])
    }

    static func trackAppleSignInSkipped(source: String = "onboarding_post_payment") {
        capture("apple_sign_in_skipped", properties: [
            "source": source,
            "result": "skipped"
        ])
    }

    // MARK: - Referral / share

    static func trackSupportChatOpened(source: String) {
        capture("support_chat_opened", properties: ["source": source])
        setPersonProperties(["has_opened_support_chat": true])
    }

    static func trackSupportMessageSent() {
        capture("support_message_sent")
    }

    static func trackReferralShareOpened(source: String = "referral_program") {
        capture("referral_share_opened", properties: ["source": source])
    }

    static func trackReferralCodeCaptured(source: String = "deep_link") {
        capture("referral_code_captured", properties: withAcquisition(["source": source]))
        setPersonProperties(["has_referral_code": true])
    }

    static func trackReferralCodeApplied(source: String = "onboarding") {
        capture("referral_code_applied", properties: withAcquisition(["source": source]))
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
        capture("purchase_started", properties: withPricingVariant(withAcquisition(props)))
        trackFunnelScreen(.purchaseStarted, extra: props)
    }

    static func trackPurchaseCompleted(
        plan: String,
        offer: String? = nil,
        source: String? = nil
    ) {
        var props: [String: Any] = ["plan": plan]
        if let offer { props["offer"] = offer }
        if let source { props["source"] = source }
        capture("purchase_completed", properties: withPricingVariant(withAcquisition(props)))
        trackFunnelScreen(.purchaseCompleted, extra: props)
    }

    static func trackPurchaseCancelled(
        plan: String,
        offer: String? = nil,
        source: String? = nil
    ) {
        var props: [String: Any] = ["plan": plan]
        if let offer { props["offer"] = offer }
        if let source { props["source"] = source }
        capture("purchase_cancelled", properties: withPricingVariant(withAcquisition(props)))
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
        capture("purchase_failed", properties: withPricingVariant(withAcquisition(props)))
    }

    static func trackRestoreStarted(source: String = "paywall") {
        capture("restore_started", properties: ["source": source])
    }

    static func trackRestoreCompleted(isActive: Bool) {
        capture("restore_completed", properties: ["is_active": isActive])
    }

    static func trackRestoreFailed(error: String, source: String = "paywall") {
        capture("restore_failed", properties: [
            "source": source,
            "error": String(error.prefix(180))
        ])
    }

    static func trackQuickActionOpened(kind: String) {
        capture("quick_action_opened", properties: ["kind": kind])
    }

    static func trackTrialRetentionDismissed(source: String) {
        capture("trial_retention_dismissed", properties: ["source": source])
    }

    // MARK: - Marketing notifications (non-payers)

    static func trackMarketingNotificationsScheduled(
        reason: String,
        campaignIds: [String],
        sawSpin: Bool
    ) {
        capture("marketing_notif_scheduled", properties: [
            "reason": reason,
            "campaign_ids": campaignIds.joined(separator: ","),
            "count": campaignIds.count,
            "saw_spin": sawSpin
        ])
    }

    static func trackMarketingNotificationOpened(
        campaignId: String,
        opensLifetimeOffer: Bool,
        opensSpinWheel: Bool = false
    ) {
        capture("marketing_notif_opened", properties: [
            "campaign_id": campaignId,
            "opens_lifetime_offer": opensLifetimeOffer,
            "opens_spin_wheel": opensSpinWheel
        ])
    }

    static func trackMarketingNotificationConverted(campaignId: String?, plan: String) {
        var props: [String: Any] = ["plan": plan]
        if let campaignId { props["campaign_id"] = campaignId }
        capture("marketing_notif_converted", properties: props)
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
        var props: [String: Any] = [
            "step": step.analyticsName,
            "step_raw": step.rawValue,
            "step_index": OnboardingFunnelScreen.from(step: step)?.funnelIndex ?? step.liveOrderIndex,
            "funnel_version": 2
        ]
        if let funnel = OnboardingFunnelScreen.from(step: step) {
            props["screen"] = funnel.id
            props["screen_label_fr"] = funnel.labelFR
            props["funnel_phase"] = funnel.phase
        }
        return props
    }

    private static func resolvedFirstName(from raw: String?) -> String? {
        let name = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard OnboardingViewModel.isRealUserFirstName(name) else { return nil }
        return name
    }

    private static func applyFirstName(
        _ raw: String?,
        source: String,
        emitEvent: Bool
    ) {
        guard let name = resolvedFirstName(from: raw) else { return }

        registerFirstNameSuperProperties(name)
        setPersonProperties([
            "first_name": name,
            "name": name
        ])

        guard emitEvent, lastTrackedFirstName != name else { return }
        lastTrackedFirstName = name
        capture("first_name_set", properties: [
            "first_name": name,
            "first_name_length": name.count,
            "source": source
        ])
    }

    private static func registerFirstNameSuperProperties(_ name: String) {
        guard isReady else { return }
        // Super properties → first_name présent sur tous les events suivants (paywall, purchase…).
        PostHogSDK.shared.register([
            "first_name": name,
            "name": name
        ])
    }
}

extension OnboardingStep {
    var analyticsName: String {
        String(describing: self)
    }
}
