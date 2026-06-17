import AVKit
import SwiftUI

/// Aperçu du scan enregistré — vidéo caméra brute (sans mesh), repli sur photo si besoin.
struct FaceScanRecordingMediaView: View {
    let result: FaceScanResult
    var height: CGFloat = 260

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let url = resolvedVideoURL {
                VideoPlayer(player: player)
                    .onAppear {
                        let newPlayer = AVPlayer(url: url)
                        player = newPlayer
                        newPlayer.play()
                    }
                    .onDisappear {
                        player?.pause()
                        player = nil
                    }
            } else if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .overlay {
                        Label("Vidéo indisponible", systemImage: "video.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var resolvedVideoURL: URL? {
        guard let filename = result.videoFilename else { return nil }
        let url = FaceScanImageStore.videoFileURL(filename: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private var snapshotImage: UIImage? {
        guard let filename = result.snapshotFilename else { return nil }
        return FaceScanImageStore.load(filename: filename)
    }
}
