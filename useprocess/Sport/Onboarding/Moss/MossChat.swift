import SwiftUI
import UIKit

// ============================================================================
// MossChat — building blocks for the conversational onboarding.
//
// The shared visual vocabulary of the conversation: style constants for the
// depth-of-field message stack, wrapping answer chips in clear glass, and the
// pinned primary/ghost buttons. The typewriter itself lives in
// MossConversationEngine (one engine, adaptive pacing, tap-to-complete).
// Moss speaks in the display face over the forest; the user answers in an
// iMessage balloon — Apple's own grey and outline (see MossIMessage).
// ============================================================================

enum MossChatStyle {
    // Onboarding copy runs in the SYSTEM face — every sentence, question,
    // title and spoken line. GT Alpina is reserved for numerals alone (see
    // `numeral(_:)`). The system face sets wider than the condensed cut, so
    // copy steps down slightly; letterspacing stays native.
    static let displayScale: CGFloat = 0.92

    /// Onboarding prose: system font.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size * displayScale)
    }

    /// Display numerals only — GT Alpina Condensed Thin, at its design size.
    static func numeral(_ size: CGFloat) -> Font {
        Theme.Fonts.serif(size)
    }

    /// For value slots that carry either a figure or a phrase ("15 min" vs
    /// "Your chosen apps"): numerals get GT Alpina, pure words stay system.
    static func value(_ text: String, _ size: CGFloat) -> Font {
        text.contains(where: \.isNumber) ? numeral(size) : display(size)
    }

    static let mossFont = display(24)
    static let userFont = Theme.Fonts.sans(15, weight: .medium)

    /// How many recent messages stay on screen.
    static let windowSize = 4

    static func opacity(forDepth depth: Int) -> Double {
        depth <= 0 ? 1 : max(0, 1 - Double(depth) * 0.32)
    }

    /// Depth of field, the optical half: each step up the stack defocuses
    /// a little more, riding the same animation as the fade. The live line
    /// (depth 0) is always sharp — the typewriter never blurs.
    static func blur(forDepth depth: Int) -> CGFloat {
        depth <= 0 ? 0 : CGFloat(depth) * 1.5
    }

    /// Depth of field, the perspective half: each step up the stack recedes
    /// a little smaller. Kept gentle (4% per step) so receding lines stay
    /// legible mid-transition; the live line is always full size.
    static func scale(forDepth depth: Int) -> CGFloat {
        depth <= 0 ? 1 : max(0.82, 1 - CGFloat(depth) * 0.04)
    }
}

// MARK: - The iMessage balloon

/// Apple's own iMessage balloon, taken from the values ChatKit.framework
/// actually ships on iOS 26 rather than from a palette site. The catalog's
/// `CKGreenBalloonColor1` reads #34C759 — exactly Apple's systemGreen — which
/// is the tell that these are the real system values and not an eyedropper.
///
/// The two balloons are built differently, and it matters:
///
/// · The BLUE (outgoing) balloon is a two-stop vertical gradient, and in
///   Messages that gradient is anchored to the SCROLL VIEW rather than the
///   balloon — whichever sits nearest the composer renders at the deep stop
///   and the ones above lighten, which is why a long thread fades upward.
///
/// · The GREY (received) balloon is a single FLAT fill. There is no
///   Color0/Color1 pair for it anywhere in the catalog, so it never gradients.
///   Its one entry is `CKGrayBalloonColorLightMode`, light-mode only, and its
///   value is exactly systemGray5 — which is where the dark half comes from.
enum MossIMessage {
    /// CKBlueBalloonColor0 — the light stop, top.
    static let blue0Light = Color(hex: 0x5AC8FA)
    static let blue0Dark  = Color(hex: 0x409CFF)
    /// CKBlueBalloonColor1 — the deep stop, bottom.
    static let blue1Light = Color(hex: 0x0088FF)
    static let blue1Dark  = Color(hex: 0x0091FF)
    /// The outgoing balloon, kept for reference — MOSS uses the grey.
    static let blueBalloon = LinearGradient(colors: [blue0Dark, blue1Dark],
                                            startPoint: .top, endPoint: .bottom)

    /// CKGrayBalloonColorLightMode == systemGray5. Flat, both appearances.
    static let grayLight = Color(hex: 0xE5E5EA)
    static let grayDark  = Color(hex: 0x2C2C2E)

    /// MOSS is a pure-black surface end to end, so the dark value always wins;
    /// the light values are reference, not a light appearance.
    static let balloon = grayDark
    /// Apple sets balloon text in `label`, which is plain white on the dark
    /// grey — not an off-white, and not MOSS's warm Theme.ink.
    static let balloonInk = Color.white

