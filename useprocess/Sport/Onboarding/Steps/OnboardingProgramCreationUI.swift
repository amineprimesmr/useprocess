//
//  OnboardingProgramCreationUI.swift
//  useprocess
//

import SwiftUI

enum OnboardingProgramCreationPalette {
    static var background: Color { OnboardingTheme.screenBackground }
    static let accent = Color(hex: "aeb2fa")
    /// Piste neutre bleu-gris — pas le violet des barres d'analyse chat.
    static var barTrack: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1)
                : UIColor(red: 0.90, green: 0.93, blue: 0.97, alpha: 1)
        })
    }
    static var subtitle: Color { OnboardingTheme.primaryText }
    static var hint: Color { OnboardingTheme.mutedText }
}

// MARK: - Background

struct OnboardingProgramCreationBackground: View {
    var body: some View {
        OnboardingProgramCreationPalette.background
            .ignoresSafeArea()
    }
}

// MARK: - Hero percentage

struct OnboardingProgramCreationHeroPercentage: View {
    @Environment(\.colorScheme) private var colorScheme

    let value: Int

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: -5) {
            Text("\(value)")
                .font(.system(size: 78, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: percentageGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .contentTransition(.numericText(countsDown: false))
                .animation(.snappy(duration: 0.26), value: value)

            Text("%")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(percentSymbolColor)
                .baselineOffset(6)
        }
        .monospacedDigit()
    }

    private var percentageGradient: [Color] {
        if colorScheme == .dark {
            return [Color.white, Color.white.opacity(0.92), Color(white: 0.58)]
        }
        return [
            Color.primary,
            Color.primary.opacity(0.9),
            Color.primary.opacity(0.62)
        ]
    }

    private var percentSymbolColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.92) : Color.primary.opacity(0.88)
    }
}

// MARK: - Badge (assets Reward/)

struct OnboardingProgramCreationBadge: View {
    enum Style: Equatable {
        case scienceApproved
        case programsGenerated
        case download
    }

    let style: Style

    /// Assets FR (`reward*`) / EN (`reward*EN`) — texte baked dans les PNG.
    private var assetName: String {
        let english = ProcessAppLanguage.shared.isEnglish
        switch style {
        case .scienceApproved:
            return english ? "rewardScienceEN" : "rewardScience"
        case .programsGenerated:
            return english ? "rewardProgramEN" : "rewardProgram"
        case .download:
            return english ? "rewardDLEN" : "rewardDL"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 336)
            .frame(height: 106)
            .accessibilityHidden(true)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .id(assetName)
    }
}

// MARK: - Progress bars

struct OnboardingProgramCreationProgressBars: View {
    @Environment(\.colorScheme) private var colorScheme

    let labels: [String]
    let progresses: [Double]
    var visibleCount: Int = 1

    private let barHeight: CGFloat = 16

    private var fillGradient: LinearGradient {
        PaywallBevelTheme.paywallProTitleGradient(for: colorScheme)
    }

    private var fillGlow: Color {
        PaywallBevelTheme.accentBlueGlow(for: colorScheme)
    }

    private var completeAccent: Color {
        colorScheme == .dark
            ? Color(red: 0.52, green: 0.88, blue: 1.0)
            : Color(red: 0.14, green: 0.50, blue: 0.96)
    }

    private var clampedVisibleCount: Int {
        min(max(visibleCount, 1), labels.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(0..<clampedVisibleCount, id: \.self) { index in
                barRow(
                    label: labels[index],
                    progress: progresses[safe: index] ?? 0,
                    isComplete: (progresses[safe: index] ?? 0) >= 0.999
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: progresses)
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: clampedVisibleCount)
    }

    private func barRow(label: String, progress: Double, isComplete: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OnboardingProgramCreationPalette.subtitle)

                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(completeAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let clamped = min(max(progress, 0), 1)
                let fillWidth = max(barHeight, width * clamped)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(OnboardingProgramCreationPalette.barTrack)

                    Capsule()
                        .fill(fillGradient)
                        .frame(width: fillWidth, height: barHeight)
                        .shadow(
                            color: fillGlow.opacity(colorScheme == .dark ? 0.45 : 0.55),
                            radius: 8,
                            x: 0,
                            y: 0
                        )
                }
            }
            .frame(height: barHeight)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Confetti

private struct ProgramCreationConfettiPiece: Identifiable {
    let id = UUID()
    let xRatio: CGFloat
    let delay: Double
    let duration: Double
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let spin: Double
}

struct OnboardingProgramCreationConfettiView: View {
    let isActive: Bool

