import SwiftUI
import UIKit

/// Avatar identité Profil — boucle du premier scan visage (création de compte).
struct ProfileFirstScanAvatar: View {
    var size: CGFloat = 152
    var isPlaybackActive: Bool = true
    var initials: String = "?"

    @Environment(\.appTheme) private var theme
    @Bindable private var scanStore = FaceScanHistoryStore.shared

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
                ZStack {
                    Circle()
                        .fill(ProfileTheme.avatarAccent)
                    Text(String(initials.prefix(1)).uppercased())
                        .font(.system(size: size * 0.38, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(theme.cardStroke.opacity(0.55), lineWidth: 0.75)
        }
        .accessibilityLabel("Premier scan visage")
        .onAppear(perform: refresh)
        .onChange(of: scanStore.history.count) { _, _ in
            refresh()
        }
        .onChange(of: isPlaybackActive) { _, active in
            guard active else { return }
            refresh()
        }
    }

    private func refresh() {
        guard let resolved = scanStore.oldestResultForProfileIdentity() else {
            videoURL = nil
            snapshot = nil
            return
        }
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: resolved)
        videoURL = FaceScanImageStore.resolvedVideoURL(for: reconciled)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            snapshot = FaceScanImageStore.load(filename: filename)
        } else {
            snapshot = nil
        }
    }
}
