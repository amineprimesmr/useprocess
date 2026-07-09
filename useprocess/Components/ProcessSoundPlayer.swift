import AVFoundation

/// Lecture courte d'effets sonores bundlés (validation, succès…).
@MainActor
enum ProcessSoundPlayer {
    private static var player: AVAudioPlayer?

    static func playRevolutPaySuccess() {
        playBundledSound(named: "revolut_pay")
    }

    static func playPouringWater() {
        playBundledSound(named: "pouring_water")
    }

    static func playBundledSound(named name: String, fileExtension: String = "mp3") {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: "Resources/Sounds"
        ) ?? Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            return
        }

        ProcessAudioSession.configureForEffectPlayback()

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            player = audioPlayer
            audioPlayer.play()
        } catch {
            player = nil
        }
    }
}
