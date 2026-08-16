import Foundation
import UserNotifications

/// Planifie la séquence marketing locale pour les non-payeurs (FOMO lifetime 19€, relances).
@MainActor
final class ProcessMarketingNotificationService {
    static let shared = ProcessMarketingNotificationService()

    private static let campaignAnchorKey = "process.mkt.campaignAnchor"
    private static let sawSpinKey = "process.mkt.sawSpinWheel"
    private static let seriesVersionKey = "process.mkt.seriesVersion"
    private static let pendingOpenCampaignKey = "process.mkt.pendingOpenCampaign"
    private static let exitChaseArmedAtKey = "process.mkt.exitChaseArmedAt"
    private static let exitChaseFiredKey = "process.mkt.exitChaseFired"
    private static let seriesVersion = 2

    /// Max notifs marketing dans les 7 premiers jours.
    private static let maxInFirstWeek = 5
    /// Fenêtre après dropoff paywall pour la chase instantanée.
    private static let exitChaseWindow: TimeInterval = 8 * 60
    /// Délai avant affichage une fois l’app en background.
    private static let exitChaseFireDelay: TimeInterval = 1.2
    /// Heures calmes : pas de fire entre 22:00 et 08:00 (série seulement — pas la chase).
    private static let quietHourStart = 22
    private static let quietHourEnd = 8

    private init() {}

    // MARK: - Public API

    /// Marque que l’utilisateur a vu la roue winback (débloque `spin_again`).
    func markSawSpinWheel() {
        UserDefaults.standard.set(true, forKey: Self.sawSpinKey)
    }

    var hasSawSpinWheel: Bool {
        UserDefaults.standard.bool(forKey: Self.sawSpinKey)
    }

    /// Démarre / rafraîchit la campagne (sortie paywall, cancel achat, app open non-payer).
    func scheduleConversionSeries(reason: String) async {
        guard !SubscriptionService.shared.subscriptionStatus.isActive else {
            cancelAll()
            return
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let defaults = UserDefaults.standard
        let now = Date()
        var anchor = defaults.object(forKey: Self.campaignAnchorKey) as? Date ?? now
        let version = defaults.integer(forKey: Self.seriesVersionKey)

        // Nouvelle ancre si première fois ou maj de série.
        if defaults.object(forKey: Self.campaignAnchorKey) == nil || version != Self.seriesVersion {
            anchor = now
            defaults.set(anchor, forKey: Self.campaignAnchorKey)
            defaults.set(Self.seriesVersion, forKey: Self.seriesVersionKey)
        }

        let candidates = buildCandidates(anchor: anchor, now: now, sawSpin: hasSawSpinWheel)
        let selected = applyCaps(candidates)

        // Ne touche pas à la chase instantanée en vol.
        cancelPendingSeriesRequests()

        var scheduledIDs: [String] = []
        for item in selected {
            guard item.fireDate > now.addingTimeInterval(45) else { continue }
            do {
                try await schedule(item)
                scheduledIDs.append(item.kind.rawValue)
            } catch {
                continue
            }
        }

        if !scheduledIDs.isEmpty {
            ProcessAnalytics.trackMarketingNotificationsScheduled(
                reason: reason,
                campaignIds: scheduledIDs,
                sawSpin: hasSawSpinWheel
            )
        }
    }

    /// Reschedule léger à l’ouverture app (ne reset pas l’ancre).
    func refreshIfNeededOnAppOpen() async {
        guard !SubscriptionService.shared.subscriptionStatus.isActive else {
            cancelAll()
            return
        }
        guard UserDefaults.standard.object(forKey: Self.campaignAnchorKey) != nil else { return }
        await scheduleConversionSeries(reason: "app_open")
    }

    /// Démarre la série après un abandon paywall / cancel + arme la chase instantanée.
    func startAfterPaywallDropoff(sawSpin: Bool, reason: String) async {
        if sawSpin { markSawSpinWheel() }
        // Nouvelle ancre à chaque dropoff paywall significatif.
        UserDefaults.standard.set(Date(), forKey: Self.campaignAnchorKey)
        UserDefaults.standard.set(Self.seriesVersion, forKey: Self.seriesVersionKey)
        armExitChase()
        await prepareNotificationPermissionIfNeeded()
        await scheduleConversionSeries(reason: reason)
    }

    /// L’étape notifs onboarding est sautée — on demande ici (paywall encore au premier plan).
    func prepareNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .notDetermined else { return }
        _ = await PermissionsManager.shared.requestNotificationPermission(analyticsSource: "paywall_dropoff")
        CoachIntelligenceNotificationService.configure()
    }

    func cancelAll() {
        cancelPendingSeriesRequests()
        cancelPendingExitChaseNotification()
        clearExitChase()
        ProcessMarketingHealthPulseService.shared.cancelAll()
        UserDefaults.standard.removeObject(forKey: Self.campaignAnchorKey)
        AppLaunchRouter.shared.clearSpinPresentation()
    }

