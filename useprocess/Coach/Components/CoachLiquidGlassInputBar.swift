import SwiftUI
import UIKit

// MARK: - Barre liquid glass — texte et vocal partagent le même conteneur

struct CoachLiquidGlassInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var pendingImage: UIImage?
    var isDisabled: Bool = false
    var isRecording: Bool = false
    var isVoiceExiting: Bool = false
    var isAttachmentMenuOpen: Bool = false
    var voiceAudioLevel: CGFloat = 0
    var voiceAudioLevels: [CGFloat] = []

    var onSend: () -> Void
    var onStartVoice: () -> Void
    var onCancelVoice: () -> Void
    var onConfirmVoice: () -> Void
    var onOpenMenu: () -> Void
    var onRemovePendingImage: () -> Void

    private var trimmedEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        pendingImage != nil || !trimmedEmpty
    }

    private var showsVoiceContent: Bool {
        isRecording || isVoiceExiting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !showsVoiceContent, let pendingImage {
                pendingImagePreview(pendingImage)
            }

            Group {
                if showsVoiceContent {
                    voiceContent
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
                } else {
                    typingContent
                        .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .bottom)))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, pendingImage == nil || showsVoiceContent ? 10 : 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 84)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            guard !isDisabled, !showsVoiceContent else { return }
            isFocused = true
        }
        .modifier(CoachInputGlassModifier())
        .animation(ProcessGlass.spring, value: showsVoiceContent)
    }

    // MARK: - Texte

    @ViewBuilder
    private var typingContent: some View {
        TextField(
            "",
            text: $text,
            prompt: Text("Demander à Process")
                .foregroundStyle(Color.primary.opacity(0.38)),
            axis: .vertical
        )
        .lineLimit(1...6)
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(.primary)
        .focused($isFocused)
        .disabled(isDisabled)
        .submitLabel(.send)
        .onSubmit {
            if canSend {
                isFocused = false
                onSend()
            }
        }
        .frame(minHeight: 32, alignment: .topLeading)

        HStack(spacing: 8) {
            Button {
                HapticManager.shared.impact(.light)
                onOpenMenu()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .rotationEffect(.degrees(isAttachmentMenuOpen ? 45 : 0))
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isAttachmentMenuOpen)

            Spacer(minLength: 8)

            if canSend {
                Button {
                    HapticManager.shared.impact(.light)
                    isFocused = false
                    onSend()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(LiquidGlassPressStyle())
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.45 : 1)
            } else {
                Button {
                    HapticManager.shared.impact(.medium)
                    isFocused = false
                    onStartVoice()
                } label: {
                    Image(systemName: "mic")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.7))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            }
        }
    }

    // MARK: - Vocal (même emplacements : gauche / centre / droite)

    private var voiceContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoachVoiceWaveformDots(
                audioLevel: voiceAudioLevel,
                audioLevels: voiceAudioLevels
            )
            .frame(minHeight: 32)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                Button {
                    HapticManager.shared.impact(.light)
                    onCancelVoice()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.72))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Button {
                    HapticManager.shared.impact(.medium)
                    onConfirmVoice()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(LiquidGlassPressStyle())
            }
        }
    }

    private func pendingImagePreview(_ pendingImage: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: pendingImage)
                .resizable()
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                HapticManager.shared.impact(.light)
                onRemovePendingImage()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 20, height: 20)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
        }
        .padding(.top, 2)
    }
}

// MARK: - Waveform (contenu interne vocal)

struct CoachVoiceWaveformDots: View {
    let audioLevel: CGFloat
    let audioLevels: [CGFloat]

    private let dotCount = 40

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(dotColor(at: index))
                    .frame(width: 5, height: 5)
                    .scaleEffect(dotScale(at: index))
                    .animation(.spring(response: 0.16, dampingFraction: 0.68), value: audioLevel)
            }
        }
        .frame(height: 10)
    }

    private func dotLevel(at index: Int) -> CGFloat {
        let samples = audioLevels
        guard !samples.isEmpty else { return 0.06 }
        let sampleIndex = min(
            max(Int(CGFloat(index) / CGFloat(dotCount) * CGFloat(samples.count)), 0),
            samples.count - 1
        )
        let sample = samples[sampleIndex]
        let centerBoost = 1 - abs(CGFloat(index) - CGFloat(dotCount) / 2) / (CGFloat(dotCount) / 2) * 0.2
        return min(max(sample * centerBoost + audioLevel * 0.1, 0.06), 1)
    }

    private func dotColor(at index: Int) -> Color {
        let level = dotLevel(at: index)
        if level > 0.42 {
            return Color.primary.opacity(0.82 + Double(level) * 0.18)
        }
        return Color.primary.opacity(0.14 + Double(level) * 0.12)
    }

    private func dotScale(at index: Int) -> CGFloat {
        0.88 + dotLevel(at: index) * 0.28
    }
}

// MARK: - Liquid glass (même rendu que les chips du menu)

private struct CoachInputGlassModifier: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}

private struct LiquidGlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(ProcessGlass.pressSpring, value: configuration.isPressed)
    }
}