    /// The template balloon is 55x35pt with cap insets top/bottom 17 — a
    /// 17.5pt corner, half the 35pt minimum height. Traced, the outline is
    /// FULLER at the tangent than a circular arc of that radius would be,
    /// which is precisely what `.continuous` draws.
    static let cornerRadius: CGFloat = 17.5
    /// The template's own minimum height, below which the corners would start
    /// distorting.
    static let minHeight: CGFloat = 35
}

/// The balloon body, no tail: a continuous rounded rectangle at the template's
/// 17.5pt corner. This is exactly ChatKit's own `bubble-tailless` outline —
/// traced, the two agree to 0.31% of area, which is the antialiasing floor.
///
/// Apple's tailless template keeps a 6pt reserve on its trailing edge purely so
/// a run of consecutive balloons lines up with the tailed one in the same
/// thread. MOSS has no tailed sibling to line up with, so the body fills its
/// frame instead of sitting 6pt shy of it.
struct MossBalloonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(MossIMessage.cornerRadius, rect.height / 2, rect.width / 2)
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

// MARK: - Answer chip

/// A selectable choice, native Liquid Glass. Both states use PROMINENT glass
/// (the frosted material) so the capsule is visible on pure black — a `.clear`
/// glass disappears with only black behind it. Unselected reads as a neutral
/// frosted pill; selected takes a white tint. The button style owns the whole
/// capsule: full hit area, the built-in fluid press. Selection haptic on tap.
/// A row of real App Store icons — the user's own apps, echoed back
/// wherever their choice reappears (reply bubble, review, plan, paywall).
struct MossAppIconRow: View {
    let urls: [URL]
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 6) {
            ForEach(urls.prefix(6), id: \.absoluteString) { url in
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24,
                                            style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct MossChip: View {
    let title: String
    var iconURL: URL? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            surface
        }
        // Native press response only (MossChipPress). Selection is a plain
        // white-fill fade — no scale overshoot, no custom land animation.
        .buttonStyle(MossChipPress())
        .animation(.smooth(duration: 0.2), value: isSelected)
        // One selection haptic per commitment, never on the sibling
        // deselecting.
        .sensoryFeedback(.selection, trigger: isSelected) { _, selected in
            selected
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var surface: some View {
        Group {
            if #available(iOS 26.0, *) {
                // The glass NEVER changes: one constant interactive surface in
                // both states, so press/release is purely the native fluid
                // effect — nothing re-resolves on selection (glass tint does
                // not interpolate; changing it snaps). Selection is a plain
                // white layer inside the capsule whose opacity fades — normal
                // SwiftUI, guaranteed smooth, riding the glass's own
                // spring-back instead of fighting it.
                label
                    .background {
                        Capsule(style: .continuous)
                            .fill(.white)
                            .opacity(isSelected ? 0.92 : 0)
                    }
                    .glassEffect(.regular.interactive(),
                                 in: Capsule(style: .continuous))
            } else {
                label
                    .background {
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.white.opacity(0.9)
                                             : Color.white.opacity(0.12))
                    }
            }
        }
        .contentShape(Capsule(style: .continuous))
    }

    private var label: some View {
        HStack(spacing: 8) {
            if let iconURL {
                AsyncImage(url: iconURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    // Reserve the footprint so the chip doesn't reflow when
                    // the icon lands.
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                }
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            Text(title)
                .font(Theme.Fonts.sans(15, weight: .medium))
                .foregroundStyle(isSelected ? .black : Theme.ink)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
    }
}

/// Pre-26 chips have no native press response; this gives every chip the
/// same restrained contact on any OS — a slight give, no bounce.
struct MossChipPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.18), value: configuration.isPressed)
    }
}

/// Entrance cascade: content settles in sequence — fade plus a small rise,
/// one beat apart — instead of arriving as a single block.
struct MossSettleIn: ViewModifier {
    let index: Int
    var stride: Double = 0.05

    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 6)
            .onAppear {
                if reduceMotion { shown = true; return }
                withAnimation(.smooth(duration: 0.32)
                    .delay(Double(index) * stride)) { shown = true }
            }
    }
}

extension View {
    func settleIn(_ index: Int, stride: Double = 0.05) -> some View {
        modifier(MossSettleIn(index: index, stride: stride))
    }
}

/// MossRecessedSurface — the record material (audit 6.4): evidence set
/// INTO the ground, never floating above it. Paper fill over the void, a
/// hairline that brightens toward the bottom, a soft inner top shade.
/// Recessed things cast no shadow, ever. The screen-blended aurora
/// suffuses the low-alpha fill from behind — that glow is the dampness;
/// never occlude it. Shared by review, mirror and trade.
struct MossRecessedSurface: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content.background {
            let shape = RoundedRectangle(cornerRadius: cornerRadius,
                                         style: .continuous)
            ZStack {
                shape.fill(Color(hex: 0xFCF8F5).opacity(0.06))
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.16), location: 0),
                        .init(color: .clear, location: 0.20),
                    ],
                    startPoint: .top, endPoint: .bottom)
                    .clipShape(shape)
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: 0xFCF8F5).opacity(0.05),
                                 Color(hex: 0xFCF8F5).opacity(0.13)],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 0.5)
            }
        }
    }
}

