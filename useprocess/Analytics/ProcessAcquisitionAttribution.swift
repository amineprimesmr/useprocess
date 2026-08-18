import Foundation
#if canImport(AdServices)
import AdServices
#endif

/// Attribution acquisition (first-touch + last-touch) : referral, ASA, UTM / campagnes.
/// Persiste en local (survit au logout). Sync PostHog + RevenueCat.
@MainActor
enum ProcessAcquisitionAttribution {
    private static let storageKey = "process.acquisition.snapshot.v1"
    private static let asaResolvedKey = "process.acquisition.asaResolved.v1"
    private static let didEmitResolvedEventKey = "process.acquisition.resolvedEvent.v1"

    private(set) static var snapshot: Snapshot = load() {
        didSet { save(snapshot) }
    }

    struct Snapshot: Codable, Equatable {
        var firstSource: String?
        var firstMedium: String?
        var firstCampaign: String?
        var firstContent: String?
        var firstTerm: String?
        var referralCode: String?
        var affiliateCode: String?
        var asaAttributed: Bool?
        var asaCampaignId: String?
        var asaAdGroupId: String?
        var asaKeywordId: String?
        var asaOrgId: String?
        var asaCountryOrRegion: String?
        var asaConversionType: String?
        var lastSource: String?
        var lastMedium: String?
        var lastCampaign: String?
        var lastContent: String?
        var lastTerm: String?
        var lastReferralCode: String?
        var updatedAt: Date?

        /// Canal principal pour PostHog / RevenueCat (first-touch).
        var primarySource: String {
            if let code = affiliateCode, !code.isEmpty { return "affiliate" }
            if let code = referralCode, !code.isEmpty { return "referral" }
            if asaAttributed == true { return "asa" }
            if let source = firstSource?.trimmingCharacters(in: .whitespacesAndNewlines),
               !source.isEmpty,
               source.lowercased() != "organic",
               source.lowercased() != "unknown" {
                return source.lowercased()
            }
            return "organic"
        }

        var primaryMedium: String {
            if affiliateCode != nil { return firstMedium ?? "affiliate" }
            if referralCode != nil { return firstMedium ?? "referral" }
            if asaAttributed == true { return firstMedium ?? "search" }
            return firstMedium ?? "organic"
        }
    }

    struct Touch: Equatable {
        var source: String?
        var medium: String?
        var campaign: String?
        var content: String?
        var term: String?
        var referralCode: String?
        var affiliateCode: String?
    }

    // MARK: - Bootstrap

    /// Appelé après `ProcessAnalytics.configure()` — ASA en arrière-plan + sync immédiat.
    static func bootstrap() {
        if snapshot.firstSource == nil && snapshot.referralCode == nil && snapshot.affiliateCode == nil && snapshot.asaAttributed != true {
            applyTouch(
                Touch(source: "organic", medium: "organic"),
                reason: "bootstrap_organic",
                allowDowngrade: false
            )
        } else {
            syncToAnalytics(emitResolvedEvent: false)
        }

        Task {
            await resolveAppleSearchAdsIfNeeded()
        }
    }

    // MARK: - Ingest

    static func capture(from url: URL) {
        let touch = touch(from: url)
        guard hasSignal(touch) else { return }
        applyTouch(touch, reason: "url", allowDowngrade: false)
    }

    static func captureReferralCode(_ raw: String, source: String = "referral", medium: String = "referral") {
        let code = ProcessReferralLink.normalizeCode(raw)
        guard !code.isEmpty else { return }
        applyTouch(
            Touch(source: source, medium: medium, referralCode: code),
            reason: "referral_code",
            allowDowngrade: false
        )
    }

    static func captureAffiliateCode(_ raw: String, source: String = "affiliate", medium: String = "creator") {
        let code = ProcessAffiliateLink.normalizeCode(raw)
        guard !code.isEmpty else { return }
        applyTouch(
            Touch(source: source, medium: medium, affiliateCode: code),
            reason: "affiliate_code",
            allowDowngrade: false
        )
    }

    static func captureCampaign(
        source: String?,
        medium: String? = nil,
        campaign: String? = nil,
        content: String? = nil,
        term: String? = nil
    ) {
        let touch = Touch(
            source: source,
            medium: medium,
            campaign: campaign,
            content: content,
            term: term
        )
        guard hasSignal(touch) else { return }
        applyTouch(touch, reason: "campaign", allowDowngrade: false)
    }

