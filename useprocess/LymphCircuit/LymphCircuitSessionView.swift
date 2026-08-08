import AVFoundation
import SwiftUI
import UIKit

/// Session live circuit lymphatique — caméra + tracking + démo PiP.
struct LymphCircuitSessionView: View {
    let dayId: String
    var startAt: FaceMorningRoutineCatalog.Step? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var model = LymphCircuitSessionModel()
    @StateObject private var camera = BodyScanCameraService()
    /// `false` = caméra grand / démo en coin · `true` = démo grand / caméra en coin.
    @State private var isDemoExpanded = false

    private let pipSize = CGSize(width: 148, height: 222)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.phase {
            case .intro:
                introView
            case .permissions:
                permissionsView
            case .active:
                activeView
            case .finished:
                finishedView
            case .error(let message):
                errorView(message)
            }
        }
        .onAppear {
            model.configure(dayId: dayId, startAt: startAt)
            camera.refreshAuthorizationStatus()
            wireCamera()
        }
        .onDisappear {
            camera.onFrame = nil
            camera.stop()
            model.resetToIntro()
        }
        .onChange(of: model.phase) { _, phase in
            switch phase {
            case .active:
                if model.needsCameraForRemainingSteps || model.currentStep?.usesLiveCamera == true {
                    ensureCameraRunning()
                }
            case .finished, .intro, .error, .permissions:
                camera.stop()
            }
        }
        .onChange(of: model.stepIndex) { _, _ in
            isDemoExpanded = false
            if model.currentStep?.usesLiveCamera == true {
                ensureCameraRunning()
            } else {
                camera.stop()
            }
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.14), in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .padding(.top, 12)

                    Text(AppCopy.t("Circuit lymphatique", en: "Lymphatic circuit"))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(AppCopy.t(
                        "Caméra live + tracking. Suis la démo dans l’angle — tape pour agrandir.",
                        en: "Live camera + tracking. Follow the corner demo — tap to expand."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(model.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.black)
                                    .frame(width: 22, height: 22)
                                    .background(.white, in: Circle())
                                Text(step.shortTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(step.repBadge ?? "")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                        }
                    }
                    .padding(18)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
            }

            Button {
                startFlow()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(AppCopy.t("Lancer", en: "Start"))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(.white, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
    }

    // MARK: - Active

    private var activeView: some View {
        GeometryReader { geo in
            // `ignoresSafeArea` annule geo.safeAreaInsets → on lit la vraie inset fenêtre.
            let topInset = max(UIApplication.safeAreaTop, 47)
            let bottomInset = max(UIApplication.safeAreaBottom, 16)
            let full = geo.size
            let pipW = pipSize.width
            let pipH = pipSize.height
            let headerHeight: CGFloat = 54
            let pipTop = topInset + headerHeight + 10
            let pipCenter = CGPoint(
                x: full.width - 14 - pipW / 2,
                y: pipTop + pipH / 2
            )
            let fullCenter = CGPoint(x: full.width / 2, y: full.height / 2)

            ZStack {
                Color.black

                // Une seule caméra + une seule vidéo — resize uniquement (pas de remount).
                cameraStage
                    .frame(
                        width: isDemoExpanded ? pipW : full.width,
                        height: isDemoExpanded ? pipH : full.height
                    )
                    .clipShape(RoundedRectangle(
                        cornerRadius: isDemoExpanded ? 18 : 0,
                        style: .continuous
                    ))
                    .overlay {
                        if isDemoExpanded {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        }
                    }
                    .shadow(color: isDemoExpanded ? .black.opacity(0.45) : .clear, radius: 12, y: 6)
                    .position(isDemoExpanded ? pipCenter : fullCenter)
                    .zIndex(isDemoExpanded ? 3 : 1)

                if let step = model.currentStep {
                    LymphCircuitDemoMediaView(
                        step: step,
                        isPlaybackActive: !model.isPaused && model.phase == .active,
                        isPip: !isDemoExpanded
                    )
                    .id(step.id)
                    .frame(
                        width: isDemoExpanded ? full.width : pipW,
                        height: isDemoExpanded ? full.height : pipH
                    )
                    .clipShape(RoundedRectangle(
                        cornerRadius: isDemoExpanded ? 0 : 18,
                        style: .continuous
                    ))
                    .overlay {
                        if !isDemoExpanded {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                        }
                    }
                    .shadow(color: isDemoExpanded ? .clear : .black.opacity(0.45), radius: 12, y: 6)
                    .position(isDemoExpanded ? fullCenter : pipCenter)
                    .zIndex(isDemoExpanded ? 1 : 3)
                }

                LinearGradient(
                    colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
                .zIndex(9)

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 0)
                        .allowsHitTesting(false)
                    bottomControls
                }
                .padding(.top, topInset + 8)
                .padding(.bottom, bottomInset)
                .zIndex(10)

                Color.clear
                    .frame(width: pipW, height: pipH)
                    .contentShape(Rectangle())
                    .position(pipCenter)
                    .zIndex(12)
                    .onTapGesture { isDemoExpanded.toggle() }
                    .accessibilityLabel(
                        isDemoExpanded
                            ? AppCopy.t("Remettre la caméra en grand", en: "Make camera full screen")
                            : AppCopy.t("Agrandir la vidéo démo", en: "Expand demo video")
                    )
                    .accessibilityAddTraits(.isButton)

                if let countdown = model.countdownValue {
                    Text("\(countdown)")
                        .font(.system(size: 96, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 12)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(11)
                        .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.2), value: model.countdownValue)
    }

    @ViewBuilder
    private var cameraStage: some View {
        if model.currentStep?.usesLiveCamera == true {
            BodyScanLiveCameraRepresentable(
                session: camera.session,
                landmarks: model.liveLandmarks,
                isReady: model.motion.isMoving || model.motion.bodyVisible
            )
        } else {
            staticStepBackground
        }
    }

    private var staticStepBackground: some View {
        ZStack {
            if let asset = model.currentStep?.assetName {
                Image(asset)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.45))
            } else {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.12, blue: 0.18), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            if let step = model.currentStep {
                VStack(spacing: 16) {
                    Image(systemName: step.fallbackIcon)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(step.shortTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                model.finishEarly()
                if model.phase == .intro || model.completedCarouselIds.isEmpty {
                    dismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.45), in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.currentStep?.shortTitle ?? "")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(model.stepLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer(minLength: 8)

            timerBadge
        }
        .padding(.horizontal, 16)
    }

    private var timerBadge: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.001, 1 - model.stepProgressFraction))
                .stroke(
                    model.motion.isMoving ? Color.green : Color.white,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(formatTime(model.secondsRemaining))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: 54, height: 54)
        .background(.black.opacity(0.4), in: Circle())
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            if model.currentStep?.usesLiveCamera == true {
                motionMeter
            }

            Text(model.coachingMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .animation(.easeOut(duration: 0.2), value: model.coachingMessage)

            HStack(spacing: 18) {
                controlButton(
                    icon: "forward.end.fill",
                    title: AppCopy.t("Passer", en: "Skip")
                ) {
                    model.skipStep()
                }

                Button {
                    model.togglePause()
                } label: {
                    Image(systemName: model.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 72, height: 72)
                        .background(.white, in: Circle())
                }
                .disabled(model.countdownValue != nil)
                .opacity(model.countdownValue != nil ? 0.5 : 1)

                controlButton(
                    icon: "checkmark",
                    title: AppCopy.t("Fait", en: "Done")
                ) {
                    model.markStepDone()
                }
            }
            .padding(.bottom, 28)
        }
        .padding(.top, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var motionMeter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(AppCopy.t("Mouvement", en: "Motion"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(model.motion.isMoving
                     ? AppCopy.t("Détecté", en: "Detected")
                     : AppCopy.t("En attente", en: "Waiting"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(model.motion.isMoving ? .green : .white.opacity(0.55))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(model.motion.isMoving ? Color.green : Color.cyan)
                        .frame(width: max(8, geo.size.width * model.motion.intensity))
                        .animation(.easeOut(duration: 0.15), value: model.motion.intensity)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 8)
    }

    private func controlButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(width: 72)
        }
    }

    // MARK: - Finished / permissions / error

    private var finishedView: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text(AppCopy.t("Circuit terminé", en: "Circuit complete"))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(AppCopy.t(
                "\(model.completedCarouselIds.count) étapes validées — belle pompe lymphatique.",
                en: "\(model.completedCarouselIds.count) steps done — great lymph pump."
            ))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text(AppCopy.t("Terminer", en: "Done"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private var permissionsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
            Text(AppCopy.t("Caméra requise", en: "Camera required"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(AppCopy.t(
                "Autorise la caméra pour le tracking en direct de tes mouvements.",
                en: "Allow camera access for live movement tracking."
            ))
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            Spacer()
            Button {
                Task {
                    if await camera.requestAccess() {
                        model.startActiveFlow()
                        ensureCameraRunning()
                    } else {
                        model.phase = .error(AppCopy.t(
                            "Autorise la caméra dans Réglages.",
                            en: "Allow camera access in Settings."
                        ))
                    }
                }
            } label: {
                Text(AppCopy.t("Autoriser", en: "Allow"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(AppCopy.retry) {
                model.resetToIntro()
            }
            .buttonStyle(.borderedProminent)
            Button(AppCopy.close) { dismiss() }
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Helpers

    private func startFlow() {
        wireCamera()
        camera.refreshAuthorizationStatus()
        switch camera.authorizationStatus {
        case .authorized:
            model.beginSession(cameraAuthorized: true)
            ensureCameraRunning()
        case .notDetermined:
            model.beginSession(cameraAuthorized: false)
        default:
            if model.needsCameraForRemainingSteps {
                model.phase = .error(AppCopy.t(
                    "Autorise la caméra dans Réglages.",
                    en: "Allow camera access in Settings."
                ))
            } else {
                model.beginSession(cameraAuthorized: true)
            }
        }
    }

    private func wireCamera() {
        camera.onFrame = { buffer, _ in
            model.enqueueFrame(buffer)
        }
    }

    private func ensureCameraRunning() {
        camera.refreshAuthorizationStatus()
        guard camera.authorizationStatus == .authorized else { return }
        wireCamera()
        if !camera.isRunning {
            camera.start(preferredPosition: .front, deliversFrames: true)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
