import AuthenticationServices
import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @Bindable private var session = AppSession.shared
    @State private var profileStore = SocialProfileStore.shared
    @State private var showPhotoFlow = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteErrorMessage: String?

    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var initials: String {
        let first = profile?.firstName.first.map(String.init) ?? "?"
        let last = profile?.lastName?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    private var fullName: String {
        if let profile {
            return profile.fullName
        }
        return profileStore.profile?.displayName ?? "Mon profil"
    }

    private var ageText: String? {
        guard let profile, profile.age > 0 else { return nil }
        return profile.ageFormatted
    }

    var body: some View {
        ZStack {
            AccountDetailsTheme.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                AccountDetailsGlassHeader(
                    onBack: { dismiss() },
                    onSave: { dismiss() },
                    saveDisabled: true
                )

                ScrollView {
                    VStack(spacing: 0) {
                        AccountDetailsAvatarSection(
                            fullName: fullName,
                            initials: initials,
                            image: profileStore.profilePhoto,
                            onChangePhoto: { showPhotoFlow = true }
                        )

                        accountFieldsSection
                            .padding(.horizontal, AccountDetailsTheme.horizontalPadding)

                        VStack(spacing: AccountDetailsTheme.rowSpacing) {
                            AccountDetailsActionButton(title: "Se déconnecter") {
                                showLogoutConfirm = true
                            }

                            AccountDetailsActionButton(title: "Supprimer le compte", destructive: true) {
                                showDeleteAlert = true
                            }
                        }
                        .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                        .padding(.top, 24)
                    }
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .profilePhotoFlow(
            isPresented: $showPhotoFlow,
            hasExistingPhoto: profileStore.hasProfilePhoto,
            onApply: { image in
                withAnimation(ProfileEditTheme.spring) {
                    profileStore.applyPhotos(image)
                }
            },
            onDelete: {
                withAnimation(ProfileEditTheme.spring) {
                    profileStore.removeAllPhotos()
                }
            }
        )
        .confirmationDialog(
            "Se déconnecter ?",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("Se déconnecter", role: .destructive) {
                AuthenticationManager.shared.signOut()
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Supprimer le compte ?",
            isPresented: $showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Supprimer le compte", role: .destructive) {
                Task { await performAccountDeletion() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est définitive. Toutes tes données seront effacées et tu reviendras au début de Process.")
        }
        .alert(
            "Suppression impossible",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { if !$0 { deleteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "Réessaie dans un instant.")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Suppression du compte…")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .allowsHitTesting(!isDeletingAccount)
        .task {
            if profileService.currentProfile == nil {
                await profileService.loadProfile()
            }
            profileStore.bind(unified: profileService.currentProfile)
        }
        .onAppear {
            profileStore.bind(unified: profileService.currentProfile)
        }
    }

    private func performAccountDeletion() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await session.deleteAccount()
            dismiss()
        } catch let error as AccountDeletionError {
            if case .cancelled = error { return }
            deleteErrorMessage = error.localizedDescription
        } catch {
            if (error as NSError).domain == ASAuthorizationError.errorDomain,
               (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return
            }
            deleteErrorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var accountFieldsSection: some View {
        AccountDetailsCard {
            NavigationLink(value: ProfileEditDestination.firstName) {
                AccountDetailsGlassRow {
                    ProfileEditListRow(
                        label: "Prénom",
                        value: profile?.firstName,
                        placeholder: "Non renseigné",
                        showsChevron: false
                    )
                }
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileEditDestination.lastName) {
                AccountDetailsGlassRow {
                    ProfileEditListRow(
                        label: "Nom de famille",
                        value: profile?.lastName,
                        placeholder: "Non renseigné",
                        showsChevron: false
                    )
                }
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileEditDestination.gender) {
                AccountDetailsGlassRow {
                    ProfileEditListRow(
                        label: "Sexe",
                        value: profile?.gender.displayName,
                        placeholder: "Non renseigné"
                    )
                }
            }
            .buttonStyle(.plain)

            NavigationLink(value: ProfileEditDestination.birthDate) {
                AccountDetailsGlassRow {
                    ProfileEditListRow(
                        label: "Date de naissance",
                        value: birthDateDisplay,
                        placeholder: "Non renseigné"
                    )
                }
            }
            .buttonStyle(.plain)

            AccountDetailsGlassRow {
                ProfileEditListRow(
                    label: "Âge",
                    value: ageText,
                    placeholder: "—",
                    showsChevron: false,
                    valueIsMuted: true
                )
            }
        }
    }

    private var birthDateDisplay: String? {
        guard let profile else { return nil }
        return Self.birthDateFormatter.string(from: profile.birthDate)
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()
}