    // MARK: - Analytics / RC payloads

    static func analyticsProperties(includeLastTouch: Bool = true) -> [String: Any] {
        var props: [String: Any] = [
            "acquisition_source": snapshot.primarySource,
            "acquisition_medium": snapshot.primaryMedium
        ]
        if let campaign = snapshot.firstCampaign, !campaign.isEmpty {
            props["acquisition_campaign"] = campaign
        }
        if let content = snapshot.firstContent, !content.isEmpty {
            props["acquisition_content"] = content
        }
        if let term = snapshot.firstTerm, !term.isEmpty {
            props["acquisition_term"] = term
        }
        if let code = snapshot.referralCode, !code.isEmpty {
            props["referral_code"] = code
            props["has_referral_code"] = true
        } else {
            props["has_referral_code"] = false
        }
        if let code = snapshot.affiliateCode, !code.isEmpty {
            props["affiliate_code"] = code
            props["has_affiliate_code"] = true
        } else {
            props["has_affiliate_code"] = false
        }
        if let asa = snapshot.asaAttributed {
            props["asa_attributed"] = asa
        }
        if let value = snapshot.asaCampaignId { props["asa_campaign_id"] = value }
        if let value = snapshot.asaAdGroupId { props["asa_ad_group_id"] = value }
        if let value = snapshot.asaKeywordId { props["asa_keyword_id"] = value }
        if let value = snapshot.asaOrgId { props["asa_org_id"] = value }
        if let value = snapshot.asaCountryOrRegion { props["asa_country"] = value }
        if let value = snapshot.asaConversionType { props["asa_conversion_type"] = value }

        if includeLastTouch {
            if let value = snapshot.lastSource { props["acquisition_last_source"] = value }
            if let value = snapshot.lastMedium { props["acquisition_last_medium"] = value }
            if let value = snapshot.lastCampaign { props["acquisition_last_campaign"] = value }
            if let value = snapshot.lastReferralCode { props["acquisition_last_referral_code"] = value }
        }
        return props
    }

    static func revenueCatAttributes() -> [String: String] {
        var attrs: [String: String] = [
            "acquisition_source": snapshot.primarySource,
            "acquisition_medium": snapshot.primaryMedium
        ]
        if let campaign = snapshot.firstCampaign, !campaign.isEmpty {
            attrs["acquisition_campaign"] = String(campaign.prefix(40))
        }
        if let code = snapshot.referralCode, !code.isEmpty {
            attrs["referral_code"] = String(code.prefix(40))
        }
        if let code = snapshot.affiliateCode, !code.isEmpty {
            attrs["affiliate_code"] = String(code.prefix(40))
        }
        if snapshot.asaAttributed == true {
            attrs["asa_attributed"] = "true"
            if let id = snapshot.asaCampaignId {
                attrs["asa_campaign_id"] = String(id.prefix(40))
            }
        }
        for (key, value) in SubscriptionMarketPolicy.analyticsProperties {
            attrs[key] = value
        }
        return attrs
    }

    static func syncToAnalytics(emitResolvedEvent: Bool = true) {
        let props = analyticsProperties()
        ProcessAnalytics.registerAcquisitionSuperProperties(props)
        ProcessAnalytics.setPersonProperties(props)

        if emitResolvedEvent,
           !UserDefaults.standard.bool(forKey: didEmitResolvedEventKey),
           snapshot.primarySource != "organic" || snapshot.referralCode != nil || snapshot.asaAttributed == true {
            UserDefaults.standard.set(true, forKey: didEmitResolvedEventKey)
            ProcessAnalytics.capture("acquisition_resolved", properties: props)
        }

        Task {
            await SubscriptionService.shared.syncAcquisitionAttributesIfPossible()
        }
    }

    // MARK: - Apple Search Ads

    static func resolveAppleSearchAdsIfNeeded() async {
        if UserDefaults.standard.bool(forKey: asaResolvedKey) { return }

        #if targetEnvironment(simulator)
        UserDefaults.standard.set(true, forKey: asaResolvedKey)
        return
        #else
        guard #available(iOS 14.3, *) else {
            UserDefaults.standard.set(true, forKey: asaResolvedKey)
            return
        }

