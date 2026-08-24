import CoreHaptics
import SwiftUI
import UIKit

// ============================================================================
// MossConversationEngine — the one typewriter for the whole conversation.
//
// The typewriter is central to MOSS's identity: slow enough to feel
// intentional, tactile, intimate, cinematic. Every Moss line in onboarding
// types through this engine so the rules hold everywhere:
//
//   · deliberate pacing by role — standard lines breathe, ceremonial lines
//     linger, longer explanations move a little quicker (after being
//     shortened first);
//   · meaningful punctuation rhythm and real breathing room after each line
//     (longer after emotional reflections);
//   · a felt typewriter — a low-intensity haptic texture synchronized with
//     the visible glyphs (MossTypeHaptics below), never keyboard clicks;
//   · a tap completes the CURRENT line only: never skips a screen, fires a
//     CTA, starts the next message, or selects an answer underneath;
//   · answer controls arrive gently after the question has landed;
//   · layout is reserved before animation — glyphs reveal inside a stable
//     text frame, nothing reflows, nothing jumps;
//   · Reduce Motion keeps the sequencing and drops the character animation
//     and its haptics;
//   · completed messages persist — returning from the keyboard, StoreKit,
//     Health, Screen Time, or the picker never replays them.
// ============================================================================

// MARK: - Typing profiles

enum MossTypingProfile {
    /// Questions and normal statements.
    case standard
    /// Longer explanatory copy (shorten first; this only softens the rest).
    case explanatory

    var millisPerCharacter: Double {
        switch self {
        case .standard: 18
        case .explanatory: 14
        }
    }
}

/// One Moss message, script-defined.
struct MossLine: Equatable {
    /// Stable identifier — analytics and resume use this, never the text.
    let id: String
    let text: String
    var profile: MossTypingProfile = .standard
    /// Emotional lines get a deeper completion pulse and a longer silence
    /// before the conversation moves on.
    var emotional: Bool = false

    init(_ id: String, _ text: String,
         profile: MossTypingProfile = .standard,
         emotional: Bool = false) {
        self.id = id
        self.text = text
        self.profile = profile
        self.emotional = emotional
    }
}

// MARK: - Engine

@MainActor
@Observable
final class MossConversationEngine {

    enum Sender: Equatable { case moss, user }

    struct Message: Identifiable, Equatable {
        let id: String
        let text: String
        let sender: Sender
        /// Characters currently revealed (== text.count when done).
        var revealed: Int
        var done: Bool
        /// Real App Store icons riding with a user reply — their own apps,
        /// shown as themselves instead of a plain name list.
        var iconURLs: [URL] = []
    }

    /// Breathing room after a normal line completes.
    static let breathMillis = 165
    /// Breathing room after an emotional reflection.
    static let emotionalBreathMillis = 320
    /// Silence between a user's answer landing and the next Moss line.
    static let postReplyMillis = 140

    private(set) var messages: [Message] = []
    /// True while any line is still revealing — the tap-catcher's signal.
    private(set) var isTyping = false
    /// The whole batch has landed and breathed — answer controls may fade
    /// in. Never true while a line is still revealing.
    private(set) var controlsVisible = false

    /// Honors Reduce Motion: sequencing stays, characters appear at once.
    var reduceMotion = false
    /// VoiceOver: the typewriter is 8-14 seconds of dead air to a blind
    /// user. Lines land instantly and are spoken as announcements instead;
    /// per-glyph haptics stay off, completion pulses stay.
    var assistiveVoice = false

    private var pump: Task<Void, Never>?
    private var queue: [MossLine] = []
    private var batchDone: (() -> Void)?
    private var currentStarted: Date?
    /// Set when the user tap-completes the in-flight line.
    private var completeRequested = false
    /// The next batch waits this long before its first glyph (set when the
    /// previous event was a user reply).
    private var pendingLeadIn = 0

    // MARK: Speaking

    /// Queue a batch of Moss lines. `instant` renders them fully displayed
    /// (resume after interruption — continuity over theatrical replay).
    func speak(_ lines: [MossLine], instant: Bool = false,
               onBatchDone: (() -> Void)? = nil) {
        guard !lines.isEmpty else { onBatchDone?(); return }
        batchDone = onBatchDone

        if instant || reduceMotion || assistiveVoice {
            for line in lines {
                messages.append(Message(id: line.id, text: line.text,
                                        sender: .moss,
                                        revealed: line.text.count, done: true))
            }
            if assistiveVoice, !instant { announce(lines) }
            finishBatch()
            return
        }

        // Les CTA n’apparaissent qu’une fois le batch entièrement tapé.
        controlsVisible = false
        queue.append(contentsOf: lines)
        startPumpIfNeeded()
    }

    /// The user's reply becomes a compact bubble; the conversation breathes,
    /// then continues.
    func userReplied(_ text: String, icons: [URL] = []) {
        guard !text.isEmpty else { return }
        messages.append(Message(id: "user.\(messages.count)", text: text,
                                sender: .user, revealed: text.count, done: true,
                                iconURLs: icons))
    }

