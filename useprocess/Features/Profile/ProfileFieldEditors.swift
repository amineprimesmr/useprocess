import SwiftUI

enum ProfileEditDestination: Hashable {
    case firstName
}

enum ProfileRoute: Hashable {
    case editProfile
}

@ViewBuilder
func profileFieldEditor(for destination: ProfileEditDestination) -> some View {
    switch destination {
    case .firstName:
        ProfileNameEditorView(
            initialValue: UnifiedProfileService.shared.currentProfile?.firstName
                ?? SocialProfileStore.shared.profile?.displayName
                ?? ""
        )
    }
}

// MARK: - Name

struct ProfileNameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared
    @State private var name: String
    @FocusState private var isFocused: Bool

    init(initialValue: String) {
        _name = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            ProfileEditTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileEditorHeader(title: "Prénom", onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: "Comment tu t'appelles ? 👋",
                    subtitle: "C'est le prénom qu'on utilise partout dans Process AI."
                )

                TextField("", text: $name, prompt:
                    Text("Ton prénom")
                        .foregroundStyle(ProfileEditTheme.placeholder)
                        .font(.system(size: 28, weight: .bold))
                )
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .padding(.horizontal, 24)
                .padding(.top, 36)

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProfileEditorBottomSaveButton(
                title: "Enregistrer",
                disabled: trimmedName.isEmpty
            ) {
                save()
                dismiss()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }

        profileStore.update { profile in
            profile.displayName = trimmedName
        }

        Task {
            guard var unified = profileService.currentProfile else { return }
            unified.firstName = trimmedName
            unified.updateLastUpdated()
            try? await profileService.saveProfile(unified)
        }
    }
}

// MARK: - Username

