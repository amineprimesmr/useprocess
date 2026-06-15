import PhotosUI
import SwiftUI
import UIKit

struct CoachChatPhotoLibrarySheet: View {
    var onSelect: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var showCamera = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                CoachPHPickerGrid(onSelect: onSelect)
            }

            bottomFloatingBar
        }
        .overlay(alignment: .leading) {
            Button {
                showCamera = true
            } label: {
                Label("Caméra", systemImage: "camera")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if #available(iOS 26.0, *) {
                            Capsule().fill(.clear).glassEffect(ProcessGlass.regular, in: Capsule())
                        } else {
                            Capsule().fill(.regularMaterial)
                        }
                    }
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
            .padding(.bottom, 92)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CoachChatCameraSheet(
                onCapture: { image in
                    showCamera = false
                    onSelect(image)
                },
                onCancel: { showCamera = false }
            )
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button("Annuler", action: onCancel)
                .font(.system(size: 17))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text("Photos")
                .font(.system(size: 17, weight: .semibold))

            Spacer(minLength: 0)

            Color.clear.frame(width: 64, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var bottomFloatingBar: some View {
        HStack(spacing: 10) {
            floatingCapsule(width: 44) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
            }

            floatingCapsule(expanded: true) {
                Text("Sélectionner des photos")
                    .font(.system(size: 16, weight: .semibold))
            }

            floatingCapsule(width: 44) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 22)
    }

    private func floatingCapsule<Content: View>(
        width: CGFloat? = nil,
        expanded: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .foregroundStyle(.primary)
            .frame(width: width, height: 44)
            .frame(maxWidth: expanded ? .infinity : width)
            .background {
                if #available(iOS 26.0, *) {
                    Capsule().fill(.clear).glassEffect(ProcessGlass.regular, in: Capsule())
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

private struct CoachPHPickerGrid: UIViewControllerRepresentable {
    var onSelect: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSelect: onSelect) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (UIImage) -> Void
        init(onSelect: @escaping (UIImage) -> Void) { self.onSelect = onSelect }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    self.onSelect(image)
                }
            }
        }
    }
}
