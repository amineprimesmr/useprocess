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
                        title: "Apple Santé",
                        value: healthStatusLabel
                    )
                    GroupedSettingsRowDivider()

                    if !healthManager.isHealthDataAvailable {
                        Text("HealthKit n'est pas disponible sur cet appareil.")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                    } else if !healthManager.isAuthorized {
                        Text("Autorise l'accès à tes données pour alimenter le readiness, le protocole et le coach.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)

                        Button {
                            Task { await healthManager.requestAuthorizationAsync() }
                        } label: {
                            Text("Connecter Apple Santé")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.processPrimary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, GroupedSettingsMetrics.rowVerticalPadding)
                    } else {
                        Text("Données synchronisées depuis l'app Santé (iPhone, Apple Watch, apps tierces).")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)

                        if healthManager.hasAppleWatch {
                            GroupedSettingsRowDivider()
                            GroupedSettingsInfoRow(icon: "applewatch", title: "Apple Watch", value: "Connectée")
                        }

                        if let last = healthManager.lastSyncDate {
                            GroupedSettingsRowDivider()
                            GroupedSettingsInfoRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Dernière sync",
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
                            Text("Synchroniser maintenant")
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
        .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
        .navigationTitle("Sources connectées")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if healthManager.isAuthorized {
                await healthManager.refreshConnectedSources()
            }
        }
    }

    private var healthStatusLabel: String {
        if !healthManager.isHealthDataAvailable { return "Indisponible" }
        if healthManager.isAuthorized { return "Connecté" }
        return "Non connecté"
    }

    private var emptyMessage: String {
        "Aucune source détectée pour aujourd'hui."
    }

    private func sourceIcon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("watch") { return "applewatch" }
        if lower.contains("iphone") || lower.contains("phone") { return "iphone" }
        return "app.badge"
    }
}
