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

    @State private var featuredPlayer: AVPlayer?
    @State private var resolvedVideoURL: URL?
    @State private var resolvedSnapshot: UIImage?
    @State private var mediaRefreshToken = 0

    var body: some View {
        Group {
            if let url = resolvedVideoURL {
                switch displayMode {
                case .featured:
                    VideoPlayer(player: featuredPlayer)
                        .onAppear {
                            guard featuredPlayer == nil else { return }
                            let player = AVPlayer(url: url)
                            featuredPlayer = player
                            player.play()
                        }
                        .onDisappear {
                            featuredPlayer?.pause()
                            featuredPlayer = nil
                        }
                case .thumbnail, .sidePanel:
                    FaceScanVideoLoopView(url: url)
                }
            } else if let image = resolvedSnapshot {
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
        .modifier(FaceScanMediaCornerClip(radius: cornerRadius))
        .id("\(result.id)-\(displayMode)-\(mediaRefreshToken)")
        .onAppear(perform: refreshResolvedMedia)
        .onChange(of: result.id) { _, _ in
            refreshResolvedMedia()
        }
        .onChange(of: result.videoFilename) { _, _ in
            refreshResolvedMedia()
        }
        .onChange(of: result.snapshotFilename) { _, _ in
            refreshResolvedMedia()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshResolvedMedia()
        }
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

    private func refreshResolvedMedia() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
        resolvedVideoURL = FaceScanImageStore.resolvedVideoURL(for: reconciled)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            resolvedSnapshot = FaceScanImageStore.load(filename: filename)
        } else {
            resolvedSnapshot = nil
        }
        if resolvedVideoURL == nil, resolvedSnapshot == nil {
            mediaRefreshToken &+= 1
        }
    }
}

private struct FaceScanMediaCornerClip: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        if radius > 0 {
            content.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content
        }
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
            if configuredURL == url, let player {
                view.setPlayer(player)
                view.resumePlaybackIfNeeded()
                return
            }

            teardown(from: view)

            let queuePlayer = AVQueuePlayer()
            queuePlayer.isMuted = true
            queuePlayer.automaticallyWaitsToMinimizeStalling = false

            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
            player = queuePlayer
            configuredURL = url

            view.setPlayer(queuePlayer)
            view.resumePlaybackIfNeeded()
        }

        func teardown(from view: FaceScanVideoLoopContainerView) {
            player?.pause()
            looper?.disableLooping()
            view.clearPlayer()
            looper = nil
            player = nil
            configuredURL = nil
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
        if playerLayer?.player === player {
            playerLayer?.frame = bounds
            return
        }

        playerLayer?.removeFromSuperlayer()

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        layer.frame = bounds
        self.layer.addSublayer(layer)
        playerLayer = layer
    }

    func clearPlayer() {
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    func resumePlaybackIfNeeded() {
        guard bounds.width > 1, bounds.height > 1, let player = playerLayer?.player else { return }
        if player.rate == 0 {
            player.play()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
        resumePlaybackIfNeeded()
    }
}
