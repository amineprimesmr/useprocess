import SwiftUI
import UIKit

/// Carousel horizontal — tous les scans visage, du plus ancien au plus récent.
struct ProfileScanHistoryCarousel: View {
    var size: CGFloat = 132
    var isPlaybackActive: Bool = true
    var initials: String = "?"

    @Environment(\.appTheme) private var theme
    @Bindable private var scanStore = FaceScanHistoryStore.shared
    @State private var focusedScanID: String?

    private var chronologicalScans: [FaceScanResult] {
        scanStore.history.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 10) {
            if chronologicalScans.isEmpty {
                ProfileFirstScanAvatar(
                    size: size,
                    isPlaybackActive: isPlaybackActive,
                    initials: initials
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 18) {
                        ForEach(chronologicalScans) { scan in
                            ProfileScanHistorySlide(
                                scan: scan,
                                size: size,
                                isPlaybackActive: isPlaybackActive && focusedScanID == scan.id
                            )
                            .id(scan.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 28)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $focusedScanID)
                .frame(height: size)

                if let focused = chronologicalScans.first(where: { $0.id == focusedScanID }) {
                    Text(scanDateLabel(focused.createdAt))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .monospacedDigit()

                    if chronologicalScans.count > 1 {
                        Text(scanPositionLabel(for: focused))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText.opacity(0.82))
                    }
                }
            }
        }
        .onAppear(perform: syncFocusedScan)
        .onChange(of: scanStore.history.count) { _, _ in
            syncFocusedScan()
        }
        .onChange(of: isPlaybackActive) { _, active in
            guard active else { return }
            syncFocusedScan()
        }
    }

    private func syncFocusedScan() {
        guard !chronologicalScans.isEmpty else {
            focusedScanID = nil
            return
        }
        if let focusedScanID,
           chronologicalScans.contains(where: { $0.id == focusedScanID }) {
            return
        }
        focusedScanID = chronologicalScans.last?.id
    }

    private func scanDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func scanPositionLabel(for scan: FaceScanResult) -> String {
        guard let index = chronologicalScans.firstIndex(where: { $0.id == scan.id }) else {
            return ""
        }
        let position = index + 1
        let total = chronologicalScans.count
        return AppCopy.t(
            "Scan \(position) sur \(total)",
            en: "Scan \(position) of \(total)"
        )
    }
}

private struct ProfileScanHistorySlide: View {
    let scan: FaceScanResult
    let size: CGFloat
    let isPlaybackActive: Bool

    @Environment(\.appTheme) private var theme
    @State private var videoURL: URL?
    @State private var snapshot: UIImage?

    var body: some View {
        Group {
            if let videoURL {
                FaceScanSilentVideoLoopView(url: videoURL, isPlaybackActive: isPlaybackActive)
            } else if let snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(theme.cardBackgroundStrong.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(theme.cardStroke.opacity(0.55), lineWidth: 0.75)
        }
        .shadow(
            color: Color.black.opacity(theme.isDark ? 0.28 : 0.08),
            radius: 14,
            y: 8
        )
        .accessibilityLabel(scanDateAccessibilityLabel)
        .onAppear(perform: refreshMedia)
        .onChange(of: scan.id) { _, _ in
            refreshMedia()
        }
    }

    private var scanDateAccessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return AppCopy.t(
            "Scan du \(formatter.string(from: scan.createdAt))",
            en: "Scan from \(formatter.string(from: scan.createdAt))"
        )
    }

    private func refreshMedia() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: scan)
        videoURL = FaceScanImageStore.resolvedVideoURL(for: reconciled)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            snapshot = FaceScanImageStore.load(filename: filename)
        } else {
            snapshot = nil
        }
    }
}
