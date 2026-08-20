import SwiftUI

/// Hub parrainage — layout Opal pixel-perfect.
struct ProcessReferralProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = ProcessReferralStore.shared
    @State private var showShareSheet = false

    var body: some View {
        ProcessReferralProgramScreen(
            store: store,
            showsBackButton: true,
            onBack: { dismiss() },
            showShareSheet: $showShareSheet
        )
        .onAppear { reloadStore() }
    }

    private func reloadStore() {
        store.reload(
            username: profileService.currentProfile?.username,
            userId: profileService.currentProfile?.userId
        )
    }
}

/// Page parrainage depuis Paramètres (navigation push).
struct ProcessReferralProgramDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = ProcessReferralStore.shared
    @State private var showShareSheet = false

    var body: some View {
        ProcessReferralProgramScreen(
            store: store,
            showsBackButton: true,
            onBack: { dismiss() },
            showShareSheet: $showShareSheet
        )
        .onAppear {
            store.reload(
                username: profileService.currentProfile?.username,
                userId: profileService.currentProfile?.userId
            )
        }
    }
}

// MARK: - Screen

private enum ProcessReferralProgramScrollAnchor {
    static let metalCard = "referral_metal_card"
    static let progress = "referral_progress"
}

private struct ProcessReferralProgramScreen: View {
    @Bindable var store: ProcessReferralStore
    let showsBackButton: Bool
    let onBack: () -> Void
    @Binding var showShareSheet: Bool

    var body: some View {
        ZStack {
            ProcessReferralTheme.pageBackground
                .ignoresSafeArea()

            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        ProcessReferralInviteHeadline()

                        ProcessReferralEngravedMetalCard(
                            code: store.displayReferralCode,
                            copyText: store.referralLink
                        )
                        .id(ProcessReferralProgramScrollAnchor.metalCard)

                        ProcessReferralOpalProgressText(acceptedCount: store.snapshot.acceptedCount)
                            .padding(.top, 8)
                            .id(ProcessReferralProgramScrollAnchor.progress)

                        ProcessReferralGlassShareButton(
                            title: AppCopy.t("Partager l’invitation", en: "Share invitation")
                        ) {
                            HapticManager.shared.impact(.medium)
                            ProcessAnalytics.trackReferralShareOpened(source: "referral_program")
                            showShareSheet = true
                        }
                        .padding(.top, 24)

                        ProcessReferralGlassSocialShareRow(
                            shareMessage: store.shareMessage,
                            link: store.referralLink
                        )
                        .padding(.top, 22)

                        ProcessReferralHowItWorksSection {
                            withAnimation(.smooth(duration: 0.35)) {
                                scrollProxy.scrollTo(
                                    ProcessReferralProgramScrollAnchor.progress,
                                    anchor: .center
                                )
                            }
                        }

                        Color.clear.frame(height: 32)
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
        .preferredColorScheme(.dark)
        .processSettingsScrollToolBar(
            title: AppCopy.t("Récompenses", en: "Rewards"),
            titleAlignment: .center,
            showsBackButton: showsBackButton,
            onBack: onBack
        )
        .sheet(isPresented: $showShareSheet) {
            ProfileShareSheet(items: [store.shareMessage])
        }
        .task {
            await store.refreshDashboard()
        }
        .refreshable {
            await store.refreshDashboard()
        }
    }
}

// MARK: - Theme

enum ProcessReferralTheme {
    static let pageBackground = Color.black
    static let surface = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let cardBackground = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let chipBackground = Color(white: 0.14)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.45)
}

struct ProcessReferralStatusBadge: View {
    let status: ProcessReferralEntryStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)

            Text(status.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(backgroundColor, in: Capsule())
    }

    private var dotColor: Color {
        status == .accepted ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color.orange
    }

    private var textColor: Color {
        status == .accepted ? Color(red: 0.55, green: 0.95, blue: 0.65) : Color.orange.opacity(0.95)
    }

    private var backgroundColor: Color {
        status == .accepted
            ? Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.16)
            : Color.orange.opacity(0.14)
    }
}

// MARK: - Legacy

struct ProcessReferralStatusSection: View {
    let entries: [ProcessReferralEntry]

    var body: some View {
        EmptyView()
    }
}
