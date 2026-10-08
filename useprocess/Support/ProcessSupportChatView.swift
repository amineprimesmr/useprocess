import SwiftUI

/// Support par email, sans fournisseur de chat tiers.
struct ProcessSupportChatView: View {
    var initialDraftMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.appTheme) private var theme

    private var emailURL: URL {
        var parts = URLComponents(url: ProcessLegalURLs.supportMail, resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "subject", value: "Process — Support")]
        if let initialDraftMessage, !initialDraftMessage.isEmpty {
            parts.queryItems?.append(URLQueryItem(name: "body", value: initialDraftMessage))
        }
        return parts.url ?? ProcessLegalURLs.supportMail
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "envelope").font(.system(size: 40))
                Text(AppCopy.t("Contacte notre équipe par email.", en: "Contact our team by email."))
                    .multilineTextAlignment(.center)
                Text(AppConfiguration.supportEmail).textSelection(.enabled)
                Button { openURL(emailURL) } label: {
                    Text(AppCopy.t("Écrire à l’assistance", en: "Email support"))
                }
                .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(theme.primaryText)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .processSettingsStandardToolbar(
                title: AppCopy.t("Assistance", en: "Support"),
                onBack: { dismiss() }
            )
            .processSettingsOpalPage()
        }
        .processAppPresentationBackground()
    }
}