extension View {
    func mossRecessedSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(MossRecessedSurface(cornerRadius: cornerRadius))
    }
}

// MARK: - Footer buttons

/// The pinned primary: full-width white-tinted Liquid Glass, native press.
/// Dimmed while disabled.
struct MossChatPrimaryButton: View {
    let title: String
    /// The brand never renders as text: the CTA closes with the wordmark.
    var wordmarkSuffix: Bool = false
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) { label }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.white)
            } else {
                Button(action: action) { label.padding(.vertical, 17) }
                    .buttonStyle(.plain)
                    .background(Capsule(style: .continuous).fill(.white))
            }
        }
        .controlSize(.large)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private var label: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.Fonts.sans(16, weight: .semibold))
            if wordmarkSuffix {
                MossWordmark(height: 14, color: .black)
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
    }
}

/// The quiet secondary ("Later") beside a primary.
struct MossChatGhostButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.sans(15, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Wrapping layout for chip groups

/// A simple left-to-right wrapping layout (for chip rows).
struct MossFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight

        let width = maxWidth.isFinite ? maxWidth : usedWidth
        return CGSize(width: width, height: max(totalHeight, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Breathing arc

/// The onboarding's living light: a moss-green aurora arc resting at the
/// bottom edge, breathing slowly under the conversation. Ported from the
/// Rebuild onboarding's aurora background and retuned to MOSS's restraint —
/// one radial gradient drifting through the moss family, screen-blended
/// over the black, never louder than the words above it. Reduce Motion
/// holds it at mid-breath, still and calm.
struct MossBreathingArc: View {
    /// Anchor edge: the arc rises from the bottom by default; `.top`
    /// inverts it for surfaces that want the light overhead.
    enum Edge { case bottom, top }
    var edge: Edge = .bottom
    /// Overall presence multiplier — surfaces that carry their own light
    /// (the comparison chart) quiet the aurora rather than fight it.
    var intensity: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The moss family — luminous accent through deeper forest greens.
    private static let auroraColors: [Color] = [
        Color(red: 0.706, green: 0.839, blue: 0.604).opacity(0.85), // luminous moss
        Color(red: 0.612, green: 0.796, blue: 0.525).opacity(0.85),
        Color(red: 0.498, green: 0.710, blue: 0.420).opacity(0.85), // deep moss
        Color(red: 0.827, green: 0.910, blue: 0.753).opacity(0.80), // pale dew
        Color(red: 0.706, green: 0.839, blue: 0.604).opacity(0.85),
    ]

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                    paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                // The hue drifts across the family over ~a minute; the
                // breath swells on a slow ~10s cycle. Reduce Motion rests
                // at mid-breath.
                let phase = reduceMotion ? 0.3 : (sin(time * 0.1) + 1) / 2
                let breath = reduceMotion ? 0.5 : (sin(time * 0.6) + 1) / 2

                let scaled = phase * Double(Self.auroraColors.count - 1)
                let index = min(Int(scaled), Self.auroraColors.count - 2)
                let color = Self.interpolate(
                    from: Self.auroraColors[index],
                    to: Self.auroraColors[index + 1],
                    progress: scaled.truncatingRemainder(dividingBy: 1.0))

                RadialGradient(
                    colors: [
                        color,
                        color.opacity(0.45),
                        color.opacity(0.28),
                        color.opacity(0.16),
                        color.opacity(0.05),
                        .clear,
                    ],
                    center: .init(x: 0.5, y: edge == .bottom ? 1.0 : 0.0),
                    startRadius: 0,
                    endRadius: geometry.size.height * (0.40 + 0.10 * breath)
                )
                .offset(y: geometry.size.height
                        * (0.10 + 0.035 * breath)
                        * (edge == .bottom ? 1 : -1))
                // Constant blur: re-blurring a full screen every frame was
                // the arc's whole GPU bill. The breath now lives in scale
                // and opacity over one fixed softness.
                .blur(radius: 42)
                .scaleEffect(1 + 0.06 * breath,
                             anchor: edge == .bottom ? .bottom : .top)
                .opacity((0.30 + 0.14 * breath) * intensity)
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func interpolate(from: Color, to: Color, progress: Double) -> Color {
        let p = CGFloat(progress)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(from).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(to).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double((1 - p) * r1 + p * r2),
            green: Double((1 - p) * g1 + p * g2),
            blue: Double((1 - p) * b1 + p * b2),
            opacity: Double((1 - p) * a1 + p * a2))
    }
}
