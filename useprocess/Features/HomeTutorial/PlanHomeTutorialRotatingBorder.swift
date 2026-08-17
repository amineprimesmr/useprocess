import SwiftUI

/// Contour lumineux rotatif — trait net, brillance courte, sans halo externe.
struct PlanHomeTutorialRotatingBorder: View, Equatable {
    var cornerRadius: CGFloat = PlanHomeTutorialMetrics.sectionCornerRadius
    var lineWidth: CGFloat = 2.75
    var rotationPeriod: Double = 4.8

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.cornerRadius == rhs.cornerRadius
            && abs(lhs.lineWidth - rhs.lineWidth) < 0.01
            && abs(lhs.rotationPeriod - rhs.rotationPeriod) < 0.01
    }

    var body: some View {
        PlanHomeTutorialRotatingBorderPulse(
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            rotationPeriod: rotationPeriod
        )
        .equatable()
        .allowsHitTesting(false)
    }
}

/// Animation isolée — seul ce subtree redessine à chaque frame.
private struct PlanHomeTutorialRotatingBorderPulse: View, Equatable {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let rotationPeriod: Double

    private static let hotCyan = Color(red: 0.78, green: 0.98, blue: 1.0)

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.cornerRadius == rhs.cornerRadius
            && abs(lhs.lineWidth - rhs.lineWidth) < 0.01
            && abs(lhs.rotationPeriod - rhs.rotationPeriod) < 0.01
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let progress = elapsed.truncatingRemainder(dividingBy: rotationPeriod) / rotationPeriod
            let angle = Angle.degrees(progress * 360)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(beamGradient(angle: angle), lineWidth: lineWidth)
        }
        .compositingGroup()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .drawingGroup(opaque: false)
    }

    /// Arc lumineux court (~12 % du périmètre) — le reste est transparent.
    private func beamGradient(angle: Angle) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.42),
                .init(color: Self.hotCyan.opacity(0.35), location: 0.46),
                .init(color: .white.opacity(0.92), location: 0.49),
                .init(color: .white, location: 0.50),
                .init(color: Self.hotCyan, location: 0.505),
                .init(color: .white.opacity(0.92), location: 0.51),
                .init(color: Self.hotCyan.opacity(0.35), location: 0.54),
                .init(color: .clear, location: 0.58),
                .init(color: .clear, location: 1.0)
            ]),
            center: .center,
            angle: angle
        )
    }
}

enum PlanHomeTutorialMetrics {
    static let sectionCornerRadius: CGFloat = 30
    static let tabCornerRadius: CGFloat = 22
}

enum PlanHomeTutorialChromeStyle {
    static func titleColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func messageColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.58)
    }

    static func dotActiveColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func dotInactiveColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.18)
    }

    static func continueButtonBackground(for colorScheme: ColorScheme) -> Color {
        OnboardingTheme.filledButtonBackground(for: colorScheme)
    }

    static func continueButtonForeground(for colorScheme: ColorScheme) -> Color {
        OnboardingTheme.filledButtonText(for: colorScheme)
    }
}

/// Wrapper tutoriel — contour + légende + CTA sur la carte ciblée uniquement.
struct PlanHomeTutorialFocusChrome<Content: View>: View {
    let focus: PlanHomeTutorialFocus
    var cornerRadius: CGFloat? = nil
    let isFocused: Bool
    let isRevealed: Bool
    let captionStep: PlanHomeTutorialStep?
    let showsFooter: Bool
    let stepIndex: Int
    let stepCount: Int
    let onAdvance: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            content()
                .overlay {
                    if isFocused {
                        PlanHomeTutorialRotatingBorder(
                            cornerRadius: cornerRadius ?? focus.cornerRadius
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .opacity(isRevealed ? 0.88 : 1)

            if isFocused, let step = captionStep {
                PlanHomeTutorialCaption(step: step)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                if showsFooter {
                    PlanHomeTutorialInlineFooter(
                        onAdvance: onAdvance,
                        stepIndex: stepIndex,
                        stepCount: stepCount
                    )
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: isFocused)
        .id(focus.scrollAnchorID)
    }
}

extension PlanHomeTutorialFocusChrome {
    init(
        focus: PlanHomeTutorialFocus,
        cornerRadius: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            focus: focus,
            store: PlanHomeTutorialStore.shared,
            cornerRadius: cornerRadius,
            content: content
        )
    }

    init(
        focus: PlanHomeTutorialFocus,
        store: PlanHomeTutorialStore,
        cornerRadius: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        let step = store.currentStep
        self.init(
            focus: focus,
            cornerRadius: cornerRadius,
            isFocused: store.isFocused(focus),
            isRevealed: store.isRevealed(focus),
            captionStep: store.isFocused(focus) ? step : nil,
            showsFooter: store.isFocused(focus) && !step.isTabStep,
            stepIndex: store.currentStepIndex,
            stepCount: store.steps.count,
            onAdvance: { store.advance() },
            content: content
        )
    }
}

/// Contour rotatif sur un segment de la tab bar (Série).
struct PlanHomeTutorialTabSegmentOutline: View, Equatable {
    let highlightedTab: ProcessMainSection
    var tabs: [ProcessMainSection] = ProcessMainSection.tabOrder

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.highlightedTab == rhs.highlightedTab && lhs.tabs == rhs.tabs
    }

    var body: some View {
        GeometryReader { geo in
            let count = max(CGFloat(tabs.count), 1)
            if let index = tabs.firstIndex(of: highlightedTab) {
                let segmentWidth = geo.size.width / count
                let centerX = segmentWidth * (CGFloat(index) + 0.5)

                PlanHomeTutorialRotatingBorder(
                    cornerRadius: PlanHomeTutorialMetrics.tabCornerRadius,
                    lineWidth: 2.75,
                    rotationPeriod: 4.8
                )
                .frame(width: max(segmentWidth - 4, 44), height: geo.size.height)
                .position(x: centerX, y: geo.size.height / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

struct PlanHomeTutorialCaption: View {
    @Environment(\.colorScheme) private var colorScheme

    let step: PlanHomeTutorialStep

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PlanHomeTutorialChromeStyle.titleColor(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Text(step.message)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(PlanHomeTutorialChromeStyle.messageColor(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}

/// CTA tutoriel — intégré dans le scroll Accueil.
struct PlanHomeTutorialInlineFooter: View {
    @Environment(\.colorScheme) private var colorScheme

    let onAdvance: () -> Void
    let stepIndex: Int
    let stepCount: Int

    var body: some View {
        VStack(spacing: 14) {
            stepDots

            Button(action: onAdvance) {
                Text(stepIndex + 1 >= stepCount
                     ? AppCopy.t("C'est parti", en: "Let's go")
                     : AppCopy.t("Continuer", en: "Continue"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(
                        PlanHomeTutorialChromeStyle.continueButtonForeground(for: colorScheme)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule(style: .continuous)
                            .fill(PlanHomeTutorialChromeStyle.continueButtonBackground(for: colorScheme))
                    )
            }
            .buttonStyle(.processPlain)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(homeStepIndices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(
                        index == stepIndex
                            ? PlanHomeTutorialChromeStyle.dotActiveColor(for: colorScheme)
                            : PlanHomeTutorialChromeStyle.dotInactiveColor(for: colorScheme)
                    )
                    .frame(width: index == stepIndex ? 18 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var homeStepIndices: [Int] {
        PlanHomeTutorialStep.allCases.enumerated().compactMap { index, step in
            step.isTabStep ? nil : index
        }
    }
}
