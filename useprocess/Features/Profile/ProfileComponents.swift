import SwiftUI
import UIKit

// MARK: - Top bar

struct ProfileTopBar: View {
    var onSettings: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            ProcessGlassIconButton(systemName: "gearshape.fill", iconSize: 18, action: onSettings)
        }
        .padding(.horizontal, ProfileTheme.horizontalPadding)
        .padding(.top, ProfileTheme.topSafeInset + 4)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(alignment: .top) {
            ProcessMainTopScrollBlur(
                visibility: 1,
                height: ProfileTheme.topBarBlurHeight
            )
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Empty hero (gradient + placeholder)

struct ProfileEmptyHeroSection: View {
    var onAddPhoto: () -> Void

    var body: some View {
        ZStack {
            ProfileEmptyHeroBackground()

            Button(action: onAddPhoto) {
                VStack(spacing: 10) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: ProfileTheme.emptyHeroIconSize, weight: .regular))
                        .foregroundStyle(ProfileTheme.textSecondary.opacity(0.85))

                    Text("Clique ici pour ajouter une photo de profil")
                        .font(.system(size: 14))
                        .foregroundStyle(ProfileTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, ProfileTheme.emptyHeroTopClearance + ProfileTheme.topSafeInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: ProfileTheme.emptyHeroTotalHeight)
        .frame(maxWidth: .infinity)
        .clipShape(ProfileTheme.heroBottomShape)
    }
}

// MARK: - Cover hero (with photo)

struct ProfileCoverPhotoSection: View {
    let image: UIImage
    let displayName: String
    let username: String
    let isPrivate: Bool
    var onChangePhoto: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .overlay(alignment: .top) {
                    ProcessMainTopScrollBlur(
                        visibility: 1,
                        height: ProfileTheme.heroTopBlurHeight
                    )
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.35), .black.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                }
                .overlay {
                    Button(action: onChangePhoto) {
                        ZStack {
                            Circle()
                                .fill(.black.opacity(0.38))
                                .frame(width: 58, height: 58)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Modifier la photo de profil")
                    .padding(.top, ProfileTheme.topSafeInset + ProfileTheme.heroHeight * 0.18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

            ProfileIdentityBlock(
                displayName: displayName,
                username: username,
                isPrivate: isPrivate,
                style: .overlay
            )
            .padding(.horizontal, ProfileTheme.horizontalPadding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: ProfileTheme.heroTotalHeight)
        .clipShape(ProfileTheme.heroBottomShape)
        .contentShape(ProfileTheme.heroBottomShape)
    }
}

enum ProfileIdentityStyle {
    case inline, overlay
}

struct ProfileIdentityBlock: View {
    let displayName: String
    let username: String
    let isPrivate: Bool
    var style: ProfileIdentityStyle = .inline

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayName)
                .font(.system(size: style == .overlay ? 30 : 26, weight: .bold))
                .foregroundStyle(ProfileTheme.textPrimary)

            HStack(spacing: 6) {
                Text("@\(username)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(style == .overlay ? .white.opacity(0.92) : ProfileTheme.textPrimary)

                if isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(style == .overlay ? .white.opacity(0.9) : ProfileTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileActionButtons: View {
    var onShare: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ProcessGlassWideButton(title: "Partager mon Profil", action: onShare)

            NavigationLink(value: ProfileRoute.editProfile) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .processGlassEffect(in: RoundedRectangle(cornerRadius: ProfileTheme.buttonCornerRadius, style: .continuous))
            .buttonStyle(ProcessGlassPressStyle())
        }
    }
}

// MARK: - Pins

struct ProfilePinsSection: View {
    let pins: [SocialProfilePin]
    var onAdd: () -> Void
    var onRemove: (SocialProfilePin) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pins")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(ProfileTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ProfileAddPinTile(action: onAdd)

                    ForEach(pins) { pin in
                        ProfilePinTile(pin: pin) {
                            onRemove(pin)
                        }
                    }
                }
            }
        }
    }
}

struct ProfileAddPinTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                .foregroundStyle(ProfileTheme.dashedBorder)
                .frame(width: ProfileTheme.pinWidth, height: ProfileTheme.pinHeight)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(ProfileTheme.textPrimary)
                }
        }
        .buttonStyle(ProfilePressStyle())
    }
}

struct ProfilePinTile: View {
    let pin: SocialProfilePin
    var onLongPress: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(pin.emoji)
                .font(.system(size: 34))
            Text(pin.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ProfileTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: ProfileTheme.pinWidth, height: ProfileTheme.pinHeight)
        .processGlassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onLongPressGesture { onLongPress() }
    }
}

// MARK: - Sheets

struct ProfileAddPinSheet: View {
    @Binding var title: String
    @Binding var emoji: String
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ProfileTheme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    TextField("Titre du pin", text: $title)
                        .font(.system(size: 17))
                        .foregroundStyle(ProfileTheme.textPrimary)
                        .padding(14)
                        .background(ProfileTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    TextField("Emoji", text: $emoji)
                        .font(.system(size: 17))
                        .foregroundStyle(ProfileTheme.textPrimary)
                        .padding(14)
                        .background(ProfileTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(16)
            }
            .navigationTitle("Nouveau Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        onSave()
                        dismiss()
                    }
                    .foregroundStyle(Color.processPrimary)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbarBackground(ProfileTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.medium])
    }
}

struct ProfileShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
