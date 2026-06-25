import SwiftUI

/// Accueil contextuel du coach — même rendu typewriter que le Protocole Origine.
struct CoachContextualHomeView: View {
    let prompt: CoachHomePrompt
    var startsComplete: Bool = false
    var onGreetingComplete: () -> Void

    @Environment(\.appTheme) private var theme
    @State private var typewriter = CoachTypewriterController()

    private let messageLineSpacing: CGFloat = 7
    private let horizontalPadding: CGFloat = 28

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                typewriterText
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, topContentPadding)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .mask(topFadeMask)
        }
        .task(id: presentationTaskID) {
            if startsComplete {
                typewriter.showImmediately(text: prompt.greetingText)
                return
            }
            await typewriter.run(text: prompt.greetingText)
            onGreetingComplete()
        }
    }

    private var presentationTaskID: String {
        "\(prompt.greetingText)|complete:\(startsComplete)"
    }

    private var topContentPadding: CGFloat {
        ProcessMainChromeMetrics.topSafeInset + 118
    }

    private var typewriterText: some View {
        ZStack(alignment: .topLeading) {
            Text(prompt.greetingText)
                .font(.system(size: OnboardingProfileChatDepthStyle.activeFontSize, weight: .regular))
                .foregroundStyle(.clear)
                .lineSpacing(messageLineSpacing)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)

            if !typewriter.displayedText.isEmpty {
                Text(typewriter.displayedText)
                    .font(.system(size: OnboardingProfileChatDepthStyle.activeFontSize, weight: .regular))
                    .foregroundStyle(theme.primaryText)
                    .lineSpacing(messageLineSpacing)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(nil, value: typewriter.displayedText)
    }

    private var topFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 110)
            Rectangle().fill(.black)
        }
    }
}
