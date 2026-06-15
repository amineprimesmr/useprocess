import SwiftUI
import UIKit

enum ProfileEditTheme {
    static let background = ProcessColors.background
    static let chipBackground = ProcessColors.secondaryBackground
    static let chipSelected = Color(.tertiarySystemBackground)
    static let headerButton = ProcessColors.secondaryBackground
    static let savePill = Color.primary.opacity(0.1)
    static let textSecondary = ProcessColors.textSecondary
    static let placeholder = Color(.placeholderText)
    static let separator = ProcessColors.border

    static let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)
}

struct ProfileEditorHeader: View {
    let title: String
    var showsSave: Bool = false
    var saveDisabled: Bool = false
    let onDismiss: () -> Void
    var onSave: (() -> Void)?

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)

            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 36, height: 36)
                        .background(ProfileEditTheme.headerButton)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                if showsSave, let onSave {
                    Button(action: onSave) {
                        Text("Enregistrer")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ProfileEditTheme.savePill)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(saveDisabled)
                    .opacity(saveDisabled ? 0.45 : 1)
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

struct ProfileEditorHero: View {
    let headline: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Text(headline)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(ProfileEditTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }
}

struct ProfileEditorBottomSaveButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.processPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(ProfileEditTheme.background)
    }
}

struct ProfileInterestChip: View {
    let interest: ProfileInterest
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interest.label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? ProfileEditTheme.chipSelected : ProfileEditTheme.chipBackground)
                .clipShape(Capsule())
                .overlay {
                    if isSelected {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(ProfileEditTheme.spring, value: isSelected)
    }
}

struct ProfileInterestFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct ProfileEditListRow: View {
    let label: String
    let value: String?
    let placeholder: String
    var showsAccentDot: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                if showsAccentDot {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.primary)
            }

            Spacer(minLength: 8)

            Text(value?.isEmpty == false ? value! : placeholder)
                .font(.system(size: 16))
                .foregroundStyle(value?.isEmpty == false ? ProfileEditTheme.textSecondary : ProfileEditTheme.placeholder)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProfileEditTheme.textSecondary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .contentShape(Rectangle())
    }
}

struct ProfileEditAvatarButton: View {
    let initials: String
    let image: UIImage?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle().fill(ProfileTheme.avatarAccent)
                        Text(initials.prefix(1).uppercased())
                            .font(.system(size: 58, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 118, height: 118)
            .clipShape(Circle())
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(Color.white)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                }
                .frame(width: 34, height: 34)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                }
                .offset(x: 2, y: 2)
                .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 28)
    }
}
