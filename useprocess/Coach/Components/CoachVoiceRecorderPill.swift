import SwiftUI

// MARK: - Pilule vocale — durée illimitée, waveform réactive au micro

struct CoachVoiceRecorderPill: View {
    let elapsed: TimeInterval
    let audioLevel: CGFloat
    let audioLevels: [CGFloat]
    let transcript: String
    var isExiting: Bool = false
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false
    @State private var dragOffset: CGSize = .zero

    private let pillHeight: CGFloat = 118
    private let barCount = 28

    private var glowIntensity: CGFloat {
        min(max(audioLevel * 1.35 + 0.15, 0.12), 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            swipeHint

            pillCard
                .scaleEffect(1 + audioLevel * 0.018)
                .offset(x: dragOffset.width * 0.35, y: min(dragOffset.height * 0.2, 0))
                .gesture(dragGesture)
        }
        .padding(.horizontal, 12)
        .opacity(appeared && !isExiting ? 1 : 0)
        .scaleEffect(appeared && !isExiting ? 1 : 0.94, anchor: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                appeared = true
            }
            HapticManager.shared.impact(.light)
        }
        .onChange(of: isExiting) { _, exiting in
            guard exiting else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                appeared = false
            }
        }
    }

    private var swipeHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.up")
                .font(.system(size: 10, weight: .semibold))
            Text("Balayez vers le haut pour valider")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.45 : 0.38))
    }

    private var pillCard: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.2) / 2.2

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(baseGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(sweepGradient(phase: phase))
                            .blendMode(.plusLighter)
                            .opacity(0.55 + glowIntensity * 0.45)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.65),
                                        Color(red: 0.45, green: 0.85, blue: 0.95).opacity(0.35 + glowIntensity * 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: Color(red: 0.35, green: 0.62, blue: 0.98).opacity(0.18 + glowIntensity * 0.28),
                        radius: 14 + glowIntensity * 16,
                        y: 6
                    )

                VStack(spacing: 8) {
                    HStack {
                        recordingDot
                        Text(formattedElapsed)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.primary.opacity(0.55))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    liveWaveform
                        .padding(.horizontal, 14)

                    if !transcript.isEmpty {
                        Text(transcript)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.88))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .animation(.easeOut(duration: 0.12), value: transcript)
                    }

                    controlsRow
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                }
            }
            .frame(height: pillHeight)
        }
    }

    private var recordingDot: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 7, height: 7)
            .overlay {
                Circle()
                    .stroke(Color.red.opacity(0.45), lineWidth: 2)
                    .scaleEffect(1 + audioLevel * 0.9)
                    .opacity(0.35 + audioLevel * 0.5)
            }
    }

    private var liveWaveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                let level = barLevel(at: index)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(barGradient(level: level))
                    .frame(width: 4, height: barHeight(level: level))
                    .animation(.spring(response: 0.18, dampingFraction: 0.62), value: level)
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
    }

    private func barLevel(at index: Int) -> CGFloat {
        let samples = audioLevels
        guard !samples.isEmpty else { return 0.08 }
        let sampleIndex = min(
            max(Int(CGFloat(index) / CGFloat(barCount) * CGFloat(samples.count)), 0),
            samples.count - 1
        )
        let sample = samples[sampleIndex]
        let centerBoost = 1 - abs(CGFloat(index) - CGFloat(barCount) / 2) / (CGFloat(barCount) / 2) * 0.25
        return min(max(sample * centerBoost + audioLevel * 0.12, 0.08), 1)
    }

    private func barHeight(level: CGFloat) -> CGFloat {
        8 + level * 28
    }

    private func barGradient(level: CGFloat) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.38, green: 0.58, blue: 0.98).opacity(0.55 + level * 0.45),
                Color(red: 0.22, green: 0.82, blue: 0.78).opacity(0.65 + level * 0.35),
                Color(red: 0.55, green: 0.92, blue: 0.62).opacity(0.75 + level * 0.25)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var controlsRow: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)

            Text("Glisser vers la gauche pour annuler")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(red: 0.28, green: 0.52, blue: 0.96))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.primary, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var formattedElapsed: String {
        let total = max(Int(elapsed), 0)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var baseGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.68, green: 0.80, blue: 0.99),
                Color(red: 0.74, green: 0.93, blue: 0.90),
                Color(red: 0.88, green: 0.98, blue: 0.94)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func sweepGradient(phase: Double) -> LinearGradient {
        let shift = phase * 1.5 - 0.25
        return LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color(red: 0.55, green: 0.88, blue: 1.0).opacity(0.35 + Double(glowIntensity) * 0.35),
                Color.white.opacity(0.65),
                Color(red: 0.45, green: 0.95, blue: 0.72).opacity(0.25 + Double(glowIntensity) * 0.3),
                Color.white.opacity(0)
            ],
            startPoint: UnitPoint(x: shift, y: 0.5),
            endPoint: UnitPoint(x: shift + 0.5, y: 0.5)
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let t = value.translation
                if t.height < -72 {
                    HapticManager.shared.impact(.medium)
                    onConfirm()
                } else if t.width < -72 {
                    HapticManager.shared.impact(.light)
                    onCancel()
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    dragOffset = .zero
                }
            }
    }
}
