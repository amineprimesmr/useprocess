import Foundation

@MainActor
@Observable
final class PlanHomeFaceScanDisplayPreferences {
    static let shared = PlanHomeFaceScanDisplayPreferences()

    private(set) var showsVideo = true

    private init() {
        reload()
    }

    func reload() {
        let key = UserScopedStorage.key("plan.home.face_scan.shows_video")
        showsVideo = UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    func setShowsVideo(_ value: Bool) {
        showsVideo = value
        UserDefaults.standard.set(value, forKey: UserScopedStorage.key("plan.home.face_scan.shows_video"))
    }
}
