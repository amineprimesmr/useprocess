import SwiftUI
import PhotosUI
import UIKit

// MARK: - Photo flow coordinator

private struct ProfileCropPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

@MainActor
struct ProfilePhotoFlowModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var showSourceSheet = false
    @State private var cropPayload: ProfileCropPayload?
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?

    let hasExistingPhoto: Bool
    let onApply: (UIImage) -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, visible in
                if visible {
                    showSourceSheet = true
                } else {
                    showSourceSheet = false
                    cropPayload = nil
                }
            }
            .confirmationDialog(
                "Changer de photo de profil",
                isPresented: $showSourceSheet,
                titleVisibility: .visible
            ) {
                Button("Photothèque") {
                    showPhotoLibrary = true
                }
                Button("Appareil photo") {
                    showCamera = true
                }
                if hasExistingPhoto {
                    Button("Supprimer la photo de profil", role: .destructive) {
                        onDelete()
                        isPresented = false
                    }
                }
                Button("Annuler", role: .cancel) {
                    isPresented = false
                }
            } message: {
                Text("Ta photo de profil est visible par tous et permettra à tes amis de t'ajouter plus facilement.")
            }
            .onChange(of: showSourceSheet) { _, visible in
                guard !visible else { return }
                if !showPhotoLibrary && !showCamera && cropPayload == nil {
                    isPresented = false
                }
            }
            .fullScreenCover(item: $cropPayload) { payload in
                ProfileImageCropView(
                    sourceImage: payload.image.normalizedOrientation(),
                    onCancel: {
                        cropPayload = nil
                        isPresented = false
                    },
                    onChoose: { cropped in
                        onApply(cropped)
                        cropPayload = nil
                        isPresented = false
                    }
                )
            }
            .photosPicker(isPresented: $showPhotoLibrary, selection: $libraryItem, matching: .images)
            .onChange(of: libraryItem) { _, item in
                Task { await handleLibraryItem(item) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ProfileCameraPicker { image in
                    showCamera = false
                    if let image {
                        cropPayload = ProfileCropPayload(image: image)
                    } else {
                        isPresented = false
                    }
                }
                .ignoresSafeArea()
            }
    }

    private func handleLibraryItem(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        libraryItem = nil
        cropPayload = ProfileCropPayload(image: image)
    }
}

extension View {
    func profilePhotoFlow(
        isPresented: Binding<Bool>,
        hasExistingPhoto: Bool,
        onApply: @escaping (UIImage) -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        modifier(
            ProfilePhotoFlowModifier(
                isPresented: isPresented,
                hasExistingPhoto: hasExistingPhoto,
                onApply: onApply,
                onDelete: onDelete
            )
        )
    }
}

// MARK: - Crop

struct ProfileImageCropView: View {
    let sourceImage: UIImage
    var onCancel: () -> Void
    var onChoose: (UIImage) -> Void

    @State private var userZoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var cropSide: CGFloat = 300

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Recadrer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                GeometryReader { geo in
                    let side = min(geo.size.width - 32, geo.size.height)
                    cropCanvas(side: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear { cropSide = side }
                        .onChange(of: side) { _, newSide in cropSide = newSide }
                }

                HStack {
                    Button("Annuler", action: onCancel)
                    Spacer()
                    Button("Choisir") {
                        if let cropped = renderCroppedImage() {
                            onChoose(cropped)
                        }
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
    }

    @ViewBuilder
    private func cropCanvas(side: CGFloat) -> some View {
        ZStack {
            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFill()
                .scaleEffect(userZoom)
                .offset(offset)
                .frame(width: side, height: side)
                .clipped()
                .overlay { cropMask(side: side) }
                .gesture(dragGesture(side: side))
                .simultaneousGesture(pinchGesture)
        }
    }

    private func cropMask(side: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.62)
            Rectangle()
                .frame(width: side, height: side)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private func dragGesture(side: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                baseOffset = clampedOffset(offset, side: side)
                offset = baseOffset
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                userZoom = max(1, min(4, baseZoom * value))
            }
            .onEnded { _ in
                baseZoom = userZoom
                baseOffset = clampedOffset(offset, side: cropSide)
                offset = baseOffset
            }
    }

    private func clampedOffset(_ proposed: CGSize, side: CGFloat) -> CGSize {
        let imageSize = sourceImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let fillScale = max(side / imageSize.width, side / imageSize.height)
        let displayW = imageSize.width * fillScale * userZoom
        let displayH = imageSize.height * fillScale * userZoom
        let maxX = max(0, (displayW - side) / 2)
        let maxY = max(0, (displayH - side) / 2)

        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func renderCroppedImage() -> UIImage? {
        let side = cropSide
        let imageSize = sourceImage.size
        guard side > 0, imageSize.width > 0, imageSize.height > 0 else { return nil }

        let fillScale = max(side / imageSize.width, side / imageSize.height)
        let drawW = imageSize.width * fillScale * userZoom
        let drawH = imageSize.height * fillScale * userZoom
        let origin = CGPoint(
            x: (side - drawW) / 2 + offset.width,
            y: (side - drawH) / 2 + offset.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: origin, size: CGSize(width: drawW, height: drawH)))
        }
    }
}

// MARK: - Camera

struct ProfileCameraPicker: UIViewControllerRepresentable {
    var onComplete: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onComplete: (UIImage?) -> Void
        init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onComplete(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            onComplete(info[.originalImage] as? UIImage)
        }
    }
}

private extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
