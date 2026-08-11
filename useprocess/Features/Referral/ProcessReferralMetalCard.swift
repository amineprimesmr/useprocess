import SwiftUI

/// Carte parrainage effet métal brossé — code dot-matrix + bouton Copy.
struct ProcessReferralMetalCard: View {
    let referralCode: String
    let copyText: String
    var onCopy: () -> Void

    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0
    @State private var parallaxX: CGFloat = 0
    @State private var parallaxY: CGFloat = 0
    @State private var isInteracting = false
    @State private var copiedFlash = false

    private let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    private let maxTiltDegrees: Double = 10
    private let maxParallax: CGFloat = 7

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            metalSurface
                .overlay {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(cardShape)
                            .gesture(interactionGesture(cardSize: geo.size))
                    }
                }

            VStack(spacing: 0) {
                Text(AppCopy.t("TON CODE PARRAIN", en: "YOUR REFERRAL CODE"))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color(white: 0.46))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)

                Spacer(minLength: 12)

                ProcessReferralDotMatrixCode(text: referralCode)
                    .padding(.horizontal, 20)

                Spacer(minLength: 12)

                Text(AppCopy.t("PARTAGE ET GAGNE", en: "SHARE & EARN REWARDS"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color(white: 0.42))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 58)
            }

            Button {
                UIPasteboard.general.string = copyText
                HapticManager.shared.notification(.success)
                withAnimation(.easeOut(duration: 0.18)) { copiedFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation { copiedFlash = false }
                }
                onCopy()
            } label: {
                Text(copiedFlash
                     ? AppCopy.t("Copié", en: "Copied")
                     : AppCopy.t("Copier", en: "Copy"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Capsule(style: .continuous).fill(Color.white))
            }
            .buttonStyle(.processPlain)
            .padding(.leading, 18)
            .padding(.bottom, 18)
            .zIndex(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(cardShape)
        .scaleEffect(isInteracting ? 1.014 : 1)
        .offset(x: parallaxX, y: parallaxY)
        .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.62)
        .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.62)
        .shadow(color: .black.opacity(isInteracting ? 0.55 : 0.42), radius: isInteracting ? 28 : 22, y: 14)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.8), value: isInteracting)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppCopy.t("Code parrainage \(referralCode)", en: "Referral code \(referralCode)"))
        .accessibilityHint(AppCopy.t("Maintiens pour incliner, touche Copier pour copier ton invitation", en: "Hold to tilt, tap Copy to copy your invite"))
    }

    private var metalSurface: some View {
        ZStack {
            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.79, blue: 0.82),
                            Color(red: 0.58, green: 0.59, blue: 0.62),
                            Color(red: 0.70, green: 0.71, blue: 0.74),
                            Color(red: 0.52, green: 0.53, blue: 0.56)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            cardShape
                .fill(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.clear,
                            Color.black.opacity(0.14),
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.10),
                            Color.clear,
                            Color.white.opacity(0.18)
                        ],
                        center: .center
                    )
                )
                .blendMode(.overlay)

            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.38),
                            Color.clear,
                            Color.clear,
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.softLight)

            ProcessReferralMetalNoiseOverlay()
                .clipShape(cardShape)
                .blendMode(.overlay)
                .opacity(0.55)

            cardShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private func interactionGesture(cardSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard cardSize.width > 1, cardSize.height > 1 else { return }
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
                    parallaxY = ny * maxParallax * 0.5
                }
            }
            .onEnded { _ in
                isInteracting = false
                HapticManager.shared.endContinuousCardHold()
                withAnimation(.spring(response: 0.52, dampingFraction: 0.76)) {
                    tiltX = 0
                    tiltY = 0
                    parallaxX = 0
                    parallaxY = 0
                }
            }
    }
}

private struct ProcessReferralDotMatrixCode: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 34, weight: .heavy, design: .monospaced))
            .tracking(3)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.29, blue: 0.32),
                        Color(red: 0.38, green: 0.39, blue: 0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: Color.white.opacity(0.35), radius: 0, x: 0, y: 1)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }
}

private struct ProcessReferralMetalNoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let count = Int(size.width * size.height * 0.045)
            for index in 0..<count {
                let seed = Double(index * 9_271)
                let x = CGFloat(seed.truncatingRemainder(dividingBy: Double(size.width - 1)))
                let y = CGFloat((seed * 1.37).truncatingRemainder(dividingBy: Double(size.height - 1)))
                let opacity = 0.04 + (seed.truncatingRemainder(dividingBy: 0.12))
                let side: CGFloat = seed.truncatingRemainder(dividingBy: 1.6) > 0.8 ? 1.2 : 0.8
                let rect = CGRect(x: x, y: y, width: side, height: side)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
