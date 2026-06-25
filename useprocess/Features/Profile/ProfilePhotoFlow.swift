import SwiftUI
import Photos
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
                Text("Recadre ta photo comme sur ton profil. L’avatar rond sera généré automatiquement.")
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
                        cropPayload = ProfileCropPayload(image: image.normalizedOrientation())
                    } else {
                        isPresented = false
                    }
                }
                .ignoresSafeArea()
            }
    }

    private func handleLibraryItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        let image = await loadFullResolutionImage(from: item)
        libraryItem = nil
        guard let image else { return }
        cropPayload = ProfileCropPayload(image: image)
    }

    private func loadFullResolutionImage(from item: PhotosPickerItem) async -> UIImage? {
        if let identifier = item.itemIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = assets.firstObject, let image = await requestFullSizeImage(for: asset) {
                return image.normalizedOrientation()
            }
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return nil }
        return image.normalizedOrientation()
    }

    private func requestFullSizeImage(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .none

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                guard let data, let image = UIImage(data: data) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: image)
            }
        }
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
    @State private var cropSize: CGSize = CGSize(width: 320, height: 244)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Recadrer")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                Text("Ajuste le cadrage — la Dynamic Island montre l’aperçu sur ton profil.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)

                GeometryReader { geo in
                    let size = coverCropSize(in: geo)
                    cropCanvas(cropSize: size)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear { cropSize = size }
                        .onChange(of: size) { _, newSize in cropSize = newSize }
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

    private func coverCropSize(in geo: GeometryProxy) -> CGSize {
        let width = min(ProfileTheme.heroCoverWidth, geo.size.width - 8)
        let height = width / ProfileTheme.heroCoverAspectRatio
        let maxHeight = max(180, geo.size.height - 8)
        if height <= maxHeight {
            return CGSize(width: width, height: height)
        }
        let fittedHeight = maxHeight
        let fittedWidth = fittedHeight * ProfileTheme.heroCoverAspectRatio
        return CGSize(width: fittedWidth, height: fittedHeight)
    }

    private func cropShapeScale(for cropSize: CGSize) -> CGFloat {
        cropSize.width / ProfileTheme.heroCoverWidth
    }

    @ViewBuilder
    private func cropCanvas(cropSize: CGSize) -> some View {
        let shape = ProfileTheme.heroBottomShape(scale: cropShapeScale(for: cropSize))

        ZStack {
            Image(uiImage: sourceImage)
                .resizable()
                .scaledToFill()
                .scaleEffect(userZoom)
                .offset(offset)
                .frame(width: cropSize.width, height: cropSize.height)
                .clipShape(shape)
                .overlay { cropMask(cropSize: cropSize, shape: shape) }
                .overlay {
                    ProfileCropSystemChromePreview(cropSize: cropSize)
                }
                .gesture(dragGesture(cropSize: cropSize))
                .simultaneousGesture(pinchGesture(cropSize: cropSize))
        }
    }

    private func cropMask(cropSize: CGSize, shape: UnevenRoundedRectangle) -> some View {
        ZStack {
            Color.black.opacity(0.62)
            shape
                .frame(width: cropSize.width, height: cropSize.height)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private func dragGesture(cropSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                baseOffset = clampedOffset(offset, cropSize: cropSize)
                offset = baseOffset
            }
    }

    private func pinchGesture(cropSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                userZoom = max(1, min(4, baseZoom * value))
            }
            .onEnded { _ in
                baseZoom = userZoom
                baseOffset = clampedOffset(offset, cropSize: cropSize)
                offset = baseOffset
            }
    }

    private func clampedOffset(_ proposed: CGSize, cropSize: CGSize) -> CGSize {
        let imageSize = sourceImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let fillScale = max(cropSize.width / imageSize.width, cropSize.height / imageSize.height)
        let displayW = imageSize.width * fillScale * userZoom
        let displayH = imageSize.height * fillScale * userZoom
        let maxX = max(0, (displayW - cropSize.width) / 2)
        let maxY = max(0, (displayH - cropSize.height) / 2)

        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func renderCroppedImage() -> UIImage? {
        guard let cropped = renderCroppedImage(for: cropSize) else { return nil }
        return cropped.resizedExactly(to: ProfileTheme.heroCoverExportSize)
    }

    private func renderCroppedImage(for outputSize: CGSize) -> UIImage? {
        let crop = outputSize
        let imageSize = sourceImage.size
        guard crop.width > 0, crop.height > 0, imageSize.width > 0, imageSize.height > 0 else { return nil }

        let previewScale = outputSize.width / max(cropSize.width, 1)
        let scaledOffset = CGSize(
            width: offset.width * previewScale,
            height: offset.height * previewScale
        )

        let fillScale = max(crop.width / imageSize.width, crop.height / imageSize.height)
        let drawW = imageSize.width * fillScale * userZoom
        let drawH = imageSize.height * fillScale * userZoom
        let origin = CGPoint(
            x: (crop.width - drawW) / 2 + scaledOffset.width,
            y: (crop.height - drawH) / 2 + scaledOffset.height
        )

        let uniformScale = drawW / imageSize.width
        var cropRect = CGRect(
            x: (-origin.x) / uniformScale,
            y: (-origin.y) / uniformScale,
            width: crop.width / uniformScale,
            height: crop.height / uniformScale
        )
        cropRect = cropRect.intersection(CGRect(origin: .zero, size: imageSize))
        guard cropRect.width > 1, cropRect.height > 1 else { return nil }

        guard let cgImage = sourceImage.cgImage else {
            return renderCroppedImageLegacy(
                cropSize: crop,
                drawW: drawW,
                drawH: drawH,
                origin: origin
            )
        }

        let pixelRect = CGRect(
            x: cropRect.origin.x * sourceImage.scale,
            y: cropRect.origin.y * sourceImage.scale,
            width: cropRect.width * sourceImage.scale,
            height: cropRect.height * sourceImage.scale
        ).integral

        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped, scale: sourceImage.scale, orientation: .up)
    }

    private func renderCroppedImageLegacy(
        cropSize: CGSize,
        drawW: CGFloat,
        drawH: CGFloat,
        origin: CGPoint
    ) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = sourceImage.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: cropSize, format: format)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: origin, size: CGSize(width: drawW, height: drawH)))
        }
    }
}

