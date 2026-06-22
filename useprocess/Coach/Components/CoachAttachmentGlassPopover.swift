import SwiftUI

enum CoachAttachmentOption: String, CaseIterable, Identifiable {
    case camera
    case photos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: "Caméra"
        case .photos: "Photos"
        }
    }

    var icon: String {
        switch self {
        case .camera: "camera"
        case .photos: "photo.on.rectangle"
        }
    }
}

struct CoachAttachmentGlassPopover: View {
    var onSelect: (CoachAttachmentOption) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(CoachAttachmentOption.allCases) { option in
                Button {
                    HapticManager.shared.impact(.light)
                    onSelect(option)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 38, height: 38)
                            Image(systemName: option.icon)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.88))
                        }

                        Text(option.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.primary)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .processGlassMenuRowStyle()
            }
        }
        .padding(.vertical, 6)
        .frame(width: 232, alignment: .leading)
        .modifier(CoachAttachmentPopoverGlassModifier())
        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 10)
    }
}

private struct CoachAttachmentPopoverGlassModifier: ViewModifier {
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regularSurface, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}
