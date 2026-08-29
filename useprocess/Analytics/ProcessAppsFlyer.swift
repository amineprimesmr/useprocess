import AppsFlyerLib
import Foundation

/// MMP AppsFlyer : install attribution, SKAN, events ROAS, deep links.
/// Idempotent. SDK 7 : `initialize` + `start` via `registerSessionReadyListener`.
final class ProcessAppsFlyer: NSObject {
    static let shared = ProcessAppsFlyer()

    private var didConfigure = false

    var isConfigured: Bool { didConfigure && AppsFlyerConfiguration.isConfigured }

    var appsFlyerUID: String? {
        guard isConfigured else { return nil }
        let uid = AppsFlyerLib.shared().getAppsFlyerUID()
        return uid.isEmpty ? nil : uid
    }

    func configure() {
        guard !didConfigure else { return }
        guard AppsFlyerConfiguration.isConfigured else {
            #if DEBUG
            print("[ProcessAppsFlyer] Dev Key / Apple App ID manquants")
            #endif
            return
        }

        let lib = AppsFlyerLib.shared()
        lib.initialize(devKey: AppsFlyerConfiguration.devKey, appId: AppsFlyerConfiguration.appleAppID)
        lib.delegate = self
        #if DEBUG
        lib.isDebug = true
        #endif

        // SDK 7 : `start()` uniquement dans le listener (une fois par cycle foreground).
        lib.registerSessionReadyListener {
            AppsFlyerLib.shared().start()
        }

        didConfigure = true
    }

    func setCustomerUserID(_ userId: String?) {
        guard isConfigured else { return }
        let trimmed = userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        AppsFlyerLib.shared().customerUserID = trimmed
    }

    func handleOpen(_ url: URL) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().handleOpen(url, options: [:])
    }

    func continueUserActivity(_ userActivity: NSUserActivity) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    func logEvent(_ name: String, values: [String: Any] = [:]) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(name, withValues: values.isEmpty ? nil : values)
    }

    func logPurchase(plan: String, offer: String?, revenue: Double?, currency: String?, productID: String?) {
        let isLifetime = plan.lowercased().contains("lifetime")
        let event = isLifetime ? "af_purchase" : "af_subscribe"

        var values: [String: Any] = [
            "af_content_type": isLifetime ? "lifetime" : "subscription",
            "af_content_id": productID ?? plan
        ]
        if let offer, !offer.isEmpty { values["offer"] = offer }
        values["plan"] = plan
        if let currency, !currency.isEmpty {
            values["af_currency"] = currency
        }
        if let revenue {
            values["af_revenue"] = revenue
        }
        logEvent(event, values: values)
    }
}

extension ProcessAppsFlyer: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        Task { @MainActor in
            ProcessAcquisitionAttribution.captureAppsFlyerConversion(conversionInfo)
        }
    }

    func onConversionDataFail(_ error: Error) {
        #if DEBUG
        print("[ProcessAppsFlyer] conversion data fail: \(error.localizedDescription)")
        #endif
    }
}
