import SwiftUI
import UIKit

enum ProfileEditDestination: Hashable {
    case firstName
    case gender
    case birthDate
    case username
    case findUser
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
    case .gender:
        ProfileGenderEditorView(
            initialValue: UnifiedProfileService.shared.currentProfile?.gender ?? .male
        )
    case .birthDate:
        ProfileBirthDateEditorView(
            initialValue: UnifiedProfileService.shared.currentProfile?.birthDate
                ?? Calendar.current.date(byAdding: .year, value: -25, to: Date())
                ?? Date()
        )
    case .username:
        ProfileUsernameEditorView(
            initialValue: SocialProfileStore.shared.profile?.username
                ?? UnifiedProfileService.shared.currentProfile?.username
                ?? ""
        )
    case .findUser:
        ProcessFindUserByTagView()
    }
}

@MainActor
private func persistProfileChanges(
    using profileService: UnifiedProfileService,
    update: (inout UnifiedUserProfile) -> Void
) async {
    guard var unified = profileService.currentProfile else { return }
    update(&unified)
    unified.updateLastUpdated()
    try? await profileService.saveProfile(unified)
}

// MARK: - Name

struct ProfileNameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var name: String
    @FocusState private var isFocused: Bool

    init(initialValue: String) {
        _name = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
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
                Task {
                    await persistProfileChanges(using: profileService) { $0.firstName = trimmedName }
                    dismiss()
                }
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
}

// MARK: - Last name

