import Combine
import Foundation

/// Layout de la page résultats scan en mode studio.
enum ProcessCreatorScanResultsLayout: String, CaseIterable, Identifiable {
    /// Page analyse standard (métriques Whoop + tendances).
    case standard
    /// Première page onboarding (rétention / cortisol + graisse vs rétention).
    case onboardingDeep

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .standard:
            return AppCopy.t("Scan normal", en: "Normal scan")
        case .onboardingDeep:
            return AppCopy.t("Premier scan (graisse / rétention)", en: "First scan (fat / retention)")
        }
    }

    @MainActor
    var subtitle: String {
        switch self {
        case .standard:
            return AppCopy.t(
                "Écran résultats classique avec tous les indicateurs.",
                en: "Classic results screen with all indicators."
            )
        case .onboardingDeep:
            return AppCopy.t(
                "Comme le 1er scan onboarding : signaux ouverts + taux graisse / rétention.",
                en: "Like the 1st onboarding scan: unlocked signals + fat / retention split."
            )
        }
    }
}

/// Slots médias de la paire Début / Maintenant (IDs stables dans l’historique).
enum ProcessCreatorStudioScanSlot: String, CaseIterable, Identifiable {
    case start
    case now

    var id: String { rawValue }

    var scanId: String { "studio-identity-\(rawValue)" }

    static let pinnedScanIDs: Set<String> = Set(allCases.map(\.scanId))

    @MainActor
    var title: String {
        switch self {
        case .start: return AppCopy.t("Début", en: "Start")
        case .now: return AppCopy.t("Maintenant", en: "Now")
        }
    }
}

/// Ancien mode studio désactivé : les résultats utilisateurs ne sont jamais simulés.
@MainActor
final class ProcessCreatorModeStore: ObservableObject {
    static let shared = ProcessCreatorModeStore()

    static let unlockFirstName = "Manny"

    private static let unlockedKeyBase = "creator.mode.unlocked"
    private static let qualityKeyBase = "creator.mode.quality"
    private static let resultsLayoutKeyBase = "creator.mode.resultsLayout"
    private static let studioNowKeyBase = "creator.mode.studioNow"

    /// 0 = mauvais · 0.5 = réaliste (analyse) · 1 = excellent.
    @Published var resultQuality: Double {
        didSet { persistQuality() }
    }

    /// Layout résultats affiché après l’analyse (et à la réouverture du dernier scan).
    @Published var scanResultsLayout: ProcessCreatorScanResultsLayout {
        didSet { persistResultsLayout() }
    }

    @Published private(set) var isUnlocked: Bool

    /// « Maintenant » simulé pour la page Progrès (nil = date réelle).
    @Published var studioNowDate: Date? {
        didSet { persistStudioNow() }
    }

    private init() {
        let defaults = UserDefaults.standard
        isUnlocked = false
        let stored = defaults.double(forKey: Self.storageKey(Self.qualityKeyBase))
        // 0 = jamais écrit → défaut réaliste.
        resultQuality = defaults.object(forKey: Self.storageKey(Self.qualityKeyBase)) == nil
            ? 0.5
            : min(1, max(0, stored))

        if let raw = defaults.string(forKey: Self.storageKey(Self.resultsLayoutKeyBase)),
           let layout = ProcessCreatorScanResultsLayout(rawValue: raw) {
            scanResultsLayout = layout
        } else {
            scanResultsLayout = .standard
        }

        if let interval = defaults.object(forKey: Self.storageKey(Self.studioNowKeyBase)) as? TimeInterval {
            studioNowDate = Date(timeIntervalSince1970: interval)
        } else {
            studioNowDate = nil
        }
    }

    static func matchesUnlockName(_ name: String) -> Bool {
        false
    }

    /// Unlock live sans dépendre uniquement du flag UserDefaults.
    func isUnlocked(forFirstName firstName: String?) -> Bool {
        false
    }

    func evaluate(firstName: String?) {
        isUnlocked = false
    }

    func syncFromCurrentProfile() {
        isUnlocked = false
        resultQuality = 0.5
        studioNowDate = nil
    }

