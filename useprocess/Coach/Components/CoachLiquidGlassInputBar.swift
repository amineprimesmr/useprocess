import SwiftUI
import UIKit

// MARK: - Barre de saisie coach
//
// iOS 26 : le bouton envoyer/micro DOIT être un sibling du glass passif (pas enfant),
// dans un GlassEffectContainer — sinon pas de press natif.

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

    private let barShape = RoundedRectangle(cornerRadius: 26, style: .continuous)
    private let actionButtonSize: CGFloat = 44
    private let horizontalPadding: CGFloat = 16
    private let bottomPadding: CGFloat = 10
    private let topPaddingDefault: CGFloat = 10
    private let topPaddingWithImage: CGFloat = 8

    private var trimmedEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        pendingImage != nil || !trimmedEmpty
    }

    private var showsVoiceContent: Bool {
        isRecording || isVoiceExiting
    }

    private var topPadding: CGFloat {
        pendingImage == nil || showsVoiceContent ? topPaddingDefault : topPaddingWithImage
    }

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                ios26Bar
            } else {
                legacyBar
            }
        }
    }

    // MARK: - iOS 26

    @available(iOS 26.0, *)
    private var ios26Bar: some View {
        GlassEffectContainer(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                passiveGlassSurface

                trailingGlassActionButton
                    .padding(.trailing, horizontalPadding)
                    .padding(.bottom, bottomPadding)
            }
        }
    }

    @available(iOS 26.0, *)
    private var passiveGlassSurface: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !showsVoiceContent, let pendingImage {
                pendingImagePreview(pendingImage)
            }

            if showsVoiceContent {
                voiceBody(includeTrailingAction: false)
            } else {
                typingBody(includeTrailingAction: false)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 84)
        .glassEffect(ProcessGlass.regularSurface, in: barShape)
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var trailingGlassActionButton: some View {
        if showsVoiceContent {
            barGlassCircleButton(systemName: "checkmark", iconSize: 16, haptic: .medium) {
                onConfirmVoice()
            }
        } else if canSend {
            barGlassCircleButton(systemName: "arrow.up", iconSize: 16) {
                onSend()
            }
            .disabled(isDisabled)
        } else {
            barGlassCircleButton(systemName: "mic", iconSize: 18, haptic: .medium) {
                isFocused = false
                onStartVoice()
            }
            .disabled(isDisabled)
        }
    }

    // MARK: - Legacy

    private var legacyBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !showsVoiceContent, let pendingImage {
                pendingImagePreview(pendingImage)
            }

            if showsVoiceContent {
                voiceBody(includeTrailingAction: true)
            } else {
                typingBody(includeTrailingAction: true)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 84)
        .background { legacyBarBackground }
    }

    // MARK: - Contenu

    @ViewBuilder
    private func typingBody(includeTrailingAction: Bool) -> some View {
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
            barIconButton(systemName: "plus", size: 22, opacity: 0.72) {
                onOpenMenu()
            }
            .rotationEffect(.degrees(isAttachmentMenuOpen ? 45 : 0))

            Spacer(minLength: 8)

            if includeTrailingAction {
                if canSend {
                    barGlassCircleButton(systemName: "arrow.up", iconSize: 16) {
                        onSend()
                    }
                    .disabled(isDisabled)
                } else {
                    barGlassCircleButton(systemName: "mic", iconSize: 18, haptic: .medium) {
                        isFocused = false
                        onStartVoice()
                    }
                    .disabled(isDisabled)
                }
            } else {
                Color.clear
                    .frame(width: actionButtonSize, height: actionButtonSize)
            }
        }
    }

    @ViewBuilder
    private func voiceBody(includeTrailingAction: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CoachVoiceWaveformDots(
                audioLevel: voiceAudioLevel,
                audioLevels: voiceAudioLevels
            )
            .frame(minHeight: 32)
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                barIconButton(systemName: "xmark", size: 22, opacity: 0.72) {
                    onCancelVoice()
                }

                Spacer(minLength: 8)

                if includeTrailingAction {
                    barGlassCircleButton(systemName: "checkmark", iconSize: 16, haptic: .medium) {
                        onConfirmVoice()
                    }
                } else {
                    Color.clear
                        .frame(width: actionButtonSize, height: actionButtonSize)
                }
            }
        }
    }

    // MARK: - Boutons

    private func barIconButton(
        systemName: String,
        size: CGFloat,
        opacity: Double = 1,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.impact(.light)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(Color.primary.opacity(opacity))
                .frame(width: actionButtonSize, height: actionButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func barGlassCircleButton(
        systemName: String,
        iconSize: CGFloat,
        haptic: UIImpactFeedbackGenerator.FeedbackStyle = .light,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.impact(haptic)
            isFocused = false
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .bold))
                .frame(width: actionButtonSize, height: actionButtonSize)
        }
        .modifier(CoachBarGlassCircleStyle())
    }

    @ViewBuilder
    private var legacyBarBackground: some View {
        barShape
            .fill(.ultraThinMaterial)
            .overlay(barShape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
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

private struct CoachBarGlassCircleStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
        } else {
            content.processGlassButton(in: Circle())
        }
    }
}

// MARK: - Waveform

struct CoachVoiceWaveformDots: View {
    let audioLevel: CGFloat
    let audioLevels: [CGFloat]

    private let dotCount = 20

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(dotColor(at: index))
                    .frame(width: 5, height: 5)
                    .scaleEffect(dotScale(at: index))
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
        let centerBoost = 1 - abs(CGFloat(index) / CGFloat(dotCount) - 0.5) / 0.5 * 0.2
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
