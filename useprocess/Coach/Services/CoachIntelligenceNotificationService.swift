import Foundation
import UserNotifications

/// Notifications style Bevel Intelligence quand une réponse coach est prête.
@MainActor
enum CoachIntelligenceNotificationService {
    static let categoryID = "PROCESS_COACH_REPLY"
    static let threadID = "process.coach.intelligence"

    private static var didConfigure = false

    static func configure() {
        guard !didConfigure else { return }
        didConfigure = true

        UNUserNotificationCenter.current().delegate = CoachNotificationCenterDelegate.shared

        let open = UNNotificationAction(
            identifier: "OPEN_COACH",
            title: AppCopy.t("Ouvrir", en: "Open"),
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [open],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func notifyReplyReady(
        conversationId: UUID,
        replyText: String,
        conversationTitle: String?
    ) async {
        configure()

        guard CoachIntelligenceSettingsStore.shared.isEnabled else { return }
        guard !CoachPresentationTracker.shared.shouldSuppressReplyNotification(for: conversationId) else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let formatted = formatBevelStyleContent(from: replyText, conversationTitle: conversationTitle)

        let content = UNMutableNotificationContent()
        content.title = formatted.title
        content.body = formatted.body
        content.sound = .default
        content.threadIdentifier = threadID
        content.categoryIdentifier = categoryID
        content.interruptionLevel = .active
        content.relevanceScore = 0.9
        content.userInfo = [
            "kind": "coach_reply",
            "conversationId": conversationId.uuidString
        ]

        let identifier = "process.coach.reply.\(conversationId.uuidString).\(Int(Date().timeIntervalSince1970))"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.15, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try? await center.add(request)
    }

    static func notifyCustom(title: String, body: String, kind: String) async {
        configure()

        guard CoachIntelligenceSettingsStore.shared.isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = threadID
        content.categoryIdentifier = categoryID
        content.userInfo = ["kind": kind]

        let identifier = "process.coach.custom.\(kind).\(Int(Date().timeIntervalSince1970))"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.15, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Bevel-style copy

    struct FormattedNotification {
        let title: String
        let body: String
    }

    static func formatBevelStyleContent(from text: String, conversationTitle: String?) -> FormattedNotification {
        let cleaned = stripMarkdown(text)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return FormattedNotification(
                title: headlineFallback(conversationTitle: conversationTitle),
                body: AppCopy.t("Ta réponse est prête — ouvre le coach pour la lire.", en: "Your response is ready — open the coach to read it.")
            )
        }

        let sentences = splitSentences(cleaned)
        let first = sentences.first ?? cleaned

        if first.count <= 46, sentences.count > 1 {
            let bodySource = sentences.dropFirst().joined(separator: ". ").trimmingCharacters(in: .whitespacesAndNewlines)
            return FormattedNotification(
                title: first,
                body: truncate(bodySource.isEmpty ? cleaned : bodySource, limit: 178)
            )
        }

        if first.count <= 46 {
            return FormattedNotification(
                title: first,
                body: truncate(cleaned, limit: 178)
            )
        }

        return FormattedNotification(
            title: headlineFallback(conversationTitle: conversationTitle),
            body: truncate(cleaned, limit: 178)
        )
    }

    private static func headlineFallback(conversationTitle: String?) -> String {
        if let title = conversationTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return OriginPlanPresenter.truncate(title, max: 46)
        }

        switch CoachIntelligenceSettingsStore.shared.personality {
        case .dataNerd:
            return AppCopy.t("Analyse prête", en: "Analysis ready")
        case .guardian:
            return AppCopy.t("Réponse Guardian", en: "Guardian response")
        case .directCoach:
            return AppCopy.t("Réponse du coach", en: "Coach response")
        case .warmGuide:
            return AppCopy.t("Ton coach t'a répondu", en: "Your coach replied")
        }
    }

    private static func splitSentences(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ".!?…"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let end = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func stripMarkdown(_ text: String) -> String {
        var result = text
        let patterns = [
            #"\*\*([^*]+)\*\*"#,
            #"\*([^*]+)\*"#,
            #"__([^_]+)__"#,
            #"_([^_]+)_"#,
            #"`([^`]+)`"#,
            #"^#+\s*"#,
            #"^[-*]\s+"#
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: "$1",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }
}

// MARK: - Delegate

final class CoachNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CoachNotificationCenterDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let kind = notification.request.content.userInfo["kind"] as? String ?? ""

        if kind == "coach_reply" {
            if let idString = notification.request.content.userInfo["conversationId"] as? String,
               let id = UUID(uuidString: idString),
               CoachPresentationTracker.shared.shouldSuppressReplyNotification(for: id) {
                completionHandler([])
                return
            }
            completionHandler([.banner, .sound, .list])
            return
        }

        if kind == "coach_checkin" || kind == "daily_outlook" || kind == "daily_review" {
            if CoachPresentationTracker.shared.isCoachPresented {
                completionHandler([])
                return
            }
        }

        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        let kind = userInfo["kind"] as? String ?? ""

        Task { @MainActor in
            switch kind {
            case "coach_reply":
                let conversationId = (userInfo["conversationId"] as? String).flatMap(UUID.init(uuidString:))
                CoachPlanNavigationBridge.shared.openCoach(conversationId: conversationId)
            case "coach_checkin":
                let prompt = userInfo["prompt"] as? String ?? AppCopy.t("Fais mon check-in du jour.", en: "Run my daily check-in.")
                CoachPlanNavigationBridge.shared.openCoachWithCheckIn(prompt: prompt)
            case "daily_outlook":
                CoachPlanNavigationBridge.shared.openCoachWithCheckIn(
                    prompt: AppCopy.t("Donne-moi mon brief matin : sommeil, jour du plan personnalisé et 1 action prioritaire.", en: "Give me my morning brief: sleep, personalized plan day, and one priority action.")
                )
            case "daily_review":
                CoachPlanNavigationBridge.shared.openEveningCheckIn()
            default:
                if kind.hasPrefix("marketing_") {
                    handleMarketingNotificationTap(kind: kind, userInfo: userInfo)
                }
            }
        }
    }

    @MainActor
    private func handleMarketingNotificationTap(kind: String, userInfo: [AnyHashable: Any]) {
        let campaignId = (userInfo["campaign_id"] as? String)
            ?? kind.replacingOccurrences(of: "marketing_", with: "")

        let resolvedKind = ProcessMarketingNotificationKind(rawValue: campaignId)
        let opensSpin = (userInfo["opens_spin_wheel"] as? Bool)
            ?? (userInfo["opens_spin_wheel"] as? NSNumber)?.boolValue
            ?? resolvedKind?.opensSpinWheel
            ?? false
        let opensLifetime = (userInfo["opens_lifetime_offer"] as? Bool)
            ?? (userInfo["opens_lifetime_offer"] as? NSNumber)?.boolValue
            ?? resolvedKind?.opensLifetimeOffer
            ?? (!opensSpin)

        ProcessMarketingNotificationService.shared.markOpened(campaignId: campaignId)
        ProcessAnalytics.trackMarketingNotificationOpened(
            campaignId: campaignId,
            opensLifetimeOffer: opensLifetime && !opensSpin,
            opensSpinWheel: opensSpin
        )

        if opensSpin {
            AppLaunchRouter.shared.presentSpinWheelFromMarketing(campaignId: campaignId)
        } else if opensLifetime {
            AppLaunchRouter.shared.presentLifetimeOfferFromMarketing(campaignId: campaignId)
        }
    }
}
