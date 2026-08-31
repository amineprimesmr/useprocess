import MessageUI
import SwiftUI
import UIKit

enum ProcessReferralShareDestination {
    case copyLink
    case messages
    case whatsApp
    case instagram
    case tikTok
}

@MainActor
enum ProcessReferralShareRouter {

    /// `true` → présenter le composeur iMessage in-app.
    static func handle(
        _ destination: ProcessReferralShareDestination,
        message: String,
        link: String
    ) -> Bool {
        switch destination {
        case .copyLink:
            UIPasteboard.general.string = link
            successFeedback()
            return false

        case .messages:
            return openMessages(message: message)

        case .whatsApp:
            openWhatsApp(message: message)
            return false

        case .instagram:
            openInstagram(message: message)
            return false

        case .tikTok:
            openTikTok(message: message, link: link)
            return false
        }
    }

    static var canPresentMessageComposer: Bool {
        MFMessageComposeViewController.canSendText()
    }

    @discardableResult
    private static func openMessages(message: String) -> Bool {
        if MFMessageComposeViewController.canSendText() {
            return true
        }
        guard let encoded = percentEncoded(message) else { return false }
        openURLs([
            "sms:&body=\(encoded)",
            "sms://?&body=\(encoded)"
        ]) { opened in
            if opened { successFeedback() }
        }
        return false
    }

    private static func openWhatsApp(message: String) {
        guard let encoded = percentEncoded(message) else { return }
        openURLs([
            "whatsapp://send?text=\(encoded)",
            "https://wa.me/?text=\(encoded)"
        ]) { opened in
            if opened { successFeedback() }
        }
    }

    private static func openInstagram(message: String) {
        UIPasteboard.general.string = message
        guard let encoded = percentEncoded(message) else { return }
        openURLs([
            "instagram://sharesheet?text=\(encoded)",
            "instagram://app",
            "https://www.instagram.com/direct/inbox/"
        ]) { opened in
            if opened { successFeedback() }
        }
    }

    private static func openTikTok(message: String, link: String) {
        UIPasteboard.general.string = message
        guard let encodedMessage = percentEncoded(message),
              let encodedLink = percentEncoded(link) else { return }
        openURLs([
            "snssdk1233://share?text=\(encodedMessage)",
            "tiktok://share?text=\(encodedMessage)",
            "tiktok://",
            "https://www.tiktok.com/share?url=\(encodedLink)"
        ]) { opened in
            if opened { successFeedback() }
        }
    }

    private static func openURLs(
        _ candidates: [String],
        completion: @escaping (Bool) -> Void
    ) {
        tryOpen(candidates, index: 0, completion: completion)
    }

    private static func tryOpen(
        _ candidates: [String],
        index: Int,
        completion: @escaping (Bool) -> Void
    ) {
        guard index < candidates.count else {
            completion(false)
            return
        }
        guard let url = URL(string: candidates[index]) else {
            tryOpen(candidates, index: index + 1, completion: completion)
            return
        }

        UIApplication.shared.open(url, options: [:]) { success in
            Task { @MainActor in
                if success {
                    completion(true)
                } else {
                    tryOpen(candidates, index: index + 1, completion: completion)
                }
            }
        }
    }

    private static func percentEncoded(_ value: String) -> String? {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }

    private static func successFeedback() {
        HapticManager.shared.notification(.success)
        ProcessSoundPlayer.playSettingsChange()
    }
}

