import SwiftUI
import UIKit

// MARK: - Barre liquid glass grande (style Grok — adaptatif clair/sombre)

struct CoachLiquidGlassInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var pendingImage: UIImage?
    var isDisabled: Bool = false
    var isRecording: Bool = false
    var isAttachmentMenuOpen: Bool = false

    var onSend: () -> Void
    var onStartVoice: () -> Void
    var onOpenMenu: () -> Void
    var onRemovePendingImage: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    private var trimmedEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        pendingImage != nil || !trimmedEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let pendingImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: pendingImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        HapticManager.shared.impact(.light)
                        onRemovePendingImage()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 22, height: 22)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -8)
                }
                .padding(.top, 2)
            }

            TextField(
                "",
                text: $text,
                prompt: Text("Demander à Process")
                    .foregroundStyle(Color.primary.opacity(0.38)),
                axis: .vertical
            )
            .lineLimit(1...6)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.primary)
            .focused($isFocused)
            .disabled(isDisabled || isRecording)
            .submitLabel(.send)
            .onSubmit {
                if canSend {
                    isFocused = false
                    onSend()
                }
            }
            .frame(minHeight: 44, alignment: .topLeading)

            HStack(spacing: 10) {
                glassCircleButton(imageName: "ProcessIA", size: 36) {
                    HapticManager.shared.impact(.light)
                    onOpenMenu()
                }
                .disabled(isDisabled)
                .rotationEffect(.degrees(isAttachmentMenuOpen ? 45 : 0))
                .animation(ProcessGlass.spring, value: isAttachmentMenuOpen)

                Spacer(minLength: 8)

                if canSend {
                    Button {
                        HapticManager.shared.impact(.light)
                        isFocused = false
                        onSend()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(isDark ? .black : .white)
                            .frame(width: 36, height: 36)
                            .background(isDark ? Color.white : Color.primary, in: Circle())
                    }
                    .buttonStyle(LiquidGlassPressStyle())
                    .disabled(isDisabled)
                } else {
                    Button {
                        guard !isRecording else { return }
                        HapticManager.shared.impact(.medium)
                        isFocused = false
                        onStartVoice()
                    } label: {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isRecording ? Color.red : Color.primary.opacity(0.7))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled || isRecording)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, pendingImage == nil ? 16 : 12)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: pendingImage == nil ? 112 : 168)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            guard !isDisabled, !isRecording else { return }
            isFocused = true
        }
        .modifier(CoachInputGlassModifier())
    }

    @ViewBuilder
    private func glassCircleButton(
        systemName: String? = nil,
        imageName: String? = nil,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: size * 0.82, height: size * 0.82)
                } else if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
            }
            .frame(width: size, height: size)
            .background {
                if imageName == nil {
                    Circle().fill(Color.primary.opacity(0.08))
                }
            }
        }
        .buttonStyle(.plain)
        .buttonStyle(LiquidGlassPressStyle())
    }
}

// MARK: - Liquid glass (même rendu que les chips du menu)

private struct CoachInputGlassModifier: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

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
