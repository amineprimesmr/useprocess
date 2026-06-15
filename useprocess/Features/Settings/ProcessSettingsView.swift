//
//  ProcessSettingsView.swift
//  useprocess
//
//  Paramètres — design MyFidPass (cartes groupées style Réglages iOS).
//

import SwiftUI
import UIKit

struct ProcessSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var session = AppSession.shared
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager

    @State private var showResetOnboardingConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                ProcessAccountSettingsSection()
                    .environmentObject(profileService)
                    .environmentObject(healthManager)

                processToolsCard

                ProcessAppSettingsHubView(embedInParentScroll: true)

                GroupedSettingsCard {
                    Button {
                        showResetOnboardingConfirm = true
                    } label: {
                        GroupedSettingsNavigationRow(
                            icon: "arrow.counterclockwise",
                            title: "Rejouer l'onboarding",
                            subtitle: "Recommencer le parcours d'accueil",
                            value: nil,
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
        .navigationTitle("Paramètres")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fermer") { dismiss() }
            }
        }
        .alert("Rejouer l'onboarding ?", isPresented: $showResetOnboardingConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Recommencer", role: .destructive) {
                session.resetOnboarding()
                dismiss()
            }
        } message: {
            Text("Tu reviendras au début du parcours d'accueil Process.")
        }
    }

    @ViewBuilder
    private var processToolsCard: some View {
        GroupedSettingsCard {
            NavigationLink {
                BodyScanHistoryTabContent()
            } label: {
                GroupedSettingsNavigationRow(
                    icon: "doc.text",
                    title: "Mes rapports de scan",
                    subtitle: "Historique posture et bien-être",
                    value: nil,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            GroupedSettingsRowDivider()

            Button {
                Task { await healthManager.performFullSync() }
            } label: {
                GroupedSettingsNavigationRow(
                    icon: "heart.text.square",
                    title: "Synchroniser Santé",
                    subtitle: healthManager.hasAppleWatch ? "Apple Watch connectée" : "Sources Apple Santé",
                    value: nil,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
    }
}

// MARK: - Compte (style AccountSettingsDetailView MyFidPass)

struct ProcessAccountSettingsSection: View {
    @EnvironmentObject private var profileService: UnifiedProfileService
    @EnvironmentObject private var healthManager: HealthManager

    var body: some View {
        GroupedSettingsCard {
            if let profile = profileService.currentProfile {
                GroupedSettingsInfoRow(
                    icon: "person.crop.circle",
                    title: "Nom",
                    value: profile.firstName.isEmpty ? "—" : [profile.firstName, profile.lastName].compactMap { $0 }.joined(separator: " ")
                )
                GroupedSettingsRowDivider()
                if let email = profile.email, !email.isEmpty {
                    GroupedSettingsInfoRow(icon: "envelope", title: "E-mail", value: email, valueLineLimit: 2)
                    GroupedSettingsRowDivider()
                }
            }

            GroupedSettingsInfoRow(
                icon: "waveform.path.ecg",
                title: "Forme du jour",
                value: "\(healthManager.readinessScore)/100 · \(healthManager.readinessLabel)"
            )
            GroupedSettingsRowDivider()

            if let score = BodyScanHistoryStore.shared.latestResult?.postureScore {
                GroupedSettingsInfoRow(icon: "figure.stand", title: "Dernier scan", value: "\(score)/100")
                GroupedSettingsRowDivider()
            }

            GroupedSettingsInfoRow(icon: "iphone", title: "Appareil", value: deviceLine)
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
    }

    private var deviceLine: String {
        "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
    }
}

/// Contenu historique scans (utilisé depuis Paramètres).
struct BodyScanHistoryTabContent: View {
    @Environment(\.appTheme) private var theme
    @Bindable private var historyStore = BodyScanHistoryStore.shared

    var body: some View {
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
