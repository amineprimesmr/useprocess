import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct FaceScanGalleryImportPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onVideoURL: (URL) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onVideoURL: onVideoURL, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (UIImage) -> Void
        let onVideoURL: (URL) -> Void
        let onCancel: () -> Void

        init(
            onImage: @escaping (UIImage) -> Void,
            onVideoURL: @escaping (URL) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onImage = onImage
            self.onVideoURL = onVideoURL
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                onCancel()
                return
            }

            let provider = result.itemProvider
            let videoTypes = [UTType.movie, .video, .mpeg4Movie, .quickTimeMovie]
                .map(\.identifier)
                .filter { provider.hasItemConformingToTypeIdentifier($0) }

            if let videoType = videoTypes.first {
                loadVideo(provider: provider, typeIdentifier: videoType)
                return
            }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        DispatchQueue.main.async { self.onImage(image) }
                    } else {
                        self.loadImageData(provider: provider)
                    }
                }
                return
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                loadImageData(provider: provider)
                return
            }

            onCancel()
        }

        private func loadVideo(provider: NSItemProvider, typeIdentifier: String) {
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, _ in
                guard let url else {
                    DispatchQueue.main.async { self.onCancel() }
                    return
                }
                let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
                let temp = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext)
                do {
                    if FileManager.default.fileExists(atPath: temp.path) {
                        try FileManager.default.removeItem(at: temp)
                    }
                    try FileManager.default.copyItem(at: url, to: temp)
                    DispatchQueue.main.async { self.onVideoURL(temp) }
                } catch {
                    DispatchQueue.main.async { self.onCancel() }
                }
            }
        }

        private func loadImageData(provider: NSItemProvider) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                guard let data, let image = UIImage(data: data) else {
                    DispatchQueue.main.async { self.onCancel() }
                    return
                }
                DispatchQueue.main.async { self.onImage(image) }
            }
        }
    }
}