    private func unlockNameCandidates(including extra: String?) -> [String] {
        let profile = UnifiedProfileService.shared.currentProfile
        let social = SocialProfileStore.shared.profile
        return [
            extra,
            profile?.firstName,
            profile?.lastName,
            profile?.username,
            social?.displayName,
            social?.username,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }

    /// Relit le flag unlock / qualité pour la clé UserDefaults actuelle.
    func reloadFromStorage() {
        let defaults = UserDefaults.standard
        let unlockedKey = Self.storageKey(Self.unlockedKeyBase)
        let qualityKey = Self.storageKey(Self.qualityKeyBase)

        // Migration : si la clé user est vide, récupère l’ancienne clé anonymous/local.
        if defaults.object(forKey: unlockedKey) == nil {
            for legacyUID in ["anonymous", "local-user"] {
                let legacy = UserScopedStorage.key(Self.unlockedKeyBase, userId: legacyUID)
                if defaults.object(forKey: legacy) != nil {
                    defaults.set(defaults.bool(forKey: legacy), forKey: unlockedKey)
                    let legacyQuality = UserScopedStorage.key(Self.qualityKeyBase, userId: legacyUID)
                    if defaults.object(forKey: legacyQuality) != nil {
                        defaults.set(defaults.double(forKey: legacyQuality), forKey: qualityKey)
                    }
                    break
                }
            }
        }

        let unlocked = false
        if unlocked != isUnlocked {
            isUnlocked = unlocked
        }
        if defaults.object(forKey: qualityKey) != nil {
            let stored = min(1, max(0, defaults.double(forKey: qualityKey)))
            if abs(stored - resultQuality) > 0.0001 {
                resultQuality = stored
            }
        }

        let layoutKey = Self.storageKey(Self.resultsLayoutKeyBase)
        if let raw = defaults.string(forKey: layoutKey),
           let layout = ProcessCreatorScanResultsLayout(rawValue: raw),
           layout != scanResultsLayout {
            scanResultsLayout = layout
        }
    }

    var allowsUnlimitedScans: Bool {
        isUnlocked(forFirstName: UnifiedProfileService.shared.currentProfile?.firstName)
    }
    var allowsPhotoImport: Bool {
        isUnlocked(forFirstName: UnifiedProfileService.shared.currentProfile?.firstName)
    }

    var showsStudioEntry: Bool {
        isUnlocked(forFirstName: UnifiedProfileService.shared.currentProfile?.firstName)
    }

    /// Horloge studio — page Progrès / série. Sinon `Date()`.
    var effectiveNow: Date {
        guard isUnlocked(forFirstName: UnifiedProfileService.shared.currentProfile?.firstName),
              let studioNowDate else {
            return Date()
        }
        return Calendar.current.startOfDay(for: studioNowDate)
    }

    var studioPlanStartDate: Date {
        let calendar = Calendar.current
        if let started = WelcomePlanStore.shared.plan?.calendar.startedAt {
            return calendar.startOfDay(for: started)
        }
        return calendar.startOfDay(for: effectiveNow)
    }

    func setStudioPlanStartDate(_ date: Date) {
        let start = Calendar.current.startOfDay(for: date)
        WelcomePlanStore.shared.updateCalendarStartedAt(start)
        if let now = studioNowDate, now < start {
            studioNowDate = start
        }
        FaceScanHistoryStore.shared.retargetStudioScanDate(slot: .start, date: start)
        objectWillChange.send()
    }

    func setStudioNowDate(_ date: Date) {
        let calendar = Calendar.current
        let start = studioPlanStartDate
        let clamped = max(calendar.startOfDay(for: date), start)
        studioNowDate = clamped
        FaceScanHistoryStore.shared.retargetStudioScanDate(slot: .now, date: clamped)
        ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
        objectWillChange.send()
    }

    func clearStudioNowDate() {
        studioNowDate = nil
        ProcessPlanProgressStore.shared.reload(plan: WelcomePlanStore.shared.plan)
        objectWillChange.send()
    }

    private func persistStudioNow() {
        let key = Self.storageKey(Self.studioNowKeyBase)
        if let studioNowDate {
            UserDefaults.standard.set(studioNowDate.timeIntervalSince1970, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    var qualityLabel: String {
        switch resultQuality {
        case ..<0.2: return AppCopy.t("Mauvais", en: "Poor")
        case ..<0.4: return AppCopy.t("Faible", en: "Weak")
        case ..<0.6: return AppCopy.t("Réaliste", en: "Realistic")
        case ..<0.8: return AppCopy.t("Bon", en: "Good")
        default: return AppCopy.t("Excellent", en: "Excellent")
        }
    }

    /// Applique le slider sur les markers d’analyse réelle.
    /// `variationSeed` (ex. scan id) fait varier les indicateurs d’un screen à l’autre.
    func applyQuality(
        to base: FaceWellnessMarkers,
        quality: Double? = nil,
        variationSeed: String = ""
    ) -> FaceWellnessMarkers {
        return base
    }

    func rebuildResult(_ result: FaceScanResult, quality: Double? = nil) -> FaceScanResult {
        return result
    }

    private func persistQuality() {
        UserDefaults.standard.set(resultQuality, forKey: Self.storageKey(Self.qualityKeyBase))
    }

    private func persistResultsLayout() {
        UserDefaults.standard.set(
            scanResultsLayout.rawValue,
            forKey: Self.storageKey(Self.resultsLayoutKeyBase)
        )
    }

    private static func storageKey(_ base: String) -> String {
        UserScopedStorage.key(base)
    }
}
