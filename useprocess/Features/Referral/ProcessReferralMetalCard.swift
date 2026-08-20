import SwiftUI
import UIKit

// MARK: - Headline (style référence)

struct ProcessReferralInviteHeadline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppCopy.t("Invite tes amis.", en: "Invite friends."))
            Text(AppCopy.t("Gagne des récompenses.", en: "Get rewarded."))
        }
        .font(.system(size: 28, weight: .heavy))
        .foregroundStyle(ProcessReferralTheme.textPrimary)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

// MARK: - Carte métal gravée (code parrainage)

struct ProcessReferralEngravedMetalCard: View {
    let code: String
    let copyText: String

    @State private var copiedFlash = false
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    @State private var parallaxX: CGFloat = 0
    @State private var parallaxY: CGFloat = 0
    @State private var isInteracting = false

    private let cardShape = RoundedRectangle(cornerRadius: 26, style: .continuous)
    private let cardHeight: CGFloat = 210
    private let baseTiltDegrees: Double = 4.8
    private let maxTiltDegrees: Double = 8
    private let maxParallax: CGFloat = 6
    private let tiltDragThreshold: CGFloat = 10

    private var normalizedCode: String {
        ProcessReferralCode.normalize(code)
    }

    var body: some View {
        cardAssembly
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                AppCopy.t("Code parrainage \(normalizedCode)", en: "Referral code \(normalizedCode)")
            )
    }

    private var cardAssembly: some View {
        ZStack(alignment: .bottomLeading) {
            cardPlate

            copyPill
                .padding(.leading, 20)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .compositingGroup()
        .rotationEffect(.degrees(baseTiltDegrees))
        .offset(x: parallaxX, y: parallaxY)
        .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.58)
        .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.58)
        .scaleEffect(isInteracting ? 1.012 : 1)
        .shadow(color: Color.black.opacity(isInteracting ? 0.50 : 0.38), radius: isInteracting ? 34 : 28, y: 20)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.8), value: isInteracting)
    }

    private var cardPlate: some View {
        ZStack {
            metalSurface
            cardTextOverlay
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .clipShape(cardShape)
        .overlay {
            GeometryReader { geo in
                Color.clear
                    .contentShape(cardShape)
                    .gesture(tiltGesture(cardSize: geo.size))
            }
        }
    }

    private var cardTextOverlay: some View {
        VStack(spacing: 0) {
            Text(AppCopy.t("TON CODE DE PARRAINAGE", en: "YOUR REFERRAL CODE"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(engravedCaptionColor)
                .padding(.top, 28)

            Spacer(minLength: 8)

            Text(normalizedCode)
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .tracking(3.2)
                .foregroundStyle(engravedCodeGradient)
                .shadow(color: Color.white.opacity(0.48), radius: 0, x: 0, y: 1.4)
                .shadow(color: Color.black.opacity(0.32), radius: 0, x: 0, y: -1)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .padding(.horizontal, 16)

            Spacer(minLength: 8)

            Text(AppCopy.t("PARTAGE ET GAGNE", en: "SHARE & EARN REWARDS"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(engravedCaptionColor)
                .padding(.bottom, 28)
        }
        .allowsHitTesting(false)
    }

    private var copyPill: some View {
        Button(action: performCopy) {
            Text(
                copiedFlash
                    ? AppCopy.t("Copié", en: "Copied")
                    : AppCopy.t("Copier", en: "Copy")
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(Capsule(style: .continuous).fill(Color.white))
            .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityHint(AppCopy.t("Copier le lien de parrainage", en: "Copy referral link"))
    }

    private var engravedCaptionColor: Color {
        Color(red: 0.36, green: 0.37, blue: 0.40)
    }

    private var engravedCodeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.30, green: 0.31, blue: 0.34),
                Color(red: 0.42, green: 0.43, blue: 0.46),
                Color(red: 0.34, green: 0.35, blue: 0.38)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var metalSurface: some View {
        ZStack {
            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.97, blue: 0.99),
                            Color(red: 0.86, green: 0.87, blue: 0.90),
                            Color(red: 0.72, green: 0.73, blue: 0.76),
                            Color(red: 0.80, green: 0.81, blue: 0.84)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.78),
                            Color.white.opacity(0.22),
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.10)
                        ],
                        startPoint: UnitPoint(x: 0.05, y: 0.0),
                        endPoint: UnitPoint(x: 0.95, y: 1.0)
                    )
                )
                .blendMode(.screen)

            cardShape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.72),
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.28, y: 0.18),
                        startRadius: 8,
                        endRadius: 220
                    )
                )
                .blendMode(.overlay)

            cardShape
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            Color.white.opacity(0.10),
                            Color.clear,
                            Color.black.opacity(0.12),
                            Color.white.opacity(0.28),
                            Color.clear,
                            Color.white.opacity(0.45)
                        ],
                        center: UnitPoint(x: 0.30, y: 0.24)
                    )
                )
                .blendMode(.overlay)

            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.82),
                            Color.white.opacity(0.34),
                            Color.clear,
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.softLight)

            ProcessReferralMetalBrushedOverlay()
                .clipShape(cardShape)
                .blendMode(.overlay)
                .opacity(0.52)

            ProcessReferralMetalNoiseOverlay(density: 0.11, maxParticle: 1.45)
                .clipShape(cardShape)
                .blendMode(.overlay)
                .opacity(0.92)

            ProcessReferralMetalNoiseOverlay(density: 0.22, maxParticle: 0.75)
                .clipShape(cardShape)
                .blendMode(.softLight)
                .opacity(0.55)

            cardShape
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.14)
                        ],
                        center: .center,
                        startRadius: 80,
                        endRadius: 260
                    )
                )
                .blendMode(.multiply)
                .opacity(0.35)

            cardShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            Color.white.opacity(0.42),
                            Color.black.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        }
    }

    private func performCopy() {
        let payload = copyText.isEmpty ? normalizedCode : copyText
        UIPasteboard.general.string = payload
        HapticManager.shared.notification(.success)
        ProcessSoundPlayer.playSettingsChange()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            copiedFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                copiedFlash = false
            }
        }
    }

    private func tiltGesture(cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard cardSize.width > 1, cardSize.height > 1 else { return }

                let dragDistance = hypot(value.translation.width, value.translation.height)
                guard dragDistance >= tiltDragThreshold else { return }

                if !isInteracting {
                    isInteracting = true
                    HapticManager.shared.beginContinuousCardHold()
                }

                let center = CGPoint(x: cardSize.width * 0.5, y: cardSize.height * 0.5)
                let nx = min(1, max(-1, (value.location.x - center.x) / (cardSize.width * 0.5)))
                let ny = min(1, max(-1, (value.location.y - center.y) / (cardSize.height * 0.5)))
                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.86)) {
                    tiltY = nx * maxTiltDegrees
                    tiltX = -ny * maxTiltDegrees
                    parallaxX = nx * maxParallax
                    parallaxY = ny * maxParallax * 0.45
                }
            }
            .onEnded { _ in
                if isInteracting {
                    isInteracting = false
                    HapticManager.shared.endContinuousCardHold()
                }

                withAnimation(.spring(response: 0.52, dampingFraction: 0.76)) {
                    tiltX = 0
                    tiltY = 0
                    parallaxX = 0
                    parallaxY = 0
                }
            }
    }
}

