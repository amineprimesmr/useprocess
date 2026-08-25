import Foundation

/// AppsFlyer MMP — Dev Key + Apple App ID embarqués (clés client, comme `appl_` RevenueCat).
enum AppsFlyerConfiguration {
    /// Dev Key dashboard AppsFlyer (App Settings). Unique au compte, pas une secret server.
    static let devKey = "FTFBvYrLVF2Qageyiuat3h"

    /// App Store ID sans le préfixe `id`.
    static let appleAppID = "6753808143"

    static var isConfigured: Bool {
        !devKey.isEmpty
            && !devKey.hasPrefix("YOUR_")
            && !appleAppID.isEmpty
            && appleAppID.allSatisfy(\.isNumber)
    }
}
