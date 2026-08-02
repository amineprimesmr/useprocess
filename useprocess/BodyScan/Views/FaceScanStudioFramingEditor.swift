import SwiftUI

/// Éditeur mode studio — pan + pinch pour recadrer le visage dans le rond.
struct FaceScanStudioFramingEditor: View {
    let result: FaceScanResult
    let initialFraming: FaceScanStudioFraming
    var onCancel: () -> Void
    var onSave: (FaceScanStudioFraming) -> Void

    @State private var framing: FaceScanStudioFraming = .identity
    @State private var dragStart: FaceScanStudioFraming?
    @State private var pinchStartScale: Double?
    @State private var resolvedVideoURL: URL?
    @State private var snapshot: UIImage?

    private let circleDiameter: CGFloat = 300

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Spacer(minLength: 12)

                framingCanvas
                    .frame(width: circleDiameter, height: circleDiameter)

                Text("Glisse pour déplacer · Pince pour zoomer")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 22)

                Spacer(minLength: 12)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            framing = initialFraming.clamped()
            refreshMedia()
        }
        .statusBarHidden(false)
    }

    private var topBar: some View {
        HStack {
            Button("Annuler") {
                onCancel()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Text("Recadrer")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button("Réinitialiser") {
                withAnimation(.easeOut(duration: 0.18)) {
                    framing = .identity
                }
                HapticManager.shared.impact(.light)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.7))
            .opacity(framing.isIdentity ? 0.35 : 1)
            .disabled(framing.isIdentity)
        }
    }

    private var framingCanvas: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))

            mediaLayer
                .frame(width: circleDiameter, height: circleDiameter)
                .scaleEffect(framing.scale)
                .offset(
                    x: CGFloat(framing.offsetX) * circleDiameter,
                    y: CGFloat(framing.offsetY) * circleDiameter
                )
                .frame(width: circleDiameter, height: circleDiameter)
                .clipShape(Circle())

            Circle()
                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2.5)

            // Croisillon discret pour centrer le visage.
            Circle()
                .strokeBorder(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 14]))
                .frame(width: circleDiameter * 0.42, height: circleDiameter * 0.42)
                .allowsHitTesting(false)
        }
        .contentShape(Circle())
        .gesture(dragGesture)
        .simultaneousGesture(magnificationGesture)
    }

    @ViewBuilder
    private var mediaLayer: some View {
        if let url = resolvedVideoURL {
            FaceScanSilentVideoLoopView(url: url)
        } else if let snapshot {
            Image(uiImage: snapshot)
                .resizable()
                .scaledToFill()
        } else {
            Color.white.opacity(0.08)
                .overlay {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                }
        }
    }

    private var bottomBar: some View {
        Button {
            HapticManager.shared.impact(.medium)
            onSave(framing.clamped())
        } label: {
            Text("Valider le cadrage")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color.white))
        }
        .buttonStyle(.plain)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let base = dragStart ?? framing
                if dragStart == nil { dragStart = framing }
                let next = FaceScanStudioFraming(
                    offsetX: base.offsetX + Double(value.translation.width / circleDiameter),
                    offsetY: base.offsetY + Double(value.translation.height / circleDiameter),
                    scale: base.scale
                )
                framing = next.clamped()
            }
            .onEnded { _ in
                dragStart = nil
                framing = framing.clamped()
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let start = pinchStartScale ?? framing.scale
                if pinchStartScale == nil { pinchStartScale = framing.scale }
                framing = FaceScanStudioFraming(
                    offsetX: framing.offsetX,
                    offsetY: framing.offsetY,
                    scale: start * Double(value)
                ).clamped()
            }
            .onEnded { _ in
                pinchStartScale = nil
                framing = framing.clamped()
            }
    }

    private func refreshMedia() {
        let reconciled = FaceScanImageStore.reconcileMediaMetadata(for: result)
        resolvedVideoURL = FaceScanImageStore.resolvedVideoURL(for: reconciled)
        if let filename = FaceScanImageStore.resolvedSnapshotFilename(for: reconciled) {
            snapshot = FaceScanImageStore.load(filename: filename)
        } else {
            snapshot = nil
        }
    }
}