    /// Tap-to-complete: finishes the current line immediately. Never skips
    /// queued lines; never performs any other action.
    func completeCurrent() {
        guard isTyping else { return }
        completeRequested = true
    }

    /// Stop the typewriter so an answer can land immediately.
    func stopSpeaking() {
        pump?.cancel()
        pump = nil
        queue.removeAll()
        if let index = messages.indices.last {
            var message = messages[index]
            if !message.done {
                message.revealed = message.text.count
                message.done = true
                messages[index] = message
            }
        }
        isTyping = false
        controlsVisible = true
        completeRequested = false
        pendingLeadIn = 0
        let done = batchDone
        batchDone = nil
        done?()
    }

    /// Drop everything (leaving the conversation entirely).
    func reset() {
        pump?.cancel()
        pump = nil
        queue.removeAll()
        messages.removeAll()
        isTyping = false
        controlsVisible = false
        batchDone = nil
    }

    // MARK: Pump

    private func startPumpIfNeeded() {
        guard pump == nil else { return }
        isTyping = true
        // A reply just landed — let it sit before Moss answers.
        if messages.last?.sender == .user { pendingLeadIn = Self.postReplyMillis }
        pump = Task { [weak self] in
            await self?.drainQueue()
        }
    }

    private func drainQueue() async {
        if pendingLeadIn > 0 {
            try? await Task.sleep(for: .milliseconds(pendingLeadIn))
            pendingLeadIn = 0
        }
        while !queue.isEmpty, !Task.isCancelled {
            let line = queue.removeFirst()
            await type(line)
            // The conversation breathes after every line, longer after an
            // emotional one; the final line's breath runs before controls
            // become interactive, keeping the landing unhurried.
            let breath = line.emotional ? Self.emotionalBreathMillis : Self.breathMillis
            try? await Task.sleep(for: .milliseconds(breath))
        }
        pump = nil
        isTyping = false
        finishBatch()
    }

    private func type(_ line: MossLine) async {
        completeRequested = false
        currentStarted = .now
        MossAnalytics.log("typewriter_started", ["message": line.id])
        MossTypeHaptics.shared.prepare()

        var message = Message(id: line.id, text: line.text, sender: .moss,
                              revealed: 0, done: false)
        messages.append(message)
        let index = messages.count - 1

        let characters = Array(line.text)
        let delays = Self.delays(for: line)
        var completedByTap = false

        // Absolute deadlines with sliced sleeps: the reveal never drifts
        // from its authored pace, and a tap-to-complete lands within ~12ms
        // instead of waiting out a punctuation pause or emotional breath.
        let clock = ContinuousClock()
        var deadline = clock.now
        typing: for position in characters.indices {
            if Task.isCancelled { return }
            if completeRequested {
                completedByTap = true
                break
            }
            message.revealed = position + 1
            messages[index] = message
            // The glyph and its pulse arrive together — the felt typewriter.
            MossTypeHaptics.shared.character(characters[position])
            deadline += .milliseconds(delays[position])
            while clock.now < deadline {
                if completeRequested {
                    completedByTap = true
                    break typing
                }
                let remaining = clock.now.duration(to: deadline)
                try? await Task.sleep(for: min(remaining, .milliseconds(12)))
            }
        }

        message.revealed = characters.count
        message.done = true
        messages[index] = message
        MossTypeHaptics.shared.completion(emotional: line.emotional)

        let latency = currentStarted.map { Int(Date.now.timeIntervalSince($0) * 1000) } ?? 0
        MossAnalytics.log(
            completedByTap ? "typewriter_completed_by_tap" : "typewriter_completed_naturally",
            ["message": line.id, "latency_ms": "\(latency)"])
    }

    /// Speak the batch through VoiceOver, one line at a time, high
    /// priority so a stale system utterance never buries Moss's voice.
    private func announce(_ lines: [MossLine]) {
        Task { @MainActor in
            for (index, line) in lines.enumerated() {
                if index > 0 { try? await Task.sleep(for: .milliseconds(200)) }
                var text = AttributedString(line.text)
                text.accessibilitySpeechAnnouncementPriority = .high
                AccessibilityNotification.Announcement(text).post()
            }
        }
    }

    private func finishBatch() {
        controlsVisible = true
        let done = batchDone
        batchDone = nil
        done?()
    }

    // MARK: Pacing math

    /// Per-character delays: the profile's deliberate base rate plus a
    /// meaningful breath at punctuation. No global speed cap — long copy is
    /// shortened at the script level, not rushed at the renderer.
    static func delays(for line: MossLine) -> [Double] {
        let characters = Array(line.text)
        guard !characters.isEmpty else { return [] }
        let base = line.profile.millisPerCharacter
        var delays = characters.map { _ in base }
        for (index, character) in characters.enumerated() {
            switch character {
            case ",": delays[index] += 26
            case ".", "?", "!": delays[index] += 58
            case "\n": delays[index] += 115
            default: break
            }
        }
        return delays
    }
}