// MARK: - Code parrainage (tuiles Opal — réglages / legacy)

struct ProcessReferralGlassCodeRow: View {
    let code: String
    var copyText: String = ""
    var onCopy: (() -> Void)? = nil

    private var normalizedCode: String {
        ProcessReferralCode.normalize(code)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(AppCopy.t("TON CODE DE PARRAINAGE", en: "YOUR REFERRAL CODE"))
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(ProcessReferralTheme.textTertiary)
                .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                ForEach(Array(normalizedCode.enumerated()), id: \.offset) { _, character in
                    ProcessReferralOpalCodeTile(character: String(character)) {
                        performCopy()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 28)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AppCopy.t("Code parrainage \(normalizedCode)", en: "Referral code \(normalizedCode)"))
    }

    private func performCopy() {
        guard !copyText.isEmpty else { return }

        UIPasteboard.general.string = copyText
        HapticManager.shared.notification(.success)
        ProcessSoundPlayer.playSettingsChange()
        onCopy?()
    }
}

private struct ProcessReferralOpalCodeTile: View {
    let character: String
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        Button(action: action) {
            Text(character)
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    shape.fill(Color(white: 0.14))
                }
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(character)
        .accessibilityHint(AppCopy.t("Copier le lien de parrainage", en: "Copy referral link"))
    }
}

// MARK: - Textures métal

private struct ProcessReferralMetalBrushedOverlay: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let lineCount = Int(size.height * 3.2)
            for index in 0..<lineCount {
                let y = CGFloat(index) / CGFloat(max(lineCount - 1, 1)) * size.height
                let seed = Double(index * 1_903)
                let opacity = 0.028 + (seed.truncatingRemainder(dividingBy: 0.05))
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y + CGFloat(sin(seed * 0.7) * 0.55)))
                context.stroke(path, with: .color(Color.white.opacity(opacity)), lineWidth: 0.65)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ProcessReferralMetalNoiseOverlay: View {
    var density: Double = 0.045
    var maxParticle: CGFloat = 1.35

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let count = Int(size.width * size.height * density)
            for index in 0..<count {
                let seed = Double(index * 9_271)
                let x = CGFloat(seed.truncatingRemainder(dividingBy: Double(size.width - 1)))
                let y = CGFloat((seed * 1.37).truncatingRemainder(dividingBy: Double(size.height - 1)))
                let opacity = 0.06 + (seed.truncatingRemainder(dividingBy: 0.16))
                let side: CGFloat = seed.truncatingRemainder(dividingBy: Double(maxParticle)) > Double(maxParticle * 0.55)
                    ? maxParticle
                    : maxParticle * 0.62
                let rect = CGRect(x: x, y: y, width: side, height: side)
                let tone = seed.truncatingRemainder(dividingBy: 1) > 0.5
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color((tone ? Color.white : Color.black).opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