    @State private var pieces: [ProgramCreationConfettiPiece] = []
    @State private var started = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(
                        piece: piece,
                        containerWidth: geometry.size.width,
                        containerHeight: geometry.size.height,
                        isActive: isActive && started
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            pieces = Self.makePieces(count: 52)
            started = true
        }
    }

    private static func makePieces(count: Int) -> [ProgramCreationConfettiPiece] {
        let palette: [Color] = [
            Color(red: 0.55, green: 0.78, blue: 0.98),
            Color(red: 0.98, green: 0.62, blue: 0.78),
            Color(red: 0.98, green: 0.86, blue: 0.45),
            Color(red: 0.72, green: 0.62, blue: 0.98),
            Color(red: 0.58, green: 0.88, blue: 0.72)
        ]

        return (0..<count).map { index in
            ProgramCreationConfettiPiece(
                xRatio: CGFloat.random(in: 0.04...0.96),
                delay: Double(index) * 0.045 + Double.random(in: 0...0.35),
                duration: Double.random(in: 2.8...4.6),
                color: palette[index % palette.count].opacity(Double.random(in: 0.55...0.9)),
                width: CGFloat.random(in: 7...12),
                height: CGFloat.random(in: 14...22),
                spin: Double.random(in: -220...220)
            )
        }
    }
}

private struct ConfettiPieceView: View {
    let piece: ProgramCreationConfettiPiece
    let containerWidth: CGFloat
    let containerHeight: CGFloat
    let isActive: Bool

    @State private var offsetY: CGFloat = -30
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(piece.color)
            .frame(width: piece.width, height: piece.height)
            .rotationEffect(.degrees(rotation))
            .position(x: piece.xRatio * containerWidth, y: offsetY)
            .onAppear {
                guard isActive else { return }
                startFalling()
            }
            .onChange(of: isActive) { _, active in
                guard active else { return }
                startFalling()
            }
    }

    private func startFalling() {
        offsetY = -30
        rotation = 0

        withAnimation(
            .linear(duration: piece.duration)
            .repeatForever(autoreverses: false)
            .delay(piece.delay)
        ) {
            offsetY = containerHeight + 40
            rotation = piece.spin
        }
    }
}

// MARK: - Success screen

struct OnboardingProgramCreationSuccessView: View {
    let isRevealed: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            successCheckmark
                .padding(.bottom, 34)

            VStack(spacing: 10) {
                Text(OnboardingCopy.t("Tout est prêt.", en: "You're all set."))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)

                Text(OnboardingCopy.t("Merci pour vos réponses.", en: "Thanks for your answers."))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
            }
            .multilineTextAlignment(.center)
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 18)
            .animation(
                .spring(response: 0.58, dampingFraction: 0.84).delay(0.08),
                value: isRevealed
            )

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successCheckmark: some View {
        Image("check3D")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .scaleEffect(isRevealed ? 1 : 0.35)
            .opacity(isRevealed ? 1 : 0)
            .animation(.spring(response: 0.56, dampingFraction: 0.72), value: isRevealed)
    }
}

struct OnboardingProgramCreationSuccessFooter: View {
    @Environment(\.colorScheme) private var colorScheme

    let isRevealed: Bool
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: onContinue) {
                Text(OnboardingCopy.t("Commencer", en: "Get started"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
            }
            .onboardingPrimaryActionStyle()
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 28)
            .animation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.14), value: isRevealed)

            Text(OnboardingCopy.t(
                "Process ne remplace pas les conseils d'un médecin. Consulte toujours ton médecin en premier lieu.",
                en: "Process doesn't replace medical advice. Always check with your doctor first."
            ))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(OnboardingTheme.mutedText)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .opacity(isRevealed ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.22), value: isRevealed)
        }
    }
}
