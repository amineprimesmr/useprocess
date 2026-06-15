import SwiftUI

// MARK: - Pill flottante enregistrement vocal (liquid glass — le blob est en overlay séparé)

struct CoachVoiceRecorderPill: View {
    let elapsed: TimeInterval
    let total: TimeInterval
    var isExiting: Bool = false
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var entrance: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0

    private let pillHeight: CGFloat = 76
    private let trackHeight: CGFloat = 8

    private var isDark: Bool { colorScheme == .dark }

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return min(max(elapsed / total, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let fullWidth = geo.size.width
            let minWidth = pillHeight
            let expand = easeOutCubic(entrance)
            let width = minWidth + (fullWidth - minWidth) * expand
            let centerBlend = smoothstep(edge0: 0.18, edge1: 0.78, x: entrance)
            let leadingX = (1 - centerBlend) * 0 + centerBlend * ((fullWidth - width) / 2)

            pillBody
                .frame(width: width, height: pillHeight, alignment: .leading)
                .offset(x: leadingX)
                .frame(width: fullWidth, height: pillHeight, alignment: .leading)
        }
        .frame(height: pillHeight)
        .onAppear { playEntrance() }
        .onChange(of: isExiting) { _, exiting in
            if exiting { playExit() }
        }
        .onTapGesture { onCancel() }
    }

    private var pillBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(CoachVoiceTimeFormat.elapsed(elapsed))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                Spacer(minLength: 0)
                Text(CoachVoiceTimeFormat.total(total))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(isDark ? Color.white.opacity(0.92) : Color.primary.opacity(0.88))

            GeometryReader { trackGeo in
                let trackW = trackGeo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(isDark ? Color.white.opacity(0.22) : Color.primary.opacity(0.18))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(isDark ? Color.white : Color.primary)
                        .frame(width: max(trackHeight, trackW * progress), height: trackHeight)
                        .animation(.linear(duration: 0.04), value: progress)
                }
            }
            .frame(height: trackHeight)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .opacity(contentOpacity)
        .modifier(CoachRecorderGlassModifier(isDark: isDark))
    }

    private func playEntrance() {
        entrance = 0
        contentOpacity = 0
        withAnimation(.interpolatingSpring(duration: 0.52, bounce: 0.14, initialVelocity: 0.55)) {
            entrance = 1
        }
        withAnimation(.easeOut(duration: 0.24).delay(0.08)) {
            contentOpacity = 1
        }
        HapticManager.shared.impact(.light)
    }

    private func playExit() {
        withAnimation(.easeIn(duration: 0.2)) {
            contentOpacity = 0
        }
        withAnimation(.interpolatingSpring(duration: 0.42, bounce: 0.06)) {
            entrance = 0
        }
    }

    private func easeOutCubic(_ t: CGFloat) -> CGFloat {
        let c = min(max(t, 0), 1)
        return 1 - pow(1 - c, 3)
    }

    private func smoothstep(edge0: CGFloat, edge1: CGFloat, x: CGFloat) -> CGFloat {
        guard edge1 > edge0 else { return x >= edge1 ? 1 : 0 }
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Glass flottant adaptatif

private struct CoachRecorderGlassModifier: ViewModifier {
    var isDark: Bool

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 26.0, *) {
                content.glassEffect(isDark ? ProcessGlass.dark : ProcessGlass.regular, in: Capsule(style: .continuous))
            } else {
                content
                    .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                    .background(
                        (isDark ? Color.black : Color(white: 0.25)).opacity(isDark ? 0.55 : 0.72),
                        in: Capsule(style: .continuous)
                    )
            }
        }
        .shadow(color: Color.black.opacity(isDark ? 0.32 : 0.18), radius: 24, y: 12)
        .shadow(color: Color.black.opacity(isDark ? 0.14 : 0.08), radius: 8, y: 4)
    }
}

// MARK: - Format temps (00:03,74 / 00:05)

enum CoachVoiceTimeFormat {
    static func elapsed(_ t: TimeInterval) -> String {
        let clamped = max(t, 0)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        let centis = Int((clamped.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d,%02d", minutes, seconds, centis)
    }

    static func total(_ t: TimeInterval) -> String {
        let clamped = max(t, 0)
        let minutes = Int(clamped) / 60
        let seconds = Int(clamped) % 60
        if abs(clamped - clamped.rounded()) < 0.01 {
            return String(format: "%02d:%02d", minutes, seconds)
        }
        let centis = Int((clamped.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d,%02d", minutes, seconds, centis)
    }
}
