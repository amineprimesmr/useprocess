import SwiftUI

/// Liste des parrainages — statut En attente / Accepté.
struct ProcessReferralTrackingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var store = ProcessReferralStore.shared

    var body: some View {
        ZStack {
            ProcessReferralTheme.pageBackground.ignoresSafeArea()

            Group {
                if store.snapshot.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(store.snapshot.entries) { entry in
                                ProcessReferralTrackingRow(entry: entry)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            ProcessReferralCircleIconButton(systemName: "xmark") { dismiss() }
                .padding(.leading, 22)
                .padding(.top, 12)
                .accessibilityLabel(AppCopy.close)
        }
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

            Text(AppCopy.t(
                "Partage ton code — tes invités apparaîtront ici avec leur statut.",
                en: "Share your code — your invites will appear here with their status."
            ))
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
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.maskedName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ProcessReferralTheme.textPrimary)

                Text(AppCopy.t(
                    "Invité(e) le \(Self.dateFormatter.string(from: entry.invitedAt))",
                    en: "Invited on \(Self.dateFormatter.string(from: entry.invitedAt))"
                ))
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
                .fill(ProcessReferralTheme.surface)
        }
    }
}
