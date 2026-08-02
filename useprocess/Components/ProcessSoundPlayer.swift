import AVFoundation

/// Lecture courte d'effets sonores bundlés (validation, succès…).
@MainActor
enum ProcessSoundPlayer {
    private static var player: AVAudioPlayer?
    private static var playbackGeneration: UInt64 = 0

    static func playRevolutPaySuccess() {
        playBundledSound(named: "revolut_pay")
    }

    /// Versement d'eau — clip court, estompé pour coller à la montée du niveau.
    static func playPouringWater() {
        playBundledSound(
            named: "pouring_water",
            maxDuration: 0.72,
            fadeOutDuration: 0.28
        )
    }

    static func playBundledSound(
        named name: String,
        fileExtension: String = "mp3",
        maxDuration: TimeInterval? = nil,
        fadeOutDuration: TimeInterval = 0
    ) {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Resources/Sounds"
        ) ?? Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            return
        }

        playbackGeneration &+= 1
        let generation = playbackGeneration
        player?.stop()

        ProcessAudioSession.configureForEffectPlayback()

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.volume = 1
            audioPlayer.prepareToPlay()
            player = audioPlayer
            audioPlayer.play()

            if let maxDuration, maxDuration > 0 {
                Task { @MainActor in
                    let hold = max(0, maxDuration - fadeOutDuration)
                    if hold > 0 {
                        try? await Task.sleep(for: .seconds(hold))
                    }
                    guard generation == playbackGeneration, player === audioPlayer else { return }
                    await fadeOut(player: audioPlayer, duration: max(0.05, fadeOutDuration), generation: generation)
                }
            }
        } catch {
            player = nil
        }
    }

    private static func fadeOut(
        player audioPlayer: AVAudioPlayer,
        duration: TimeInterval,
        generation: UInt64
    ) async {
        let steps = 8
        let stepDuration = duration / Double(steps)
        for step in 1...steps {
            guard generation == playbackGeneration, player === audioPlayer else { return }
            audioPlayer.volume = Float(max(0, 1 - Double(step) / Double(steps)))
            try? await Task.sleep(for: .seconds(stepDuration))
        }
        guard generation == playbackGeneration, player === audioPlayer else { return }
        audioPlayer.stop()
        player = nil
    }
}
