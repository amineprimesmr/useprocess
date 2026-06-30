import AVFoundation
import Foundation
import Speech

@MainActor
final class CoachSpeechTranscriber {
    static let shared = CoachSpeechTranscriber()

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr_FR"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private(set) var isRecording = false
    private var latestTranscript = ""
    private var committedTranscript = ""
    private var meterTask: Task<Void, Never>?

    /// Niveau audio lissé (0…1) — réagit à la voix en temps réel.
    private(set) var audioLevel: CGFloat = 0
    /// Historique des niveaux pour la waveform (dernières ~32 mesures).
    private(set) var audioLevels: [CGFloat] = Array(repeating: 0.06, count: 32)

    private var rawLevel: CGFloat = 0
    private let levelSmoothing: CGFloat = 0.22
    private let waveformCapacity = 52

    /// Transcription partielle en cours d'enregistrement.
    var partialTranscript: String { latestTranscript }

    private init() {}

    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startRecording() throws {
        guard !isRecording else { return }
        guard speechRecognizer?.isAvailable == true else {
            throw CoachSpeechError.recognizerUnavailable
        }

        stopInternal(discard: true)

        try ProcessAudioSession.configureForVoiceCapture()

        latestTranscript = ""
        committedTranscript = ""
        resetMeter()

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        beginRecognitionRequest()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let level = Self.computeLevel(from: buffer)
            self.recognitionRequest?.append(buffer)
            Task { @MainActor in
                self.applyMeterLevel(level)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        startIdleMeterDecay()
    }

    func stopRecording() -> String {
        let captured = bestTranscriptSnapshot()
        stopInternal(discard: false)
        latestTranscript = ""
        committedTranscript = ""
        resetMeter()
        return captured
    }

    func cancelRecording() {
        stopInternal(discard: true)
        latestTranscript = ""
        committedTranscript = ""
        resetMeter()
    }

    private func bestTranscriptSnapshot() -> String {
        let live = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let committed = committedTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        if !committed.isEmpty { return committed }
        return ""
    }

    // MARK: - Recognition (continue jusqu'à arrêt manuel)

    private func beginRecognitionRequest() {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if #available(iOS 13, *) {
            request.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        }
        recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionEvent(result: result, error: error)
            }
        }
    }

    private func handleRecognitionEvent(result: SFSpeechRecognitionResult?, error: Error?) {
        guard isRecording else { return }

        if let result {
            let segment = result.bestTranscription.formattedString
            if result.isFinal {
                if !segment.isEmpty {
                    committedTranscript = mergeTranscript(committedTranscript, segment)
                }
                latestTranscript = committedTranscript
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(40))
                    guard self.isRecording else { return }
                    self.beginRecognitionRequest()
                }
            } else {
                latestTranscript = mergeTranscript(committedTranscript, segment)
            }
        }

        if error != nil, isRecording {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                guard self.isRecording else { return }
                self.beginRecognitionRequest()
            }
        }
    }

    private func mergeTranscript(_ base: String, _ addition: String) -> String {
        let trimmed = addition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        if base.isEmpty { return trimmed }
        if base.hasSuffix(trimmed) || trimmed.hasPrefix(base) { return trimmed }
        return base + " " + trimmed
    }

    // MARK: - Audio meter

    private func applyMeterLevel(_ level: CGFloat) {
        let normalized = min(max(level, 0), 1)
        rawLevel = rawLevel * (1 - levelSmoothing) + normalized * levelSmoothing
        audioLevel = rawLevel

        if audioLevels.count >= waveformCapacity {
            audioLevels.removeFirst()
        }
        audioLevels.append(max(rawLevel, 0.06))
    }

    private func resetMeter() {
        rawLevel = 0
        audioLevel = 0
        audioLevels = Array(repeating: 0.06, count: waveformCapacity)
    }

    private func startIdleMeterDecay() {
        meterTask?.cancel()
        meterTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled, isRecording else { break }
                if rawLevel > 0.02 {
                    rawLevel *= 0.88
                    audioLevel = rawLevel
                    if audioLevels.count >= waveformCapacity {
                        audioLevels.removeFirst()
                    }
                    audioLevels.append(max(rawLevel, 0.06))
                } else {
                    audioLevel = 0.06
                    if audioLevels.count >= waveformCapacity {
                        audioLevels.removeFirst()
                    }
                    audioLevels.append(0.06)
                }
            }
        }
    }

    nonisolated private static func computeLevel(from buffer: AVAudioPCMBuffer) -> CGFloat {
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        if let channel = buffer.floatChannelData?[0] {
            var sum: Float = 0
            for index in 0..<count {
                let sample = channel[index]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(count))
            return CGFloat(min(max(rms * 18, 0), 1))
        }

        if let channel = buffer.int16ChannelData?[0] {
            var sum: Float = 0
            for index in 0..<count {
                let sample = Float(channel[index]) / Float(Int16.max)
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(count))
            return CGFloat(min(max(rms * 18, 0), 1))
        }

        return 0
    }

    // MARK: - Teardown

    private func stopInternal(discard: Bool) {
        meterTask?.cancel()
        meterTask = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        ProcessAudioSession.endVoiceCaptureAndRestoreMixing()
    }
}

enum CoachSpeechError: LocalizedError {
    case recognizerUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            "La dictée n'est pas disponible sur cet appareil."
        case .permissionDenied:
            "Autorise le micro et la reconnaissance vocale dans Réglages."
        }
    }
}