    /// Mémorise la campagne ouverte (pour `marketing_notif_converted` au prochain achat).
    func markOpened(campaignId: String) {
        UserDefaults.standard.set(campaignId, forKey: Self.pendingOpenCampaignKey)
        if campaignId == ProcessMarketingNotificationKind.paywallExitInstant.rawValue
            || campaignId == ProcessMarketingNotificationKind.spinAgain.rawValue {
            markSawSpinWheel()
        }
        clearExitChase()
        cancelPendingExitChaseNotification()
    }

    /// Annule la série à l’achat ; track `marketing_notif_converted` si une notif a ouvert l’app.
    func handlePurchaseSuccess(plan: String) {
        let campaignId = UserDefaults.standard.string(forKey: Self.pendingOpenCampaignKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingOpenCampaignKey)
        cancelAll()
        if let campaignId {
            ProcessAnalytics.trackMarketingNotificationConverted(campaignId: campaignId, plan: plan)
        }
    }

    func clearPendingOpen() {
        UserDefaults.standard.removeObject(forKey: Self.pendingOpenCampaignKey)
    }

    // MARK: - Exit chase (quitté l’app juste après paywall)

    /// Arme la chase : dès que l’app passe en background (fenêtre 8 min), notif ~1.2s → roue.
    func armExitChase() {
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return }
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: Self.exitChaseArmedAtKey)
        defaults.set(false, forKey: Self.exitChaseFiredKey)
    }

    func clearExitChase() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.exitChaseArmedAtKey)
        defaults.set(false, forKey: Self.exitChaseFiredKey)
    }

    /// Appelé quand l’app passe en background → chase instantanée si armée / sur paywall.
    func handleAppLeftForeground() {
        guard !SubscriptionService.shared.subscriptionStatus.isActive else {
            clearExitChase()
            return
        }

        let onRetentionSurface = ProcessPreAccessHomeSwipeCoordinator.shared.retentionSurface != .none
        if onRetentionSurface, !isExitChaseArmedAndFresh {
            // Quitte l’app depuis le paywall / la roue sans dismiss préalable.
            armExitChase()
        }

        guard isExitChaseArmedAndFresh else { return }
        guard !UserDefaults.standard.bool(forKey: Self.exitChaseFiredKey) else { return }

        Task {
            await fireExitChaseNotificationIfPossible()
        }
    }

    /// App revient au premier plan — retire la chase pending non délivrée.
    func handleAppBecameActive() {
        cancelPendingExitChaseNotification()
        // Garde l’arme si encore dans la fenêtre (2ᵉ sortie app = 2ᵉ chance, tant que pas fired).
        if !isExitChaseArmedAndFresh {
            clearExitChase()
        }
    }

    private var isExitChaseArmedAndFresh: Bool {
        guard let armedAt = UserDefaults.standard.object(forKey: Self.exitChaseArmedAtKey) as? Date else {
            return false
        }
        return Date().timeIntervalSince(armedAt) <= Self.exitChaseWindow
    }

    private func fireExitChaseNotificationIfPossible() async {
        guard !SubscriptionService.shared.subscriptionStatus.isActive else { return }
        guard isExitChaseArmedAndFresh else { return }
        guard !UserDefaults.standard.bool(forKey: Self.exitChaseFiredKey) else { return }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        cancelPendingExitChaseNotification()

        let kind = ProcessMarketingNotificationKind.paywallExitInstant
        let firstName = UnifiedProfileService.shared.currentProfile?.firstName
        let content = UNMutableNotificationContent()
        content.title = kind.title(firstName: firstName)
        content.body = kind.body()
        content.sound = .default
        content.threadIdentifier = "process.marketing"
        content.interruptionLevel = .active
        content.relevanceScore = 1.0
        content.userInfo = [
            "kind": kind.userInfoKind,
            "campaign_id": kind.rawValue,
            "opens_lifetime_offer": false,
            "opens_spin_wheel": true
        ]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: Self.exitChaseFireDelay,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: kind.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            UserDefaults.standard.set(true, forKey: Self.exitChaseFiredKey)
            ProcessAnalytics.trackMarketingNotificationsScheduled(
                reason: "paywall_exit_instant",
                campaignIds: [kind.rawValue],
                sawSpin: hasSawSpinWheel
            )
        } catch {
            // ignore
        }
    }

    private func cancelPendingExitChaseNotification() {
        let id = ProcessMarketingNotificationKind.paywallExitInstant.notificationIdentifier
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Annule uniquement la série FOMO (garde la chase instantanée).
    func cancelPendingSeriesRequests() {
        let center = UNUserNotificationCenter.current()
        let ids = ProcessMarketingNotificationKind.seriesCases.map(\.notificationIdentifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Compat : annule série + chase délivrée/pending.
    func cancelPendingMarketingRequests() {
        cancelPendingSeriesRequests()
        cancelPendingExitChaseNotification()
        let deliveredInstant = ProcessMarketingNotificationKind.paywallExitInstant.notificationIdentifier
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [deliveredInstant])
    }

    // MARK: - Build schedule

    private struct Candidate: Equatable {
        let kind: ProcessMarketingNotificationKind
        let fireDate: Date
    }

    private func buildCandidates(anchor: Date, now: Date, sawSpin: Bool) -> [Candidate] {
        let calendar = Calendar.current
        var items: [Candidate] = []

        func dayOffset(_ days: Int, hour: Int, minute: Int) -> Date? {
            guard let day = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: anchor)) else {
                return nil
            }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            return calendar.date(from: components).map(respectQuietHours)
        }

        // Vague A
        items.append(Candidate(kind: .planReady, fireDate: respectQuietHours(anchor.addingTimeInterval(2 * 3600))))
        if let d = dayOffset(1, hour: 8, minute: 30) {
            items.append(Candidate(kind: .morningPuff, fireDate: d))
        }
        if let d = dayOffset(1, hour: 19, minute: 0) {
            items.append(Candidate(kind: .fomoLifetime, fireDate: d))
        }

        // Vague B
        if let d = dayOffset(2, hour: 12, minute: 0) {
            items.append(Candidate(kind: .offerAlmostGone, fireDate: d))
        }
        if sawSpin, let d = dayOffset(2, hour: 18, minute: 0) {
            items.append(Candidate(kind: .spinAgain, fireDate: d))
        }
        if let d = dayOffset(3, hour: 20, minute: 0) {
            items.append(Candidate(kind: .lastChance19, fireDate: d))
        }

        // Vague C
        if let d = dayOffset(4, hour: 9, minute: 0) {
            items.append(Candidate(kind: .socialProof, fireDate: d))
        }
        if let d = dayOffset(5, hour: 19, minute: 0) {
            items.append(Candidate(kind: .scanWasted, fireDate: d))
        }
        if let weekend = nextSaturday(after: anchor, hour: 10, minute: 0) {
            items.append(Candidate(kind: .weekendReset, fireDate: weekend))
        }

        // Vague D
        if let d = dayOffset(7, hour: 18, minute: 0) {
            items.append(Candidate(kind: .missYouValue, fireDate: d))
        }
        if let d = dayOffset(10, hour: 12, minute: 0) {
            items.append(Candidate(kind: .priceAnchor, fireDate: d))
        }
        if let d = dayOffset(14, hour: 19, minute: 0) {
            items.append(Candidate(kind: .finalNudge, fireDate: d))
        }
        if let d = dayOffset(21, hour: 11, minute: 0) {
            items.append(Candidate(kind: .dormant, fireDate: d))
        }

        return items
            .map { Candidate(kind: $0.kind, fireDate: max($0.fireDate, now.addingTimeInterval(60))) }
            .sorted { $0.fireDate < $1.fireDate }
    }

    /// 1 notif / jour civil + max 5 dans les 7 premiers jours (priorité).
    private func applyCaps(_ candidates: [Candidate]) -> [Candidate] {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(
            for: (UserDefaults.standard.object(forKey: Self.campaignAnchorKey) as? Date) ?? Date()
        )

        var byDay: [Date: [Candidate]] = [:]
        for item in candidates {
            let day = calendar.startOfDay(for: item.fireDate)
            byDay[day, default: []].append(item)
        }

        var dailyWinners: [Candidate] = []
        for day in byDay.keys.sorted() {
            let best = byDay[day]!.max(by: { $0.kind.retentionPriority < $1.kind.retentionPriority })!
            dailyWinners.append(best)
        }
        dailyWinners.sort { $0.fireDate < $1.fireDate }

        var firstWeek: [Candidate] = []
        var later: [Candidate] = []
        for item in dailyWinners {
            let day = calendar.startOfDay(for: item.fireDate)
            let daysFromAnchor = calendar.dateComponents([.day], from: anchorDay, to: day).day ?? 0
            if daysFromAnchor < 7 {
                firstWeek.append(item)
            } else {
                later.append(item)
            }
        }

        firstWeek.sort { $0.kind.retentionPriority > $1.kind.retentionPriority }
        let cappedWeek = Array(firstWeek.prefix(Self.maxInFirstWeek))
            .sorted { $0.fireDate < $1.fireDate }

        return cappedWeek + later
    }

    private func nextSaturday(after date: Date, hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday … 7 = Saturday
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let offset = daysUntilSaturday == 0 ? 7 : daysUntilSaturday // prochain samedi (pas aujourd’hui)
        guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)) else {
            return nil
        }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components).map(respectQuietHours)
    }

    private func respectQuietHours(_ date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        if hour >= Self.quietHourStart {
            // → lendemain 9h
            guard let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else {
                return date
            }
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: next) ?? date
        }
        if hour < Self.quietHourEnd {
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        }
        return date
    }

    private func schedule(_ item: Candidate) async throws {
        let firstName = UnifiedProfileService.shared.currentProfile?.firstName
        let content = UNMutableNotificationContent()
        content.title = item.kind.title(firstName: firstName)
        content.body = item.kind.body()
        content.sound = .default
        content.threadIdentifier = "process.marketing"
        content.userInfo = [
            "kind": item.kind.userInfoKind,
            "campaign_id": item.kind.rawValue,
            "opens_lifetime_offer": item.kind.opensLifetimeOffer,
            "opens_spin_wheel": item.kind.opensSpinWheel
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: item.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: item.kind.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }
}
