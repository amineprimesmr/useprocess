import AVFoundation

/// Politique audio Process — ne jamais couper Spotify / Apple Music sauf dictée coach.
enum ProcessAudioSession {

    /// Par défaut : mix avec la musique en cours (accueil, vidéos muettes, caméra, AR).
    static func configureForMixingWithOthers() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Non bloquant — la session peut déjà être active.
        }
    }

    /// Réapplique le mode mix sauf pendant la dictée micro.
    @MainActor
    static func configureForMixingWithOthersIfIdle() {
        guard !CoachSpeechTranscriber.shared.isRecording else { return }
        configureForMixingWithOthers()
    }

    /// Dictée coach — duck la musique sans la stopper.
    static func configureForVoiceCapture() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.duckOthers, .defaultToSpeaker, .mixWithOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Fin dictée — relance la musique au volume normal.
    static func endVoiceCaptureAndRestoreMixing() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        configureForMixingWithOthers()
    }

    /// Lecteur vidéo sans piste audible (scans, previews).
    static func configurePlayerForSilentPlayback(_ player: AVPlayer) {
        player.isMuted = true
        player.volume = 0
        if #available(iOS 15.0, *) {
            player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
    }
}
