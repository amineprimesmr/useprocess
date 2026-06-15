import SwiftUI
import AVFoundation

struct BodyScanSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var model = BodyScanSessionModel()
    @StateObject private var camera = BodyScanCameraService()

    var userId: String
    var profile: UnifiedUserProfile?
    var showsCloseButton: Bool
    var onFinished: ((BodyScanResult) -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.phase {
            case .intro:
                introView
            case .permissions:
                permissionsView
            case .bodyTurntable:
                turntableView
            case .analyzing:
                analyzingView
            case .report(let result):
                BodyScanReportView(result: result) {
                    onFinished?(result)
                    if showsCloseButton { dismiss() }
                }
                .background(theme.background.ignoresSafeArea())
            case .error(let message):
                errorView(message)
            }
        }
        .onAppear {
            model.bindSession(userId: userId, profile: profile)
            camera.refreshAuthorizationStatus()
            wireCamera()
        }
        .onDisappear {
            camera.onFrame = nil
            camera.stop()
        }
    }

    private func wireCamera() {
        camera.onFrame = { buffer, _ in
            model.enqueueFrame(buffer)
        }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "rotate.3d")
                .font(.system(size: 64))
                .foregroundStyle(.white)

            Text("SCAN 360°")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 16) {
                instructionLine("RECULE — 3 MÈTRES")
                instructionLine("TOURNE SUR TOI")
                instructionLine("LENTEMENT")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button("COMMENCER") { startScanFlow() }
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.white, in: RoundedRectangle(cornerRadius: 30))
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
        }
    }

    private func instructionLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
    }

    // MARK: - Turntable

    private var turntableView: some View {
        ZStack {
            BodyScanLiveCameraRepresentable(
                session: camera.session,
                landmarks: model.liveLandmarks,
                isReady: model.liveFeedback.isReady
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button("QUITTER") {
                        camera.stop()
                        model.reset()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                VStack(spacing: 24) {
                    timerRing

                    Text(model.mainInstruction)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(2)

                    if model.isCountdownActive {
                        Text("\(model.capturedAnglesCount) angles")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    } else {
                        Text(model.liveFeedback.message)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.65))
                .padding(.bottom, 40)
            }
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 8)
                .frame(width: 100, height: 100)
            if model.isCountdownActive {
                Circle()
                    .trim(from: 0, to: model.turntableProgress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
            }
            Text(model.isCountdownActive ? "\(model.turntableTimeRemaining)" : "—")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Permissions & helpers

    private var permissionsView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill").font(.system(size: 48)).foregroundStyle(.white)
            Text("CAMÉRA").font(.system(size: 32, weight: .black)).foregroundStyle(.white)
            Spacer()
            Button("AUTORISER") {
                Task {
                    if await camera.requestAccess() { startScanFlow() }
                    else { model.phase = .error("Autorise la caméra dans Réglages.") }
                }
            }
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 60)
            .background(.white, in: RoundedRectangle(cornerRadius: 30))
            .padding(.horizontal, 32).padding(.bottom, 48)
        }
    }

    private func startScanFlow() {
        model.bindSession(userId: userId, profile: profile)
        wireCamera()
        switch camera.authorizationStatus {
        case .authorized:
            camera.start(preferredPosition: .front)
            model.startBodyTurntable()
        case .notDetermined:
            model.phase = .permissions
        default:
            model.phase = .error("Autorise la caméra dans Réglages.")
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView().tint(.white).scaleEffect(1.4)
            Text("ANALYSE IA…")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("Rapport personnalisé en cours")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message).foregroundStyle(.white).multilineTextAlignment(.center)
            Button("Réessayer") { model.reset() }.buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
