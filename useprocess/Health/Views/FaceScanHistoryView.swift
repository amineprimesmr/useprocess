import SwiftUI

struct FaceScanHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let history: [FaceScanResult]
    var isScanDue: Bool = false
    var onSelect: ((FaceScanResult) -> Void)?
    var onScan: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if history.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, scan in
                            historyCard(scan, previous: history[safe: index + 1])
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 108)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Historique visage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let onScan {
                    ProcessCoachFloatingPillButton(
                        title: scanButtonTitle,
                        leadingSystemImage: "camera.fill",
                        action: onScan
                    )
                    .padding(.horizontal, 20)
                    .safeAreaPadding(.bottom, 10)
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "face.smiling")
                .font(.system(size: 44))
                .foregroundStyle(theme.secondaryText.opacity(0.55))
                .padding(.top, 48)

            Text("Aucun scan enregistré")
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            Text("Chaque scan garde la vidéo et ton analyse debloat ici — lance ton premier scan pour commencer.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Card

    private func historyCard(_ scan: FaceScanResult, previous: FaceScanResult?) -> some View {
        let trend = previous.map { scan.delta(from: $0) }

        return Button {
            HapticManager.shared.impact(.light)
            onSelect?(scan)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                videoHeader(scan)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primaryText)

                            HStack(spacing: 8) {
                                Text(FaceWellnessScore.appreciation(for: scan).headline)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(theme.secondaryText)

                                if scan.aiEnhanced {
                                    Label("Claude", systemImage: "sparkles")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(theme.onboardingAccent)
                                }
                            }
                        }

                        Spacer(minLength: 8)

                        FaceWellnessAppreciationBadge(
                            appreciation: FaceWellnessScore.appreciation(for: scan),
                            theme: theme,
                            style: .compact
                        )
                    }

                    FaceScanMetricsRow(
                        markers: scan.markers,
                        relativeSignals: scan.relativeSignals,
                        trend: trend,
                        theme: theme
                    )

                    if let preview = analysisPreview(for: scan) {
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        Text("Voir le détail")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(theme.onboardingAccent)
                }
                .padding(14)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func videoHeader(_ scan: FaceScanResult) -> some View {
        ZStack(alignment: .bottomLeading) {
            FaceScanRecordingMediaView(
                result: scan,
                height: 210,
                displayMode: .thumbnail
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Vidéo du scan \(scan.createdAt.formatted(date: .abbreviated, time: .shortened))")

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            HStack {
                Label("Scan enregistré", systemImage: "video.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
            }
            .padding(12)
        }
        .frame(height: 210)
    }

    private var scanButtonTitle: String {
        if history.isEmpty {
            return "Faire mon premier scan"
        }
        if isScanDue {
            return "Faire un scan maintenant"
        }
        return "Faire un scan"
    }

    private func analysisPreview(for scan: FaceScanResult) -> String? {
        let parsed = CoachEngine.parsedFaceAnalysis(for: scan)
        if !parsed.summary.isEmpty {
            return parsed.summary
        }
        guard let raw = scan.claudeAnalysis, !raw.isEmpty else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 140 { return trimmed }
        return String(trimmed.prefix(140)) + "…"
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: theme.isDark ? 0 : 0.5)
            }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct FaceScanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let result: FaceScanResult
    var previous: FaceScanResult?

    private var appreciation: FaceWellnessScore.Appreciation {
        FaceWellnessScore.appreciation(for: result)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FaceScanRecordingMediaView(result: result, height: 280)

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                            if appreciation.headline != appreciation.displayText {
                                Text(appreciation.headline)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(theme.secondaryText)
                            }
                            if let confidence = result.scanConfidence {
                                Text("\(FaceWellnessScore.confidenceLabel(for: confidence)) · relatif à toi")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(theme.secondaryText)
                            }
                        }
                        Spacer()
                        FaceWellnessAppreciationBadge(
                            appreciation: appreciation,
                            theme: theme,
                            style: .prominent
                        )
                    }

                    FaceScanMetricsRow(
                        markers: result.markers,
                        relativeSignals: result.relativeSignals,
                        trend: previous.map { result.delta(from: $0) },
                        theme: theme
                    )

                    let analysis = CoachEngine.parsedFaceAnalysis(for: result)
                    if analysis.isValid {
                        FaceScanAnalysisCard(analysis: analysis, theme: theme)
                    } else if let raw = result.claudeAnalysis {
                        Text(raw)
                            .font(.subheadline)
                            .foregroundStyle(theme.primaryText)
                    }
                }
                .padding()
            }
            .processTransparentScrollSurface()
            .navigationTitle("Détail scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .processAppPageBackground()
    }
}
