import AVKit
import SwiftUI

/// Aperçu du scan enregistré — vidéo caméra brute (sans mesh), repli sur photo si besoin.
struct FaceScanRecordingMediaView: View {
    let result: FaceScanResult
    var height: CGFloat = 260
    var displayMode: DisplayMode = .featured

    enum DisplayMode {
        case featured
        case thumbnail
        case sidePanel
    }

    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let url = resolvedVideoURL {
                switch displayMode {
                case .featured:
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
                case .thumbnail, .sidePanel:
                    FaceScanVideoLoopView(url: url)
                }
            } else if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(height: displayMode == .sidePanel ? nil : height)
        .frame(maxWidth: usesFullWidth ? .infinity : nil)
        .frame(maxHeight: displayMode == .sidePanel ? .infinity : nil)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var usesFullWidth: Bool {
        displayMode == .featured || displayMode == .sidePanel
    }

    private var cornerRadius: CGFloat {
        switch displayMode {
        case .thumbnail: 10
        case .featured: 14
        case .sidePanel: 0
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.08))
            .overlay {
                Label("Vidéo indisponible", systemImage: "video.slash")
                    .font(displayMode == .thumbnail ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
            }
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

private struct FaceScanVideoLoopView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> FaceScanVideoLoopContainerView {
        let view = FaceScanVideoLoopContainerView()
        context.coordinator.attach(to: view, url: url)
        return view
    }

    func updateUIView(_ uiView: FaceScanVideoLoopContainerView, context: Context) {
        context.coordinator.attach(to: uiView, url: url)
    }

    static func dismantleUIView(_ uiView: FaceScanVideoLoopContainerView, coordinator: Coordinator) {
        coordinator.teardown(from: uiView)
    }

    final class Coordinator {
        private var looper: AVPlayerLooper?
        private var player: AVQueuePlayer?
        private var configuredURL: URL?

        func attach(to view: FaceScanVideoLoopContainerView, url: URL) {
            guard configuredURL != url else { return }
            teardown(from: view)

            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true
            queuePlayer.automaticallyWaitsToMinimizeStalling = false

            looper = AVPlayerLooper(player: queuePlayer, templateItem: AVPlayerItem(url: url))
            player = queuePlayer
            configuredURL = url

            view.setPlayer(queuePlayer)
            queuePlayer.play()
        }

        func teardown(from view: FaceScanVideoLoopContainerView) {
            player?.pause()
            looper?.disableLooping()
            looper = nil
            player = nil
            configuredURL = nil
            view.clearPlayer()
        }
    }
}

private final class FaceScanVideoLoopContainerView: UIView {
    private var playerLayer: AVPlayerLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        clipsToBounds = true
        layer.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPlayer(_ player: AVPlayer) {
        playerLayer?.removeFromSuperlayer()

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        playerLayer = layer
    }

    func clearPlayer() {
        playerLayer?.player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
