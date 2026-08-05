import SwiftUI

/// Liste des parrainages — statut En attente / Accepté.
struct ProcessReferralTrackingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = ProcessReferralStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if store.snapshot.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(store.snapshot.entries) { entry in
                                ProcessReferralTrackingRow(entry: entry)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
            .processTransparentScrollSurface()
            .navigationTitle(AppCopy.t("Suivre les parrainages", en: "Track Referrals"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProcessReferralToolbarButton(systemName: "xmark", action: { dismiss() })
                        .accessibilityLabel(AppCopy.close)
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .onAppear {
            store.reload(
                username: profileService.currentProfile?.username,
                userId: profileService.currentProfile?.userId
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(ProcessReferralTheme.textSecondary)

            Text(AppCopy.t("Aucun parrainage pour l'instant", en: "No Referrals Yet"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ProcessReferralTheme.textPrimary)

            Text(AppCopy.t("Partage ton lien — tes invités apparaîtront ici avec leur statut.", en: "Share your link — your invites will appear here with their status."))
                .font(.system(size: 14))
                .foregroundStyle(ProcessReferralTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProcessReferralTrackingRow: View {
    let entry: ProcessReferralEntry

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = ProcessAppLanguage.shared.locale
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.maskedName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)

                Text(AppCopy.t("Invité(e) le \(Self.dateFormatter.string(from: entry.invitedAt))", en: "Invited on \(Self.dateFormatter.string(from: entry.invitedAt))"))
                    .font(.system(size: 13))
                    .foregroundStyle(ProcessReferralTheme.textSecondary)
            }

            Spacer(minLength: 8)

            ProcessReferralStatusBadge(status: entry.status)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ProcessReferralTheme.cardBackground)
                .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        }
    }
}

struct ProcessReferralStatusBadge: View {
    let status: ProcessReferralEntryStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)

            Text(status.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor, in: Capsule())
    }

    private var dotColor: Color {
        status == .accepted ? Color(red: 0.2, green: 0.78, blue: 0.35) : Color.orange
    }

    private var textColor: Color {
        status == .accepted ? Color(red: 0.15, green: 0.55, blue: 0.28) : Color.orange
    }

    private var backgroundColor: Color {
        status == .accepted
            ? Color(red: 0.2, green: 0.78, blue: 0.35).opacity(0.14)
            : Color.orange.opacity(0.12)
    }
}
