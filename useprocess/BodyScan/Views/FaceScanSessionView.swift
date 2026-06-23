import SwiftUI

struct FaceScanSessionView: View {
    @EnvironmentObject private var profileService: UnifiedProfileService

    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void

    @State private var isProcessing = false
    @State private var completedResult: FaceScanResult?

    var body: some View {
        ZStack {
            FaceScanCaptureScreen(onBack: onDismiss) { payload, markers in
                Task { await process(payload: payload, markers: markers) }
            }

            if isProcessing {
                Color.black.opacity(0.62).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.1)
                    if ProcessPrivacyConsentStore.shared.canSendFacePhotoToAI {
                        Text("Analyse wellness en cours…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Comparaison avec tes scans précédents")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text("Enregistrement du scan…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Scores calculés localement sur ton appareil")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(24)
            }
        }
        .sheet(item: $completedResult) { result in
            FaceScanResultSheet(result: result) {
                onComplete(result)
            }
        }
    }

    private func process(payload: FaceScanCapturePayload, markers: FaceWellnessMarkers) async {
        isProcessing = true
        defer { isProcessing = false }

        let result = await FaceScanService.recordScan(
            payload: payload,
            markers: markers,
            profile: profileService.currentProfile
        )
        completedResult = result
    }
}

struct FaceScanResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.appTheme) private var theme

    let result: FaceScanResult
    var onDone: () -> Void

    private var isRegularWidth: Bool {
        AdaptiveScreenLayout.isRegularWidth(horizontalSizeClass)
    }

    private var mediaHeight: CGFloat {
        AdaptiveScreenLayout.mediaPreviewHeight(containerWidth: 520, isRegular: isRegularWidth)
    }

    private var analysis: FaceScanAnalysisContent {
        CoachEngine.parsedFaceAnalysis(for: result)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FaceScanRecordingMediaView(result: result, height: mediaHeight)

                    HStack(alignment: .center) {
                        Text(result.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                        Spacer()
                        FaceWellnessScoreBadge(
                            score: result.resolvedFaceDayScore,
                            theme: theme,
                            style: .compact
                        )
                    }

                    if let confidence = result.scanConfidence {
                        Text("\(FaceWellnessScore.confidenceLabel(for: confidence)) · score relatif à toi, pas à ta morphologie")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    FaceScanMetricsRow(
                        markers: result.markers,
                        relativeSignals: result.relativeSignals,
                        trend: nil,
                        theme: theme
                    )

                    if analysis.isValid {
                        FaceScanAnalysisCard(analysis: analysis, theme: theme)
                    } else if let raw = result.claudeAnalysis {
                        Text(raw)
                            .font(.subheadline)
                            .foregroundStyle(theme.primaryText)
                    } else {
                        Text("Analyse Claude indisponible — tes scores locaux sont enregistrés.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
                .padding()
                .regularWidthContainer(maxWidth: AdaptiveScreenLayout.faceScanColumnMaxWidth)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Scan enregistré")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminer") {
                        dismiss()
                        onDone()
                    }
                }
            }
        }
        .presentationDetents(isRegularWidth ? [.medium, .large] : [.large])
        .presentationDragIndicator(.visible)
    }
}
