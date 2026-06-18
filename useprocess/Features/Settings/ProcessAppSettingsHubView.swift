//
//  ProcessAppSettingsHubView.swift
//  useprocess
//
//  Hub paramètres app — design MyFidPass.
//

import SwiftUI
import SafariServices
import UIKit

struct ProcessAppSettingsHubView: View {
    @Environment(\.openURL) private var openURL
    @Bindable private var session = AppSession.shared

    var embedInParentScroll: Bool = false

    @State private var inAppSafariURL: URL?

    var body: some View {
        Group {
            if embedInParentScroll {
                appSettingsSectionsContent
                    .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            } else {
                ScrollView {
                    appSettingsSectionsContent
                        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
                .navigationTitle("Paramètres")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .sheet(isPresented: Binding(
            get: { inAppSafariURL != nil },
            set: { if !$0 { inAppSafariURL = nil } }
        )) {
            if let url = inAppSafariURL {
                ProcessInAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private var appearancePicker: some View {
        VStack(spacing: 0) {
            ForEach(Array(AppAppearance.allCases.enumerated()), id: \.element.id) { index, mode in
                if index > 0 { GroupedSettingsRowDivider() }
                Button {
                    session.setAppearance(mode)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: appearanceIcon(for: mode))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 28)
                        Text(mode.label)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        if session.appearance == mode {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.processPrimary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func appearanceIcon(for mode: AppAppearance) -> String {
        switch mode {
        case .system: "circle.lefthalf.filled"
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        }
    }

    private var appSettingsSectionsContent: some View {
        VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
            GroupedSettingsCard {
                appearancePicker
            }

            GroupedSettingsCard {
                GroupedSettingsInfoRow(
                    icon: "sparkles",
                    title: "Coach Claude",
                    value: ClaudeConfiguration.isConfigured ? "Connecté" : "Non configuré"
                )
                GroupedSettingsRowDivider()
                GroupedSettingsInfoRow(
                    icon: "network",
                    title: "Transport",
                    value: ClaudeConfiguration.transportLabel
                )
                GroupedSettingsRowDivider()
                GroupedSettingsInfoRow(
                    icon: "cpu",
                    title: "Modèle chat",
                    value: ClaudeModel.preferred(for: .chat).displayName
                )
            }

            GroupedSettingsCard {
                Button { inAppSafariURL = ProcessLegalURLs.termsOfUse } label: {
                    GroupedSettingsNavigationRow(
                        icon: "doc.text",
                        title: "Conditions d'utilisation",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                Button { inAppSafariURL = ProcessLegalURLs.privacyPolicy } label: {
                    GroupedSettingsNavigationRow(
                        icon: "hand.raised",
                        title: "Politique de confidentialité",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                Button { inAppSafariURL = ProcessLegalURLs.legalNotice } label: {
                    GroupedSettingsNavigationRow(
                        icon: "building.columns",
                        title: "Mentions légales",
                        subtitle: nil,
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }

            GroupedSettingsCard {
                NavigationLink {
                    ScrollView {
                        HealthMedicalSourcesView()
                            .padding(GroupedSettingsMetrics.horizontalPadding)
                            .padding(.vertical, 16)
                    }
                    .background(GroupedSettingsMetrics.pageBackground.ignoresSafeArea())
                    .navigationTitle("Sources santé")
                    .navigationBarTitleDisplayMode(.inline)
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "heart.text.square",
                        title: "Sources et références santé",
                        subtitle: "Citations des recommandations",
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }

            GroupedSettingsCard {
                Button { inAppSafariURL = ProcessLegalURLs.supportPage } label: {
                    GroupedSettingsNavigationRow(
                        icon: "questionmark.circle",
                        title: "Centre d'aide",
                        subtitle: "FAQ et assistance",
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                GroupedSettingsRowDivider()
                Button { openURL(ProcessLegalURLs.supportMail) } label: {
                    GroupedSettingsNavigationRow(
                        icon: "envelope.open",
                        title: "Contacter le support",
                        subtitle: "E-mail à l'équipe Process",
                        value: nil,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ProcessInAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewControllerWrapper {
        SFSafariViewControllerWrapper(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewControllerWrapper, context: Context) {}
}

private final class SFSafariViewControllerWrapper: UIViewController {
    init(url: URL) {
        super.init(nibName: nil, bundle: nil)
        let safari = SFSafariViewController(url: url)
        addChild(safari)
        view.addSubview(safari.view)
        safari.view.frame = view.bounds
        safari.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        safari.didMove(toParent: self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