// MARK: - Aperçu Dynamic Island / encoche (non exporté)

private struct ProfileCropSystemChromePreview: View {
    let cropSize: CGSize

    private var scale: CGFloat {
        cropSize.width / ProfileTheme.heroCoverWidth
    }

    private var topSafeInset: CGFloat {
        ProcessMainChromeMetrics.topSafeInset
    }

    private var showsDynamicIsland: Bool {
        topSafeInset >= 59
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if showsDynamicIsland {
                    Capsule(style: .continuous)
                        .fill(Color.black)
                        .frame(
                            width: ProfileCropSystemChromePreview.dynamicIslandWidth * scale,
                            height: ProfileCropSystemChromePreview.dynamicIslandHeight * scale
                        )
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                } else if topSafeInset > 20 {
                    RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 154 * scale, height: 30 * scale)
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                }
            }
            .padding(.top, chromeTopPadding * scale)

            Spacer(minLength: 0)
        }
        .frame(width: cropSize.width, height: cropSize.height, alignment: .top)
        .allowsHitTesting(false)
    }

    private var chromeTopPadding: CGFloat {
        if showsDynamicIsland {
            return 11 + max(topSafeInset - 59, 0)
        }
        return 8
    }

    private static let dynamicIslandWidth: CGFloat = 126
    private static let dynamicIslandHeight: CGFloat = 37
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

extension UIImage {
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Extrait un carré centré pour l’avatar rond (Plan, Coach, édition profil).
    func profileAvatarSquareCrop() -> UIImage {
        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
            .intersection(CGRect(origin: .zero, size: size))

        guard let cgImage,
              cropRect.width > 1,
              cropRect.height > 1,
              let cropped = cgImage.cropping(to: CGRect(
                x: cropRect.origin.x * scale,
                y: cropRect.origin.y * scale,
                width: cropRect.width * scale,
                height: cropRect.height * scale
              ).integral) else {
            return self
        }

        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    func resizedExactly(to targetSize: CGSize) -> UIImage {
        guard targetSize.width > 0, targetSize.height > 0 else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
