import SwiftUI

struct FaceScanHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    let history: [FaceScanResult]
    var onSelect: ((FaceScanResult) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if history.isEmpty {
                        Text("Aucun scan enregistré.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, scan in
                            historyRow(scan, previous: history[safe: index + 1])
                        }
                    }
                }
                .padding()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Historique visage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func historyRow(_ scan: FaceScanResult, previous: FaceScanResult?) -> some View {
        let trend = previous.map { scan.delta(from: $0) }

        return Button {
            onSelect?(scan)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(scan.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    if scan.aiEnhanced {
                        Label("Claude", systemImage: "sparkles")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                FaceScanMetricsRow(markers: scan.markers, trend: trend, theme: theme)

                if let text = scan.claudeAnalysis {
                    let parsed = CoachEngine.parsedFaceAnalysis(for: scan)
                    let preview = parsed.summary.isEmpty
                        ? String(text.prefix(120)) + (text.count > 120 ? "…" : "")
                        : parsed.summary
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FaceScanRecordingMediaView(result: result, height: 260)

                    FaceScanMetricsRow(
                        markers: result.markers,
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
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Détail scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
