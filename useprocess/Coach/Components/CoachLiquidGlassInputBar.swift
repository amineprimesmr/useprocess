import SwiftUI
import UIKit

// MARK: - Barre liquid glass (style Grok — adaptatif clair/sombre)

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

    private var trimmedEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSend: Bool {
        pendingImage != nil || !trimmedEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let pendingImage {
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
            .disabled(isDisabled || isRecording)
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
                        guard !isRecording else { return }
                        HapticManager.shared.impact(.medium)
                        isFocused = false
                        onStartVoice()
                    } label: {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isRecording ? Color.red : Color.primary.opacity(0.7))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled || isRecording)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, pendingImage == nil ? 10 : 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: pendingImage == nil ? 84 : 140)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            guard !isDisabled, !isRecording else { return }
            isFocused = true
        }
        .modifier(CoachInputGlassModifier())
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
