import Foundation

/// Résultat iTunes Lookup — version App Store vs build installé.
struct ProcessAppUpdateInfo: Identifiable, Equatable {
    let id: String
    let currentVersion: String
    let availableVersion: String
    let releaseNotes: String
    let appLogoURL: URL?
    let appStoreURL: URL
    let isForced: Bool
}

/// Vérifie les mises à jour via `itunes.apple.com/lookup` (même flux que VersionAppCheck).
///
/// Mise à jour bloquante : mets `[FORCE]` dans les notes « Nouveautés » App Store Connect.
@MainActor
enum ProcessAppUpdateChecker {
    static let appStoreID = "6753808143"
    private static let forceMarker = "[FORCE]"
    private static let fallbackStoreURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)")!

    static func checkIfAppUpdateAvailable() async -> ProcessAppUpdateInfo? {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let lookupURL = lookupURL(bundleID: bundleID) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let results = payload?["results"] as? [Any]
            guard let jsonValue = results?.first as? [String: Any] else { return nil }

            guard let availableVersion = jsonValue["version"] as? String,
                  let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            else {
                return nil
            }

            guard currentVersion.compare(availableVersion, options: .numeric) == .orderedAscending else {
                return nil
            }

            let notes = (jsonValue["releaseNotes"] as? String) ?? ""
            let artwork = jsonValue["artworkUrl512"] as? String
            let trackURL = (jsonValue["trackViewUrl"] as? String)?
                .components(separatedBy: "?")
                .first
            let storeURL = trackURL.flatMap(URL.init(string:)) ?? fallbackStoreURL

            return ProcessAppUpdateInfo(
                id: availableVersion,
                currentVersion: currentVersion,
                availableVersion: availableVersion,
                releaseNotes: notes,
                appLogoURL: artwork.flatMap(URL.init(string:)),
                appStoreURL: storeURL,
                isForced: notes.uppercased().contains(forceMarker)
            )
        } catch {
            return nil
        }
    }

    private static func lookupURL(bundleID: String) -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: ProcessAppLanguage.prefersEnglish ? "us" : "fr")
        ]
        return components?.url
    }
}

/// Présente la sheet de maj au launch / retour foreground.
@MainActor
@Observable
final class ProcessAppUpdateStore {
    static let shared = ProcessAppUpdateStore()

    private static let dismissedVersionKey = "process.appUpdate.dismissedVersion"
    private static let lookupCooldown: TimeInterval = 30 * 60

    var presentedUpdate: ProcessAppUpdateInfo?
    private var lastLookupAt: Date?
    private var cachedUpdate: ProcessAppUpdateInfo?

    private init() {}

    var isForced: Bool { presentedUpdate?.isForced == true }

    func refresh(hasCompletedOnboarding: Bool) async {
        await fetchIfNeeded()
        presentIfEligible(hasCompletedOnboarding: hasCompletedOnboarding)
    }

    func dismissOptional() {
        guard let update = presentedUpdate, !update.isForced else { return }
        UserDefaults.standard.set(update.availableVersion, forKey: Self.dismissedVersionKey)
        presentedUpdate = nil
    }

    private func fetchIfNeeded() async {
        if let lastLookupAt, Date().timeIntervalSince(lastLookupAt) < Self.lookupCooldown {
            return
        }
        lastLookupAt = Date()
        cachedUpdate = await ProcessAppUpdateChecker.checkIfAppUpdateAvailable()
    }

    private func presentIfEligible(hasCompletedOnboarding: Bool) {
        guard presentedUpdate == nil else { return }
        guard let update = cachedUpdate else { return }

        if update.isForced {
            presentedUpdate = update
            ProcessAnalytics.trackAppUpdatePromptShown(
                from: update.currentVersion,
                to: update.availableVersion,
                forced: true
            )
            return
        }

        guard hasCompletedOnboarding else { return }
        let dismissed = UserDefaults.standard.string(forKey: Self.dismissedVersionKey)
        guard dismissed != update.availableVersion else { return }

        presentedUpdate = update
        ProcessAnalytics.trackAppUpdatePromptShown(
            from: update.currentVersion,
            to: update.availableVersion,
            forced: false
        )
    }
}