struct ProfileLastNameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var lastName: String
    @FocusState private var isFocused: Bool

    init(initialValue: String) {
        _lastName = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileEditorHeader(title: "Nom de famille", onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: "Quel est ton nom ?",
                    subtitle: "Il apparaît sur ton profil et dans les détails du compte."
                )

                TextField("", text: $lastName, prompt:
                    Text("Ton nom de famille")
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
                disabled: trimmedLastName.isEmpty
            ) {
                Task {
                    await persistProfileChanges(using: profileService) { $0.lastName = trimmedLastName }
                    dismiss()
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    private var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Gender

struct ProfileGenderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var selectedGender: Gender

    init(initialValue: Gender) {
        _selectedGender = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileEditorHeader(
                    title: "Sexe",
                    showsSave: true,
                    onDismiss: { dismiss() },
                    onSave: {
                        Task {
                            await persistProfileChanges(using: profileService) { $0.gender = selectedGender }
                            dismiss()
                        }
                    }
                )

                AccountDetailsCard {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Button {
                            selectedGender = gender
                        } label: {
                            AccountDetailsGlassRow {
                                HStack {
                                    Text(gender.displayName)
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    if selectedGender == gender {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.primary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                .padding(.top, 20)

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Birth date

struct ProfileBirthDateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var birthDate: Date

    init(initialValue: Date) {
        _birthDate = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileEditorHeader(
                    title: "Date de naissance",
                    showsSave: true,
                    onDismiss: { dismiss() },
                    onSave: {
                        Task {
                            await persistProfileChanges(using: profileService) { profile in
                                profile.birthDate = birthDate
                                profile.age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? profile.age
                            }
                            dismiss()
                        }
                    }
                )

                DatePicker(
                    "",
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "fr_FR"))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .accountDetailsGlassRelief()
                .padding(.horizontal, AccountDetailsTheme.horizontalPadding)
                .padding(.top, 12)

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Username

struct ProfileUsernameEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService
    @State private var profileStore = SocialProfileStore.shared
    @State private var username: String
    @State private var availability: UsernameAvailability = .idle
    @State private var saveError: String?
    @State private var isSaving = false
    @FocusState private var isFocused: Bool
    @State private var availabilityTask: Task<Void, Never>?

    init(initialValue: String) {
        _username = State(initialValue: initialValue)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileEditorHeader(title: "Tag Process", onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: "Choisis ton @unique ✨",
                    subtitle: "C'est comme ça que les autres te trouveront sur Process."
                )

                HStack(spacing: 4) {
                    Text("@")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(ProfileEditTheme.placeholder)

                    TextField("", text: $username, prompt:
                        Text("ton_tag")
                            .foregroundStyle(ProfileEditTheme.placeholder)
                            .font(.system(size: 28, weight: .bold))
                    )
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)

                availabilityLabel
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                if let saveError {
                    Text(saveError)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                }

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProfileEditorBottomSaveButton(
                title: isSaving ? "Enregistrement…" : "Enregistrer",
                disabled: !canSave || isSaving
            ) {
                Task { await save() }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
            scheduleAvailabilityCheck()
        }
        .onChange(of: username) { _, _ in
            saveError = nil
            scheduleAvailabilityCheck()
        }
        .onDisappear {
            availabilityTask?.cancel()
        }
    }

    @ViewBuilder
    private var availabilityLabel: some View {
        switch availability {
        case .idle:
            Text("Lettres, chiffres, _ et . — \(ProcessUsernameTag.minLength) à \(ProcessUsernameTag.maxLength) caractères.")
                .font(.system(size: 14))
                .foregroundStyle(ProfileEditTheme.placeholder)
                .multilineTextAlignment(.center)
        case .checking:
            Text("Vérification…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ProfileEditTheme.placeholder)
        case .available:
            Label("Tag disponible", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.green)
        case .current:
            Label("C'est ton tag actuel", systemImage: "person.crop.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ProfileEditTheme.placeholder)
        case .taken:
            Label("Tag déjà pris", systemImage: "xmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.red)
        case .invalid(let message):
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
        }
    }

    private var cleanedUsername: String {
        ProcessUsernameTag.normalize(username)
    }

    private var currentUsername: String {
        ProcessUsernameTag.normalize(
            profileService.currentProfile?.username
                ?? profileStore.profile?.username
                ?? ""
        )
    }

    private var canSave: Bool {
        guard !cleanedUsername.isEmpty else { return false }
        switch availability {
        case .available, .current:
            return true
        default:
            return false
        }
    }

    private func scheduleAvailabilityCheck() {
        availabilityTask?.cancel()
        availabilityTask = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            await refreshAvailability()
        }
    }

    @MainActor
    private func refreshAvailability() async {
        let cleaned = cleanedUsername
        guard !cleaned.isEmpty else {
            availability = .idle
            return
        }

        if cleaned == currentUsername {
            availability = .current
            return
        }

        do {
            try ProcessUsernameTag.validate(cleaned)
        } catch let error as ProcessUsernameError {
            if case .invalid(let message) = error {
                availability = .invalid(message)
                return
            }
        } catch {
            availability = .invalid(error.localizedDescription)
            return
        }

        availability = .checking
        let userId = profileService.currentProfile?.userId ?? "local-user"

        do {
            let available = try await ProcessUsernameRegistry.shared.isAvailable(cleaned, for: userId)
            availability = available ? .available : .taken
        } catch {
            availability = .invalid(error.localizedDescription)
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        do {
            try await profileService.updateUsername(cleanedUsername)
            dismiss()
        } catch {
            saveError = error.localizedDescription
            await refreshAvailability()
        }
    }

    private enum UsernameAvailability {
        case idle
        case checking
        case available
        case current
        case taken
        case invalid(String)
    }
}

struct ProcessFindUserByTagView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var query = ""
    @State private var result: ProcessPublicUserTag?
    @State private var errorMessage: String?
    @State private var isSearching = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ProfileEditorHeader(title: "Trouver un utilisateur", onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: "Recherche par @",
                    subtitle: "Entre le tag Process de la personne que tu cherches."
                )

                HStack(spacing: 4) {
                    Text("@")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(ProfileEditTheme.placeholder)

                    TextField("", text: $query, prompt:
                        Text("tag")
                            .foregroundStyle(ProfileEditTheme.placeholder)
                            .font(.system(size: 28, weight: .bold))
                    )
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await search() }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 36)

                if isSearching {
                    ProgressView()
                        .padding(.top, 24)
                } else if let result {
                    VStack(spacing: 8) {
                        Text(result.displayName)
                            .font(.system(size: 22, weight: .bold))
                        Text(result.formattedTag)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(ProfileEditTheme.placeholder)

                        Button {
                            UIPasteboard.general.string = result.formattedTag
                            HapticManager.shared.notification(.success)
                        } label: {
                            Text("Copier le tag")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.processPrimary)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(.top, 28)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                }

                Spacer(minLength: 0)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProfileEditorBottomSaveButton(
                title: "Rechercher",
                disabled: ProcessUsernameTag.normalize(query).isEmpty || isSearching
            ) {
                Task { await search() }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFocused = true
            }
        }
    }

    @MainActor
    private func search() async {
        let tag = ProcessUsernameTag.normalize(query)
        guard !tag.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        result = nil
        defer { isSearching = false }

        do {
            try ProcessUsernameTag.validate(tag)
            result = try await profileService.lookupUser(byTag: tag)
        } catch {
            errorMessage = error.localizedDescription
        }
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