// MARK: - The felt typewriter

/// A dedicated low-intensity haptic texture synchronized with the visible
/// glyphs — soft organic ticks, faint drops of water. Never keyboard clicks,
/// never a notification machine. CoreHaptics transients per glyph; devices
/// without the hardware degrade to a sparse soft tick.
@MainActor
final class MossTypeHaptics {
    static let shared = MossTypeHaptics()

    private let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var engineRunning = false
    private let fallback = UIImpactFeedbackGenerator(style: .soft)
    private var fallbackCounter = 0

    private init() {}

    /// Warm the engine before a line begins so the first glyph is felt.
    func prepare() {
        guard supported else { fallback.prepare(); return }
        if engine == nil {
            engine = try? CHHapticEngine()
            engine?.playsHapticsOnly = true
            engine?.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engineRunning = false }
            }
            engine?.resetHandler = { [weak self] in
                Task { @MainActor in self?.engineRunning = false }
            }
        }
        startIfNeeded()
    }

    private func startIfNeeded() {
        guard let engine, !engineRunning else { return }
        do {
            try engine.start()
            engineRunning = true
        } catch {
            engineRunning = false
        }
    }

    /// One glyph, one pulse. Spaces and breaks stay silent; capitals press a
    /// touch firmer; commas accent; periods land clearly.
    func character(_ character: Character) {
        guard !character.isWhitespace else { return }
        let intensity: Float
        let sharpness: Float
        switch character {
        case ",":
            (intensity, sharpness) = (0.32, 0.30)
        case ".", "?", "!":
            (intensity, sharpness) = (0.46, 0.42)
        default:
            if character.isUppercase {
                (intensity, sharpness) = (0.30, 0.38)
            } else {
                (intensity, sharpness) = (0.17, 0.34)
            }
        }
        transient(intensity: intensity, sharpness: sharpness)
    }

    /// The line has landed — one grounded pulse, deeper when it mattered.
    func completion(emotional: Bool) {
        transient(intensity: emotional ? 0.62 : 0.42,
                  sharpness: emotional ? 0.28 : 0.34)
    }

    private func transient(intensity: Float, sharpness: Float) {
        guard supported else {
            // Sparse soft tick where CoreHaptics doesn't exist — texture
            // over machinery, never a buzz per glyph.
            fallbackCounter += 1
            if fallbackCounter % 4 == 0 {
                fallback.impactOccurred(intensity: CGFloat(max(0.3, intensity)))
            }
            return
        }
        startIfNeeded()
        guard engineRunning, let engine else { return }
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ], relativeTime: 0)
        if let pattern = try? CHHapticPattern(events: [event], parameters: []),
           let player = try? engine.makePlayer(with: pattern) {
            try? player.start(atTime: 0)
        }
    }
}

// MARK: - Stable-layout typed text

/// Renders a message inside its FINAL text frame: the full string is always
/// laid out, unrevealed glyphs are simply clear. No reflow, no line-height
/// jumps, no shifting buttons while text appears.
struct MossTypedText: View {
    let message: MossConversationEngine.Message

    var body: some View {
        Text(attributed)
            .accessibilityLabel(message.text)
    }

    private var attributed: AttributedString {
        var string = AttributedString(message.text)
        guard !message.done, message.revealed < message.text.count else { return string }
        let characters = string.characters
        if let cut = characters.index(characters.startIndex, offsetBy: message.revealed,
                                      limitedBy: characters.endIndex) {
            string[cut...].foregroundColor = .clear
        }
        return string
    }
}

/// A conversation message routed by sender — Moss in serif over the dark,
/// the user in a compact capsule of clear Liquid Glass.
struct MossConversationBubble: View {
    let message: MossConversationEngine.Message

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.sender == .user { Spacer(minLength: 56) }

            content
                .multilineTextAlignment(message.sender == .user ? .trailing : .leading)
                .frame(maxWidth: .infinity,
                       alignment: message.sender == .user ? .trailing : .leading)

            if message.sender == .moss { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.sender {
        case .moss:
            mossMessageText

        case .user:
            VStack(alignment: .trailing, spacing: 7) {
                if !message.iconURLs.isEmpty {
                    MossAppIconRow(urls: message.iconURLs)
                }
                Text(message.text)
                    .font(MossChatStyle.userFont)
                    .foregroundStyle(MossIMessage.balloonInk)
            }
            .padding(.vertical, message.iconURLs.isEmpty ? 10 : 12)
            .padding(.horizontal, 16)
            .frame(minHeight: MossIMessage.minHeight)
            .background(MossIMessage.balloon, in: MossBalloonShape())
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var mossMessageText: some View {
        let text = MossTypedText(message: message)
            .font(MossChatStyle.mossFont)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)

        if colorScheme == .dark {
            text
                .shadow(color: .black.opacity(0.8), radius: 10, y: 1)
                .shadow(color: .black.opacity(0.5), radius: 24, y: 2)
        } else {
            text
        }
    }
}