struct ProfileUsernameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profileStore = SocialProfileStore.shared
    @State private var username: String
    @FocusState private var isFocused: Bool

    init(initialValue: String) {
        _username = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            ProfileEditTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileEditorHeader(title: "Nom d'utilisateur", onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: "Choisis ton @unique ✨",
                    subtitle: "C'est comme ça que les autres te trouveront sur Process."
                )

                TextField("", text: $username, prompt:
                    Text("Ajoute ton pseudo")
                        .foregroundStyle(ProfileEditTheme.placeholder)
                        .font(.system(size: 28, weight: .bold))
                )
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .padding(.horizontal, 24)
                .padding(.top, 36)

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProfileEditorBottomSaveButton(
                title: "Enregistrer",
                disabled: cleanedUsername.isEmpty
            ) {
                save()
                dismiss()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    private var cleanedUsername: String {
        username.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
    }

    private func save() {
        guard !cleanedUsername.isEmpty else { return }
        profileStore.update { $0.username = cleanedUsername }
    }
}

// MARK: - Bio

struct ProfileBioEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profileStore = SocialProfileStore.shared
    @State private var bio: String
    @FocusState private var isFocused: Bool

    init(initialValue: String) {
        _bio = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            ProfileEditTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileEditorHeader(
                    title: "Bio",
                    showsSave: true,
                    onDismiss: { dismiss() },
                    onSave: {
                        save()
                        dismiss()
                    }
                )

                ProfileEditorHero(
                    headline: "Écris quelque chose sur toi 💭",
                    subtitle: "Ce que tu aimes, ce que tu fais, ou tout ce qui te semble juste."
                )

                TextField(
                    "",
                    text: $bio,
                    prompt: Text("Ajoute ta bio")
                        .foregroundStyle(ProfileEditTheme.placeholder)
                        .font(.system(size: 22, weight: .bold)),
                    axis: .vertical
                )
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)
                .lineLimit(1...8)
                .focused($isFocused)
                .padding(.horizontal, 24)
                .padding(.top, 28)

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text(bioCharacterLabel)
                .font(.system(size: 13))
                .foregroundStyle(ProfileEditTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .background(ProfileEditTheme.background)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    private var bioCharacterLabel: String {
        let count = bio.count
        return count <= 1 ? "\(count) caractère" : "\(count) caractères"
    }

    private func save() {
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        profileStore.update { $0.bio = trimmed.isEmpty ? nil : trimmed }
    }
}

// MARK: - Education

struct ProfileEducationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profileStore = SocialProfileStore.shared
    @State private var education: String
    @FocusState private var isFocused: Bool

    init(initialValue: String) {
        _education = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            ProfileEditTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileEditorHeader(title: "Éducation", onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: "Où tu étudies? 🎓",
                    subtitle: "Ton école, ta filière, ou le campus où tu passes tes journées."
                )

                TextField("", text: $education, prompt:
                    Text("Ajoute ton école")
                        .foregroundStyle(ProfileEditTheme.placeholder)
                        .font(.system(size: 28, weight: .bold))
                )
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.center)
                .focused($isFocused)
                .padding(.horizontal, 24)
                .padding(.top, 36)

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProfileEditorBottomSaveButton(
                title: "Enregistrer",
                disabled: trimmedEducation.isEmpty
            ) {
                save()
                dismiss()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    private var trimmedEducation: String {
        education.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        profileStore.update { $0.education = trimmedEducation.isEmpty ? nil : trimmedEducation }
    }
}

// MARK: - Interests

struct ProfileInterestsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profileStore = SocialProfileStore.shared
    @State private var selectedIDs: Set<String>
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    init(initialIDs: [String]) {
        _selectedIDs = State(initialValue: Set(initialIDs))
    }

    private var filteredCategories: [ProfileInterestCategory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return ProfileInterestsCatalog.categories }

        return ProfileInterestsCatalog.categories.compactMap { category in
            let matches = category.interests.filter {
                $0.title.lowercased().contains(query) || $0.emoji.contains(query)
            }
            guard !matches.isEmpty else { return nil }
            return ProfileInterestCategory(id: category.id, title: category.title, interests: matches)
        }
    }

    var body: some View {
        ZStack {
            ProfileEditTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ProfileEditorHeader(
                    title: "Intérêts",
                    showsSave: true,
                    onDismiss: { dismiss() },
                    onSave: {
                        save()
                        dismiss()
                    }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ProfileEditorHero(
                                headline: "Qu'est-ce qui te passionne en ce moment ? ✨",
                                subtitle: "Musique, mèmes, cueillette de champignons : tout ce qui te passionne. Ajoute le tien si ce n'est pas répertorié."
                            )
                            .padding(.bottom, 4)
                        }

                        TextField("", text: $searchText, prompt:
                            Text("Trouve ou ajoute ce que tu aimes...")
                                .foregroundStyle(ProfileEditTheme.placeholder)
                                .font(.system(size: 22, weight: .bold))
                        )
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .focused($isSearchFocused)
                        .padding(.horizontal, 16)

                        ForEach(filteredCategories) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.title)
                                    .font(.system(size: 13))
                                    .foregroundStyle(ProfileEditTheme.textSecondary)
                                    .padding(.horizontal, 16)

                                ProfileInterestFlowLayout(spacing: 8) {
                                    ForEach(category.interests) { interest in
                                        ProfileInterestChip(
                                            interest: interest,
                                            isSelected: selectedIDs.contains(interest.id)
                                        ) {
                                            toggle(interest)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 72)
                }
                .scrollIndicators(.hidden)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottom) {
            Text("Choisis-en jusqu'à \(ProfileInterestsCatalog.maxSelection)")
                .font(.system(size: 13))
                .foregroundStyle(ProfileEditTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.clear, ProfileEditTheme.background.opacity(0.85), ProfileEditTheme.background],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private func toggle(_ interest: ProfileInterest) {
        if selectedIDs.contains(interest.id) {
            selectedIDs.remove(interest.id)
            return
        }

        guard selectedIDs.count < ProfileInterestsCatalog.maxSelection else { return }
        selectedIDs.insert(interest.id)
    }

    private func save() {
        let ordered = ProfileInterestsCatalog.allInterests
            .map(\.id)
            .filter { selectedIDs.contains($0) }

        profileStore.update { profile in
            profile.interestTags = ordered
            profile.interests = ProfileInterestsCatalog.summary(for: ordered)
        }
    }
}
