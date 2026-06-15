import SwiftUI

struct BodyScanRootView: View {
    @Binding var selectedSection: ProcessMainSection
    var onOpenProfile: () -> Void

    @EnvironmentObject private var profileService: UnifiedProfileService
    @Environment(\.appTheme) private var theme
    @Bindable private var historyStore = BodyScanHistoryStore.shared

    @State private var showScanner = false
    @State private var showReport = false

    private var userId: String {
        AuthUser.current?.uid ?? profileService.currentProfile?.userId ?? "local-\(AppConfiguration.bundleIdentifier)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                if let result = historyStore.latestResult {
                    processMainScrollableChrome(
                        selectedSection: $selectedSection,
                        pageSection: .scan
                    ) {
                        VStack(spacing: 20) {
                            lastScanCard(result)

                            Button("Voir mon rapport") { showReport = true }
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(theme.background)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(theme.primaryText, in: RoundedRectangle(cornerRadius: 26))
                                .padding(.horizontal, 24)

                            Button("Nouveau scan") { showScanner = true }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(theme.primaryText)
                                .padding(.bottom, 8)
                        }
                        .padding(.vertical, 24)
                    }
                } else {
                    processMainScrollableChrome(
                        selectedSection: $selectedSection,
                        pageSection: .scan
                    ) {
                        emptyState
                            .frame(minHeight: 520)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showScanner) {
                BodyScanSessionView(
                    userId: userId,
                    profile: profileService.currentProfile,
                    showsCloseButton: true
                ) { _ in
                    showScanner = false
                }
            }
            .sheet(isPresented: $showReport) {
                if let result = historyStore.latestResult {
                    NavigationStack {
                        BodyScanReportView(result: result) {
                            showReport = false
                        }
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fermer") { showReport = false }
                            }
                        }
                    }
                }
            }
        }
        .task {
            await loadRemoteHistory()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(theme.primaryText.opacity(0.8))
            Text("Analyse ton corps en 360°")
                .font(.title2.bold())
                .foregroundStyle(theme.primaryText)
            Text("Posture, symétrie, visage et priorités musculaires personnalisées.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Lancer mon premier scan") { showScanner = true }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(theme.background)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(theme.primaryText, in: RoundedRectangle(cornerRadius: 26))
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
        }
    }

    private func lastScanCard(_ result: BodyScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dernier scan")
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            HStack {
                Text("Score \(result.postureScore)/100")
                    .font(.title.bold())
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Text(result.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            if result.aiEnhanced {
                Label("Analyse Claude", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.primaryText.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func loadRemoteHistory() async {
        guard AppConfiguration.firebaseConfigured,
              let uid = AuthUser.current?.uid else { return }
        if let latest = try? await BodyScanFirestoreRepository.shared.fetchLatest(userId: uid) {
            historyStore.push(latest)
        }
    }
}
