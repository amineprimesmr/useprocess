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
            title: "Ouvrir",
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
        content.subtitle = "Process Intelligence"
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
        content.subtitle = "Process Intelligence"
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
                body: "Ta réponse est prête — ouvre le coach pour la lire."
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
            return "Analyse prête"
        case .guardian:
            return "Réponse Guardian"
        case .directCoach:
            return "Réponse du coach"
        case .warmGuide:
            return "Process t'a répondu"
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
                let prompt = userInfo["prompt"] as? String ?? "Fais mon check-in du jour."
                CoachPlanNavigationBridge.shared.openCoachWithCheckIn(prompt: prompt)
            case "daily_outlook":
                CoachPlanNavigationBridge.shared.openCoachWithCheckIn(
                    prompt: "Donne-moi mon brief matin : readiness, jour protocole et 1 action prioritaire."
                )
            case "daily_review":
                CoachPlanNavigationBridge.shared.openCoachWithCheckIn(
                    prompt: "Fais mon bilan du jour : journal, streak et ce qu'il reste à faire."
                )
            default:
                break
            }
        }
    }
}
