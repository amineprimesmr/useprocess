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

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        latestTranscript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.latestTranscript = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal == true) {
                Task { @MainActor in
                    self.stopInternal(discard: false)
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() -> String {
        stopInternal(discard: false)
        let text = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        latestTranscript = ""
        return text
    }

    func cancelRecording() {
        stopInternal(discard: true)
        latestTranscript = ""
    }

    private func stopInternal(discard: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        if discard {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
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
