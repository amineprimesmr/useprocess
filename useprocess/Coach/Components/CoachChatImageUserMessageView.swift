import SwiftUI

/// Bulle utilisateur avec photo(s) au-dessus du texte.
struct CoachChatImageUserMessageView: View {
    let message: CoachMessage
    let images: [UIImage]
    var profile: UnifiedUserProfile?
    var font: Font
    var lineSpacing: CGFloat
    var bubbleColor: Color
    var textColor: Color
    var onLongPress: (CGRect) -> Void

    @State private var bubbleFrame: CGRect = .zero

    private var displayText: String {
        CoachChatImageMessageMarker.displayText(from: message.text)
    }

    private var showsDisplayText: Bool {
        let text = displayText
        guard !text.isEmpty else { return false }
        return !CoachChatImageMessageMarker.isPlaceholderDisplayText(text)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 48)

            CoachUserThoughtBubbleBody(bubbleColor: bubbleColor) {
                VStack(alignment: .leading, spacing: 10) {
                    attachmentImages

                    if showsDisplayText {
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

    @ViewBuilder
    private var attachmentImages: some View {
        if images.count == 1, let image = images.first {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if images.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}
