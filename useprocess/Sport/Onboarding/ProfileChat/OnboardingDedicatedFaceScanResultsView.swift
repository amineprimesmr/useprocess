//
//  OnboardingDedicatedFaceScanResultsView.swift
//  useprocess
//

import SwiftUI

/// Page dédiée du premier scan : anneau + indicateurs ouverts/verrouillés, sans revue comportementale.
struct OnboardingDedicatedFaceScanResultsView: View {
    let result: FaceScanResult
    var onContinue: () -> Void

    @State private var showsCreatePlanButton = false

    private var fullDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = ProcessAppLanguage.shared.locale
        formatter.dateFormat = ProcessAppLanguage.shared.isEnglish ? "EEEE, MMMM d" : "EEEE d MMMM"
        let raw = formatter.string(from: result.createdAt)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    var body: some View {
        ZStack {
            FaceScanWhoopPalette.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 18)

                    FaceScanWhoopScoreRing(result: result, showsGlobalScore: false, ringSize: 232)
                        .padding(.bottom, 28)

                    OnboardingFaceDeepAnalysisView(
                        result: result,
                        ringScale: 1,
                        showsScoreRing: false,
                        showsUnlockTeaser: false
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .frame(minHeight: 430)
                }
            }
            .processTransparentScrollSurface()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showsCreatePlanButton {
                    bottomCTA
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .processClearUIKitHostingBackground()
        .background(FaceScanWhoopPalette.canvas)
        .task {
            try? await Task.sleep(for: .seconds(7))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                showsCreatePlanButton = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(OnboardingCopy.t("Premier scan", en: "First scan"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FaceScanWhoopPalette.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(fullDateTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FaceScanWhoopPalette.label)
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomCTA: some View {
        OnboardingCreatePlanButton(
            title: AppCopy.t("Créer mon plan", en: "Create my plan")
        ) {
            HapticManager.shared.impact(.medium)
            onContinue()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}

struct OnboardingCreatePlanButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            OnboardingCreatePlanButtonVisual(title: title)
        }
        .buttonStyle(OnboardingCreatePlanButtonStyle())
        .accessibilityLabel(title)
    }
}

private struct OnboardingCreatePlanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Capsule())
            .processButtonPressScale(isPressed: configuration.isPressed)
    }
}

struct OnboardingCreatePlanButtonVisual: View {
    @Environment(\.colorScheme) private var colorScheme

    var title: String

    private var isLight: Bool { colorScheme == .light }

    var body: some View {
        HStack(spacing: 10) {
            Image("ProcessAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isLight ? Color.white : Color.black)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(isLight ? Color.black : Color.white, in: Capsule())
        .overlay {
            OnboardingCreatePlanRotatingBorder()
        }
        .shadow(
            color: Color(red: 0.08, green: 0.22, blue: 0.72).opacity(isLight ? 0.22 : 0.28),
            radius: 10,
            y: 2
        )
    }
}

/// Contour bleu foncé lumineux qui tourne autour du CTA.
private struct OnboardingCreatePlanRotatingBorder: View {
    private let lineWidth: CGFloat = 2.4
    private let rotationPeriod: Double = 2.4

    private static let deepBlue = Color(red: 0.04, green: 0.16, blue: 0.58)
    private static let midBlue = Color(red: 0.10, green: 0.32, blue: 0.88)
    private static let glow = Color(red: 0.38, green: 0.58, blue: 1.0)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let progress = elapsed.truncatingRemainder(dividingBy: rotationPeriod) / rotationPeriod
            let angle = Angle.degrees(progress * 360)
            let gradient = AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: Self.deepBlue, location: 0.0),
                    .init(color: Self.midBlue, location: 0.16),
                    .init(color: Self.glow, location: 0.24),
                    .init(color: Color.white.opacity(0.92), location: 0.30),
                    .init(color: Self.glow, location: 0.36),
                    .init(color: Self.deepBlue, location: 0.52),
                    .init(color: Self.deepBlue.opacity(0.72), location: 0.78),
                    .init(color: Self.deepBlue, location: 1.0)
                ]),
                center: .center,
                angle: angle
            )

            ZStack {
                Capsule()
                    .stroke(gradient, lineWidth: lineWidth + 6)
                    .blur(radius: 6)
                    .opacity(0.62)
                Capsule()
                    .strokeBorder(gradient, lineWidth: lineWidth)
            }
        }
        .allowsHitTesting(false)
    }
}
