import SwiftUI

/// Bulle utilisateur avec vidéo du scan visage + texte.
struct CoachFaceScanUserMessageView: View {
    let message: CoachMessage
    let result: FaceScanResult
    var profile: UnifiedUserProfile?
    var font: Font
    var lineSpacing: CGFloat
    var bubbleColor: Color
    var textColor: Color
    var onLongPress: (CGRect) -> Void

    @State private var bubbleFrame: CGRect = .zero

    private var displayText: String {
        CoachFaceScanMessageMarker.displayText(from: message.text)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 48)

            CoachUserThoughtBubbleBody(bubbleColor: bubbleColor) {
                VStack(alignment: .leading, spacing: 10) {
                    FaceScanRecordingMediaView(result: result, height: 168)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if !displayText.isEmpty {
                        Text(displayText)
                            .font(font)
                            .foregroundStyle(textColor)
                            .lineSpacing(lineSpacing)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { bubbleFrame = proxy.frame(in: .global) }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in
                            bubbleFrame = frame
                        }
                }
            }
            .overlay {
                CoachBubbleLongPressDetector { globalFrame in
                    let frame = globalFrame.width > 1 ? globalFrame : bubbleFrame
                    guard frame.width > 1, frame.height > 1 else { return }
                    HapticManager.shared.impact(.medium)
                    onLongPress(frame)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            CoachThoughtBubbleTailView(color: bubbleColor)
                .padding(.leading, -7)

            CoachUserChatAvatarView(
                profile: profile,
                bubbleColor: bubbleColor,
                textColor: textColor
            )
        }
        .transition(
            .opacity
                .combined(with: .offset(y: 10))
                .combined(with: .scale(scale: 0.98, anchor: .bottomTrailing))
        )
    }
}
