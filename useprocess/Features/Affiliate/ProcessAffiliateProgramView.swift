import SwiftUI

@MainActor
@Observable
final class ProcessAffiliateStore {
    static let shared = ProcessAffiliateStore()

    private(set) var dashboard: ProcessAffiliateDashboardResponse?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private init() {}

    func reload() async {
        guard FirebaseBootstrap.isConfigured,
              AuthUser.current != nil,
              ClaudeConfiguration.functionsBaseURL != nil else {
            dashboard = nil
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            dashboard = try await AffiliateRemoteService.dashboard()
        } catch let error as AffiliateRemoteError {
            if case .httpError(404, _) = error {
                dashboard = nil
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ProcessAffiliateProgramDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @State private var store = ProcessAffiliateStore.shared
    @State private var paypalEmail = ""
    @State private var isSaving = false
    @State private var statusMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                if store.isLoading && store.dashboard == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let dashboard = store.dashboard {
                    statsGrid(dashboard.stats)
                    codesSection(dashboard)
                    payoutSection(dashboard)
                    commissionsSection(dashboard)
                } else {
                    applySection
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .padding(20)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(AppCopy.t("Programme créateur", en: "Creator program"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.reload() }
        .refreshable { await store.reload() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppCopy.t("Commissions clipper", en: "Clipper commissions"))
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.primaryText)
            Text(
                AppCopy.t(
                    "40 % du revenu net sur chaque abonnement actif pendant 30 jours de hold.",
                    en: "40% of net revenue on each active subscription, with a 30-day hold."
                )
            )
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)
        }
    }

    private func statsGrid(_ stats: ProcessAffiliateDashboardStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(
                title: AppCopy.t("En attente", en: "Pending"),
                value: money(cents: stats.pendingCents)
            )
            statCard(
                title: AppCopy.t("À payer", en: "Payable"),
                value: money(cents: stats.payableCents)
            )
            statCard(
                title: AppCopy.t("Payé", en: "Paid"),
                value: money(cents: stats.paidCents)
            )
            statCard(
                title: AppCopy.t("Parrainés", en: "Referred"),
                value: "\(stats.referredCount)"
            )
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.7 : 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func codesSection(_ dashboard: ProcessAffiliateDashboardResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppCopy.t("Tes codes", en: "Your codes"))
                .font(.headline)
            ForEach(dashboard.codes) { code in
                VStack(alignment: .leading, spacing: 4) {
                    Text(code.code)
                        .font(.title3.weight(.bold))
                    Text(ProcessAffiliateLink.landingURL(code: code.code).absoluteString)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.7 : 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func payoutSection(_ dashboard: ProcessAffiliateDashboardResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppCopy.t("Paiement PayPal", en: "PayPal payout"))
                .font(.headline)
            TextField(
                AppCopy.t("Email PayPal", en: "PayPal email"),
                text: $paypalEmail
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.emailAddress)
            .padding(14)
            .background(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.7 : 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onAppear {
                paypalEmail = dashboard.paypalEmail ?? ""
            }

            Button {
                Task { await savePaypal() }
            } label: {
                Text(AppCopy.t("Enregistrer", en: "Save"))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .background(theme.primaryText)
            .foregroundStyle(theme.inverseText)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(isSaving)
        }
    }

    private func commissionsSection(_ dashboard: ProcessAffiliateDashboardResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppCopy.t("Commissions récentes", en: "Recent commissions"))
                .font(.headline)
            if dashboard.recentCommissions.isEmpty {
                Text(AppCopy.t("Aucune commission pour l’instant.", en: "No commissions yet."))
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            } else {
                ForEach(dashboard.recentCommissions) { row in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.eventType)
                                .font(.subheadline.weight(.semibold))
                            Text(row.status)
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                        Spacer()
                        Text(money(cents: row.commissionCents, currency: row.currency))
                            .font(.subheadline.weight(.bold))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var applySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppCopy.t("Pas encore clipper ?", en: "Not a clipper yet?"))
                .font(.headline)
            Text(
                AppCopy.t(
                    "Demande ton accès créateur ou connecte-toi sur useprocess.xyz/affiliate.",
                    en: "Apply for creator access or sign in at useprocess.xyz/affiliate."
                )
            )
            .font(.subheadline)
            .foregroundStyle(theme.secondaryText)

            Link(
                AppCopy.t("Ouvrir le portail web", en: "Open web portal"),
                destination: URL(string: "https://useprocess.xyz/affiliate")!
            )
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.7 : 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func money(cents: Int, currency: String = "EUR") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "\(cents)"
    }

    private func savePaypal() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await AffiliateRemoteService.syncProfile(
                paypalEmail: paypalEmail,
                payoutMethod: "paypal"
            )
            statusMessage = AppCopy.t("PayPal enregistré.", en: "PayPal saved.")
            await store.reload()
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
