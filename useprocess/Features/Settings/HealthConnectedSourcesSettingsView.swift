import SwiftUI

struct HealthConnectedSourcesSettingsView: View {
    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupedSettingsCard {
                    GroupedSettingsInfoRow(
                        icon: "heart.text.square",
                        title: AppCopy.t("Apple Santé", en: "Apple Health"),
                        value: healthStatusLabel
                    )
                    GroupedSettingsRowDivider()

                    if !healthManager.isHealthDataAvailable {
                        Text(AppCopy.t("HealthKit n'est pas disponible sur cet appareil.", en: "HealthKit isn't available on this device."))
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                    } else if !healthManager.isAuthorized {
                        Text(AppCopy.t("Autorise l'accès à tes données pour alimenter le plan personnalisé et le coach.", en: "Allow access to your data to power your personalized plan and coach."))
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)

                        Button {
                            Task { await healthManager.requestAuthorizationAsync(analyticsSource: "health_sources_settings") }
                        } label: {
                            Text(AppCopy.t("Connecter Apple Santé", en: "Connect Apple Health"))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.processPrimary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, GroupedSettingsMetrics.rowVerticalPadding)
                    } else {
                        Text(AppCopy.t("Données synchronisées depuis l'app Santé (iPhone, Apple Watch, apps tierces).", en: "Data synced from the Health app (iPhone, Apple Watch, third-party apps)."))
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)

                        if healthManager.hasAppleWatch {
                            GroupedSettingsRowDivider()
                            GroupedSettingsInfoRow(icon: "applewatch", title: "Apple Watch", value: AppCopy.t("Connectée", en: "Connected"))
                        }

                        if let last = healthManager.lastSyncDate {
                            GroupedSettingsRowDivider()
                            GroupedSettingsInfoRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: AppCopy.t("Dernière sync", en: "Last Sync"),
                                value: last.formatted(date: .abbreviated, time: .shortened)
                            )
                        }
                    }
                }

                if healthManager.isAuthorized {
                    GroupedSettingsCard {
                        if healthManager.connectedSources.isEmpty {
                            Text(emptyMessage)
                                .font(.subheadline)
                                .foregroundStyle(theme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                        } else {
                            ForEach(Array(healthManager.connectedSources.enumerated()), id: \.offset) { index, source in
                                if index > 0 { GroupedSettingsRowDivider() }
                                HStack(spacing: 12) {
                                    Image(systemName: sourceIcon(for: source))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .frame(width: 28)
                                    Text(source)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                            }
                        }
                    }

                    Button {
                        Task { await healthManager.performFullSync() }
                    } label: {
                        HStack(spacing: 8) {
                            if healthManager.syncInProgress {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text(AppCopy.t("Synchroniser maintenant", en: "Sync Now"))
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.processPrimary)
                    .disabled(healthManager.syncInProgress)
                }
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .processTransparentScrollSurface()
        .navigationTitle(AppCopy.t("Sources connectées", en: "Connected Sources"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if healthManager.isAuthorized {
                await healthManager.refreshConnectedSources()
            }
        }
    }

    private var healthStatusLabel: String {
        if !healthManager.isHealthDataAvailable { return AppCopy.t("Indisponible", en: "Unavailable") }
        if healthManager.isAuthorized { return AppCopy.t("Connecté", en: "Connected") }
        return AppCopy.t("Non connecté", en: "Not Connected")
    }

    private var emptyMessage: String {
        AppCopy.t("Aucune source détectée pour aujourd'hui.", en: "No sources detected for today.")
    }

    private func sourceIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("watch") { return "applewatch" }
        if lower.contains("iphone") || lower.contains("phone") { return "iphone" }
        return "app.badge"
    }
}
