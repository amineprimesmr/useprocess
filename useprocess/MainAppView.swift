import SwiftUI

struct MainAppView: View {
    @Bindable private var session = AppSession.shared
    @Environment(\.appTheme) private var theme

    var body: some View {
        TabView {
            CoachChatView()
                .tabItem {
                    Label("Coach", systemImage: "sparkles")
                }

            HealthDashboardView()
                .tabItem {
                    Label("Santé", systemImage: "heart.text.square.fill")
                }

            BodyScanRootView()
                .tabItem {
                    Label("Scan", systemImage: "viewfinder")
                }

            BodyScanHistoryTab()
                .tabItem {
                    Label("Rapports", systemImage: "doc.text")
                }

            ProfileTabView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
        }
        .tint(theme.primaryText)
    }
}

private struct BodyScanHistoryTab: View {
    @Environment(\.appTheme) private var theme
    @Bindable private var historyStore = BodyScanHistoryStore.shared

    var body: some View {
        NavigationStack {
            List {
                if historyStore.history.isEmpty {
                    ContentUnavailableView(
                        "Aucun rapport",
                        systemImage: "doc.text",
                        description: Text("Fais un scan pour générer ton premier rapport.")
                    )
                } else {
                    ForEach(historyStore.history) { result in
                        NavigationLink {
                            BodyScanReportView(result: result) {}
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Score \(result.postureScore)/100")
                                    .font(.headline)
                                Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rapports")
        }
    }
}

private struct ProfileTabView: View {
    @Bindable private var session = AppSession.shared
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            List {
                if let profile = profileService.currentProfile {
                    Section("Compte") {
                        LabeledContent("Prénom", value: profile.firstName.isEmpty ? "—" : profile.firstName)
                        if let score = BodyScanHistoryStore.shared.latestResult?.postureScore {
                            LabeledContent("Dernier score posture", value: "\(score)/100")
                        }
                    }
                }

                Section("Santé") {
                    LabeledContent("Readiness", value: "\(healthManager.readinessScore)/100")
                    LabeledContent("HRV baseline", value: healthManager.baselines.hrv > 0
                        ? String(format: "%.0f ms", healthManager.baselines.hrv) : "—")
                    LabeledContent("Sommeil moyen", value: healthManager.baselines.sleepNeedHours > 0
                        ? String(format: "%.1f h", healthManager.baselines.sleepNeedHours) : "—")
                    LabeledContent("Apple Watch", value: healthManager.hasAppleWatch ? "Connectée" : "Non détectée")
                    LabeledContent("Sources", value: "\(healthManager.connectedSources.count)")
                }

                Section("Application") {
                    Button("Rejouer l'onboarding") {
                        session.resetOnboarding()
                    }
                    .foregroundStyle(.red)

                    Button("Resynchroniser Santé") {
                        Task { await healthManager.performFullSync() }
                    }
                }

                Section("Intelligence Claude") {
                    LabeledContent("Transport", value: ClaudeConfiguration.transportLabel)
                    LabeledContent(
                        "Statut",
                        value: ClaudeConfiguration.isConfigured ? "Connecté" : "Non configuré"
                    )
                    LabeledContent("Modèle chat", value: ClaudeModel.preferred(for: .chat).displayName)
                    LabeledContent("Modèle scan", value: ClaudeModel.preferred(for: .bodyScanReport).displayName)
                }
            }
            .navigationTitle("Profil")
        }
    }
}
