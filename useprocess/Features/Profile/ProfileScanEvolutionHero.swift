import SwiftUI

/// Hero profil — dernier scan en rond, swipe chronologique pour voir l'évolution.
struct ProfileScanEvolutionHero: View {
    @Bindable var historyStore: FaceScanHistoryStore
    var onOpenScan: (FaceScanResult) -> Void

    @Environment(\.appTheme) private var theme

    @State private var selectedScanId: String?

    private let circleDiameter: CGFloat = 220

    /// Du plus ancien au plus récent — swipe vers la droite = scans plus récents.
    private var chronologicalScans: [FaceScanResult] {
        historyStore.history.reversed()
    }

    private var selectedScan: FaceScanResult? {
        guard let selectedScanId else { return chronologicalScans.last }
        return chronologicalScans.first(where: { $0.id == selectedScanId })
    }

    private var selectedIndex: Int {
        guard let selectedScanId,
              let index = chronologicalScans.firstIndex(where: { $0.id == selectedScanId }) else {
            return max(0, chronologicalScans.count - 1)
        }
        return index
    }

    var body: some View {
        VStack(spacing: 14) {
            if chronologicalScans.isEmpty {
                emptyState
            } else {
                scanCarousel
                scanMetadata
            }
        }
        .padding(.top, ProcessMainChromeMetrics.topSafeInset + 52)
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.bottom, 4)
        .onAppear(perform: syncSelectedScan)
        .onChange(of: historyStore.history.map(\.id)) { _, _ in
            syncSelectedScan()
        }
    }

    private var scanCarousel: some View {
        TabView(selection: $selectedScanId) {
            ForEach(chronologicalScans) { scan in
                Button {
                    HapticManager.shared.impact(.light)
                    onOpenScan(scan)
                } label: {
                    ProfileScanCircleMedia(result: scan, diameter: circleDiameter)
                }
                .buttonStyle(.plain)
                .tag(scan.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: circleDiameter + 12)
        .onChange(of: selectedScanId) { oldValue, newValue in
            guard oldValue != newValue, newValue != nil else { return }
            HapticManager.shared.selection()
        }
        .accessibilityLabel("Historique des scans visage")
        .accessibilityHint(chronologicalScans.count > 1 ? "Glisse pour voir l'évolution" : "")
    }

    private var scanMetadata: some View {
        VStack(spacing: 6) {
            if let scan = selectedScan {
                HStack(spacing: 8) {
                    Text(scanDateLabel(scan.createdAt))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    ReadinessScoreMiniBadge(score: scan.displayWellnessScore)
                }
            }

            if chronologicalScans.count > 1 {
                Text("\(selectedIndex + 1) sur \(chronologicalScans.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .monospacedDigit()

                Text("Glisse pour voir l'évolution")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.secondaryText.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.2), value: selectedScanId)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.55 : 0.35))
                    .frame(width: circleDiameter, height: circleDiameter)

                VStack(spacing: 8) {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(theme.onboardingAccent.opacity(0.85))

                    Text("Aucun scan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
            }

            Text("Fais ton premier scan depuis l'accueil pour suivre ton évolution.")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    private func syncSelectedScan() {
        guard !chronologicalScans.isEmpty else {
            selectedScanId = nil
            return
        }

        if let selectedScanId,
           chronologicalScans.contains(where: { $0.id == selectedScanId }) {
            return
        }

        selectedScanId = chronologicalScans.last?.id
    }

    private func scanDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "'Aujourd'hui,' HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'Hier,' HH:mm"
        } else {
            formatter.dateFormat = "d MMM yyyy"
        }
        return formatter.string(from: date)
    }
}

private struct ProfileScanCircleMedia: View {
    let result: FaceScanResult
    let diameter: CGFloat

    @Environment(\.appTheme) private var theme

    var body: some View {
        FaceScanRecordingMediaView(
            result: result,
            height: diameter,
            displayMode: .featured
        )
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(
                    Color.primary.opacity(theme.isDark ? 0.14 : 0.08),
                    lineWidth: 0.5
                )
        }
        .shadow(
            color: Color.black.opacity(theme.isDark ? 0.28 : 0.10),
            radius: 18,
            y: 8
        )
        .accessibilityLabel("Scan du \(result.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }
}
