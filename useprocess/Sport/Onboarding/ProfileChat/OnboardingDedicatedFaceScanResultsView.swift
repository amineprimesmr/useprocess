//
//  OnboardingDedicatedFaceScanResultsView.swift
//  useprocess
//

import StoreKit
import SwiftUI

/// Page dédiée du premier scan : anneau + indicateurs ouverts/verrouillés, sans revue comportementale.
struct OnboardingDedicatedFaceScanResultsView: View {
    @Environment(\.requestReview) private var requestReview
    @ObservedObject private var creatorMode = ProcessCreatorModeStore.shared

    let result: FaceScanResult
    var onContinue: () -> Void
    var onRetryScan: (() -> Void)? = nil

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

                    FaceScanWhoopScoreRing(result: result, showsGlobalScore: false, ringSize: 196)
                        .padding(.bottom, 22)

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
                bottomCTA
            }
        }
        .processClearUIKitHostingBackground()
        .background(FaceScanWhoopPalette.canvas)
        .task {
            guard !OnboardingAppStoreRatingPrompt.hasBeenShown else { return }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            OnboardingAppStoreRatingPrompt.markShown()
            ProcessAnalytics.trackAppStoreReviewPrompted(source: "onboarding_face_scan_results")
            requestReview()
        }
    }

    private var showsDevRescanButton: Bool {
        guard onRetryScan != nil else { return false }
        #if DEBUG
        return true
        #else
        return creatorMode.isUnlocked(forFirstName: UnifiedProfileService.shared.currentProfile?.firstName)
        #endif
    }

    private var header: some View {
        ZStack {
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

            if showsDevRescanButton {
                HStack {
                    Button(action: retryScan) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FaceScanWhoopPalette.label)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .strokeBorder(FaceScanWhoopPalette.label.opacity(0.18), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.processPlain)
                    .accessibilityLabel(AppCopy.t("Revenir au scan du visage", en: "Back to face scan"))

                    Text(AppCopy.t("DEV", en: "DEV"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(FaceScanWhoopPalette.secondary)
                        .allowsHitTesting(false)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func retryScan() {
        HapticManager.shared.impact(.light)
        onRetryScan?()
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
    @Environment(\.colorScheme) private var colorScheme

    var title: String
    var action: () -> Void

    private var isLight: Bool { colorScheme == .light }

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.processPlain)
        .contentShape(Capsule())
        .shadow(color: Color(red: 0.08, green: 0.22, blue: 0.72).opacity(isLight ? 0.22 : 0.28), radius: 10, y: 2)
        .accessibilityLabel(title)
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