        #if canImport(AdServices)
        let token: String
        do {
            token = try AAAttribution.attributionToken()
        } catch {
            // Token sometimes unavailable for a few seconds after install — retry once later.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            do {
                token = try AAAttribution.attributionToken()
            } catch {
                UserDefaults.standard.set(true, forKey: asaResolvedKey)
                return
            }
        }

        guard let payload = await fetchASAAttribution(token: token) else {
            // Keep unresolved so a later open can retry (network blip).
            return
        }

        UserDefaults.standard.set(true, forKey: asaResolvedKey)

        let attributed = payload["attribution"] as? Bool ?? false
        guard attributed else {
            syncToAnalytics(emitResolvedEvent: false)
            return
        }

        var next = snapshot
        next.asaAttributed = true
        next.asaCampaignId = stringValue(payload["campaignId"])
        next.asaAdGroupId = stringValue(payload["adGroupId"])
        next.asaKeywordId = stringValue(payload["keywordId"])
        next.asaOrgId = stringValue(payload["orgId"])
        next.asaCountryOrRegion = payload["countryOrRegion"] as? String
        next.asaConversionType = payload["conversionType"] as? String
        next.updatedAt = Date()

        // First-touch upgrade if still organic / empty.
        if shouldUpgradeFirstTouch(current: next.firstSource, incoming: "asa") {
            next.firstSource = "asa"
            next.firstMedium = "search"
            if next.firstCampaign == nil {
                next.firstCampaign = next.asaCampaignId.map { "asa_\($0)" }
            }
        }
        next.lastSource = "asa"
        next.lastMedium = "search"
        if let campaignId = next.asaCampaignId {
            next.lastCampaign = "asa_\(campaignId)"
        }

        snapshot = next
        syncToAnalytics(emitResolvedEvent: true)
        #else
        UserDefaults.standard.set(true, forKey: asaResolvedKey)
        #endif
        #endif
    }

    // MARK: - Private

    private static func touch(from url: URL) -> Touch {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        func query(_ names: String...) -> String? {
            for name in names {
                if let value = items.first(where: { $0.name.lowercased() == name.lowercased() })?.value?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                   !value.isEmpty {
                    return value
                }
            }
            return nil
        }

        let referral = ProcessReferralLink.parseCode(from: url)
            ?? query("ref", "code").map { ProcessReferralLink.normalizeCode($0) }

        var source = query("utm_source", "source")
        var medium = query("utm_medium", "medium")
        var campaign = query("utm_campaign", "campaign")
        let content = query("utm_content", "content")
        let term = query("utm_term", "term")

        // App Store campaign token `ct=ref_CODE` (si jamais relayé).
        if referral == nil, let ct = query("ct"), ct.lowercased().hasPrefix("ref_") {
            let code = ProcessReferralLink.normalizeCode(String(ct.dropFirst(4)))
            if !code.isEmpty {
                return Touch(
                    source: source ?? "referral",
                    medium: medium ?? "referral",
                    campaign: campaign,
                    content: content,
                    term: term,
                    referralCode: code
                )
            }
        }

        if let referral, !referral.isEmpty {
            source = source ?? "referral"
            medium = medium ?? "referral"
        }

        // Campagne path /c/tiktok
        if campaign == nil || source == nil {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.lowercased().hasPrefix("c/") {
                let slug = String(path.dropFirst(2))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                if !slug.isEmpty {
                    source = source ?? slug
                    medium = medium ?? "campaign"
                    campaign = campaign ?? slug
                }
            }
        }

        return Touch(
            source: source?.lowercased(),
            medium: medium?.lowercased(),
            campaign: campaign,
            content: content,
            term: term,
            referralCode: referral.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    private static func hasSignal(_ touch: Touch) -> Bool {
        let values = [
            touch.source, touch.medium, touch.campaign, touch.content, touch.term,
            touch.referralCode, touch.affiliateCode
        ]
        return values.contains { ($0?.isEmpty == false) }
    }

    private static func applyTouch(_ touch: Touch, reason: String, allowDowngrade: Bool) {
        var next = snapshot
        let now = Date()

        // Last-touch always updates when we have signal.
        if let source = touch.source, !source.isEmpty { next.lastSource = source }
        if let medium = touch.medium, !medium.isEmpty { next.lastMedium = medium }
        if let campaign = touch.campaign, !campaign.isEmpty { next.lastCampaign = campaign }
        if let content = touch.content, !content.isEmpty { /* last content unused */ _ = content }
        if let term = touch.term, !term.isEmpty { /* last term unused */ _ = term }
        if let code = touch.referralCode, !code.isEmpty { next.lastReferralCode = code }

        let incomingSource = resolvedIncomingSource(touch)
        if shouldUpgradeFirstTouch(current: next.firstSource, incoming: incomingSource)
            || allowDowngrade
            || next.firstSource == nil {
            next.firstSource = touch.source ?? incomingSource
            if let medium = touch.medium {
                next.firstMedium = medium
            } else if incomingSource == "referral" {
                next.firstMedium = "referral"
            } else if incomingSource == "affiliate" {
                next.firstMedium = "creator"
            } else if incomingSource == "asa" {
                next.firstMedium = "search"
            }
            if let campaign = touch.campaign { next.firstCampaign = campaign }
            if let content = touch.content { next.firstContent = content }
            if let term = touch.term { next.firstTerm = term }
        } else {
            // Enrich empty first-touch fields without changing source.
            if next.firstMedium == nil { next.firstMedium = touch.medium }
            if next.firstCampaign == nil { next.firstCampaign = touch.campaign }
            if next.firstContent == nil { next.firstContent = touch.content }
            if next.firstTerm == nil { next.firstTerm = touch.term }
        }

        if let code = touch.referralCode, !code.isEmpty {
            if next.referralCode == nil || next.referralCode?.isEmpty == true {
                next.referralCode = code
            }
            if shouldUpgradeFirstTouch(current: next.firstSource, incoming: "referral") {
                next.firstSource = touch.source ?? "referral"
                next.firstMedium = touch.medium ?? "referral"
            }
        }

        if let code = touch.affiliateCode, !code.isEmpty {
            if next.affiliateCode == nil || next.affiliateCode?.isEmpty == true {
                next.affiliateCode = code
            }
            if shouldUpgradeFirstTouch(current: next.firstSource, incoming: "affiliate") {
                next.firstSource = touch.source ?? "affiliate"
                next.firstMedium = touch.medium ?? "creator"
            }
        }

        next.updatedAt = now
        snapshot = next

        #if DEBUG
        print("[Acquisition] touch reason=\(reason) primary=\(next.primarySource) affiliate=\(next.affiliateCode ?? "-") referral=\(next.referralCode ?? "-")")
        #endif

        syncToAnalytics(emitResolvedEvent: next.primarySource != "organic" || next.referralCode != nil || next.affiliateCode != nil)
    }

    private static func resolvedIncomingSource(_ touch: Touch) -> String {
        if let code = touch.affiliateCode, !code.isEmpty { return "affiliate" }
        if let code = touch.referralCode, !code.isEmpty { return "referral" }
        if let source = touch.source?.lowercased(), !source.isEmpty { return source }
        if touch.campaign != nil { return "campaign" }
        return "organic"
    }

    private static func priority(for source: String?) -> Int {
        guard let source, !source.isEmpty else { return 0 }
        switch source.lowercased() {
        case "affiliate": return 45
        case "referral": return 40
        case "asa": return 30
        case "organic", "unknown": return 0
        default: return 20 // utm / paid / social / creator
        }
    }

    private static func shouldUpgradeFirstTouch(current: String?, incoming: String) -> Bool {
        priority(for: incoming) > priority(for: current)
    }

    private static func stringValue(_ any: Any?) -> String? {
        if let number = any as? NSNumber { return number.stringValue }
        if let string = any as? String, !string.isEmpty { return string }
        if let int = any as? Int { return String(int) }
        return nil
    }

    private static func fetchASAAttribution(token: String) async -> [String: Any]? {
        guard let url = URL(string: "https://api-adservices.apple.com/api/v1/") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            // 404 = no attribution data yet / not an ASA install.
            if http.statusCode == 404 {
                return ["attribution": false]
            }
            guard (200...299).contains(http.statusCode) else { return nil }
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }

    private static func load() -> Snapshot {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return Snapshot()
        }
        return decoded
    }

    private static func save(_ snapshot: Snapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
