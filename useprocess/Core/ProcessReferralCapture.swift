import Foundation

/// Liens et messages de parrainage partagés entre l'app et le site.
enum ProcessReferralLink {
    static let landingHost = "useprocess.xyz"
    static let joinHost = "join.useprocess.xyz"
    static let joinPathPrefix = "/join/"

    static func landingURL(code: String) -> URL {
        let normalized = normalizeCode(code)
        return URL(string: "https://\(landingHost)\(joinPathPrefix)\(normalized)")!
    }

    /// Lien ultra-court — actif quand join.useprocess.xyz pointe vers Vercel.
    static func brandedShortURL(code: String) -> URL {
        let normalized = normalizeCode(code)
        return URL(string: "https://\(joinHost)/\(normalized)")!
    }

    static func normalizeCode(_ raw: String) -> String {
        ProcessReferralCode.normalize(raw)
    }

    static func displayCode(from raw: String) -> String {
        normalizeCode(raw)
    }

    static func parseCode(from url: URL) -> String? {
        if url.scheme == "process", url.host == "referral" {
            if let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value,
               !item.isEmpty {
                return normalizeCode(item)
            }
        }

        if let host = url.host?.lowercased(),
           host == landingHost || host == joinHost || host.hasSuffix(".\(landingHost)") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if host == joinHost, !path.isEmpty,
               path.lowercased() != "get", path.lowercased() != "telecharger",
               path.lowercased() != "app", path.lowercased() != "i", path.lowercased() != "a" {
                return normalizeCode(path)
            }
            if path.lowercased().hasPrefix("join/") {
                let code = String(path.dropFirst(5))
                if !code.isEmpty { return normalizeCode(code) }
            }
            if path == "get" || path == "telecharger" || path == "app" || path == "i" || path == "a" || path.isEmpty {
                if let item = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "ref" || $0.name == "code" })?
                    .value,
                   !item.isEmpty {
                    return normalizeCode(item)
                }
            }
        }

        return nil
    }

    static func parseCode(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), let parsed = parseCode(from: url) {
            return parsed
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            let matches = detector.matches(in: trimmed, options: [], range: range)
            for match in matches {
                if let url = match.url, let parsed = parseCode(from: url) {
                    return parsed
                }
            }
        }

        let joinPattern = #/(?:https?:\/\/)?(?:join\.)?useprocess\.xyz(?:/join)?/([A-Za-z0-9-]+)/#
        if let match = trimmed.firstMatch(of: joinPattern) {
            return normalizeCode(String(match.1))
        }

        let codePattern = #/\b([A-Z0-9]{5})\b/#
        if let match = trimmed.uppercased().firstMatch(of: codePattern) {
            return normalizeCode(String(match.1))
        }

        return nil
    }
}

/// Capture et applique un code parrainage entrant (lien profond / universal link).
@MainActor
enum ProcessReferralAttribution {
    private static let pendingKey = "referral.pendingCode"

    static var pendingCode: String? {
        guard let raw = UserDefaults.standard.string(forKey: pendingKey) else { return nil }
        let normalized = ProcessReferralLink.normalizeCode(raw)
        return normalized.isEmpty ? nil : normalized
    }

    static func capture(from url: URL) {
        ProcessAcquisitionAttribution.capture(from: url)
        guard let code = ProcessReferralLink.parseCode(from: url) else { return }
        storePending(code)
    }

    /// Ne jamais lire `UIPasteboard` au launch — iOS affiche « coller depuis le Mac ».
    /// Le code arrive uniquement via universal link / `process://referral`.

    static func applyPendingIfNeeded(to viewModel: OnboardingViewModel) {
        guard let code = pendingCode else { return }
        if ProcessAffiliateLifetimePass.matches(code) {
            ProcessAffiliateLifetimePass.unlock()
            clearPending()
            viewModel.creatorCodeDraft = ProcessAffiliateLifetimePass.code
            viewModel.creatorCodeIsVerified = true
            viewModel.saveProgress()
            return
        }
        let current = viewModel.referralCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if current.isEmpty {
            viewModel.referralCode = code
            viewModel.saveProgress()
            ProcessAcquisitionAttribution.captureReferralCode(code)
            Task { @MainActor in
                ProcessAnalytics.trackReferralCodeApplied(source: "onboarding")
            }
        }
    }

    static func clearPending() {
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    /// Saisie manuelle (paywall, réglages) — persiste jusqu'à inscription / onboarding.
    static func rememberManualEntry(_ raw: String) {
        storePending(raw)
    }

    private static func storePending(_ code: String) {
        let normalized = ProcessReferralLink.normalizeCode(code)
        guard !normalized.isEmpty else { return }
        if ProcessAffiliateLifetimePass.matches(normalized) {
            ProcessAffiliateLifetimePass.unlock()
            return
        }
        UserDefaults.standard.set(normalized, forKey: pendingKey)
        ProcessAcquisitionAttribution.captureReferralCode(normalized)
        Task { @MainActor in
            ProcessAnalytics.trackReferralCodeCaptured(source: "deep_link")
        }
    }
}

extension ProcessReferralLink {
    /// Deep link campagne sans code parrain (`process://acquire?utm_source=tiktok`).
    static func isAcquisitionURL(_ url: URL) -> Bool {
        url.scheme == "process" && (url.host == "acquire" || url.host == "referral")
    }
}

extension Notification.Name {
    static let processReferralCodeCaptured = Notification.Name("processReferralCodeCaptured")
}
