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
            } else if chronologicalScans.count == 1, let scan = chronologicalScans.first {
                ProfileScanHistorySlide(
                    scan: scan,
                    size: size,
                    isPlaybackActive: isPlaybackActive
                )

                Text(scanDateLabel(scan.createdAt))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .monospacedDigit()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(chronologicalScans) { scan in
                            ProfileScanHistorySlide(
                                scan: scan,
                                size: size,
                                isPlaybackActive: isPlaybackActive && focusedScanID == scan.id
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .containerRelativeFrame(.horizontal)
                            .id(scan.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
                .scrollPosition(id: $focusedScanID)
                .frame(height: size)

                if let focused = chronologicalScans.first(where: { $0.id == focusedScanID }) {
                    Text(scanDateLabel(focused.createdAt))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                        .monospacedDigit()

                    scanPageIndicator(focused: focused)
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

    @ViewBuilder
    private func scanPageIndicator(focused: FaceScanResult) -> some View {
        let total = chronologicalScans.count
        if total > 1, let index = chronologicalScans.firstIndex(where: { $0.id == focused.id }) {
            HStack(spacing: 6) {
                ForEach(Array(chronologicalScans.enumerated()), id: \.element.id) { itemIndex, _ in
                    Capsule(style: .continuous)
                        .fill(
                            itemIndex == index
                                ? theme.primaryText.opacity(theme.isDark ? 0.88 : 0.72)
                                : theme.secondaryText.opacity(0.28)
                        )
                        .frame(width: itemIndex == index ? 16 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.22), value: index)
                }
            }
            .padding(.top, 2)

            Text(scanPositionLabel(for: focused))
                .font(.caption)
                .foregroundStyle(theme.secondaryText.opacity(0.82))
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
