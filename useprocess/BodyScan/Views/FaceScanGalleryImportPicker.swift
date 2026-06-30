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

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url else {
                        DispatchQueue.main.async { self.onCancel() }
                        return
                    }
                    let temp = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(url.pathExtension.isEmpty ? "mp4" : url.pathExtension)
                    do {
                        if FileManager.default.fileExists(atPath: temp.path) {
                            try FileManager.default.removeItem(at: temp)
                        }
                        try FileManager.default.copyItem(at: url, to: temp)
                        DispatchQueue.main.async {
                            self.onVideoURL(temp)
                        }
                    } catch {
                        DispatchQueue.main.async { self.onCancel() }
                    }
                }
                return
            }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    guard let image = object as? UIImage else {
                        DispatchQueue.main.async { self.onCancel() }
                        return
                    }
                    DispatchQueue.main.async {
                        self.onImage(image)
                    }
                }
                return
            }

            onCancel()
        }
    }
}
