import SwiftUI
import UIKit

enum ProfileEditDestination: Hashable {
    case firstName
    case gender
    case birthDate
}

@ViewBuilder
func profileFieldEditor(for destination: ProfileEditDestination) -> some View {
    Group {
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
        }
    }
    .processSettingsDetailPage()
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
                ProfileEditorHeader(title: AppCopy.t("Prénom", en: "First Name"), onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: AppCopy.t("Comment tu t'appelles ? 👋", en: "What's your name? 👋"),
                    subtitle: AppCopy.t("C'est le prénom qu'on utilise partout dans Process.", en: "This is the first name we use throughout Process.")
                )

                TextField("", text: $name, prompt:
                    Text(AppCopy.t("Ton prénom", en: "Your first name"))
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
                title: AppCopy.save,
                disabled: trimmedName.isEmpty
            ) {
                Task {
                    await persistProfileChanges(using: profileService) { $0.firstName = trimmedName }
                    ProcessAnalytics.trackFirstNameSet(trimmedName, source: "profile_edit")
                    ProcessCreatorModeStore.shared.evaluate(firstName: trimmedName)
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
                ProfileEditorHeader(title: AppCopy.t("Nom de famille", en: "Last Name"), onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: AppCopy.t("Quel est ton nom ?", en: "What's your last name?"),
                    subtitle: AppCopy.t("Il apparaît sur ton profil et dans les détails du compte.", en: "It appears on your profile and in your account details.")
                )

                TextField("", text: $lastName, prompt:
                    Text(AppCopy.t("Ton nom de famille", en: "Your last name"))
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
                title: AppCopy.save,
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
                    title: AppCopy.t("Sexe", en: "Gender"),
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
                        .buttonStyle(.processPlain)
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
                    title: AppCopy.t("Date de naissance", en: "Date of Birth"),
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
                .environment(\.locale, ProcessAppLanguage.shared.locale)
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
                    headline: AppCopy.t("Écris quelque chose sur toi 💭", en: "Write something about yourself 💭"),
                    subtitle: AppCopy.t("Ce que tu aimes, ce que tu fais, ou tout ce qui te semble juste.", en: "What you like, what you do, or anything that feels right.")
                )

                TextField(
                    "",
                    text: $bio,
                    prompt: Text(AppCopy.t("Ajoute ta bio", en: "Add your bio"))
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
        return count <= 1
            ? AppCopy.t("\(count) caractère", en: "\(count) character")
            : AppCopy.t("\(count) caractères", en: "\(count) characters")
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
                ProfileEditorHeader(title: AppCopy.t("Éducation", en: "Education"), onDismiss: { dismiss() })

                ProfileEditorHero(
                    headline: AppCopy.t("Où tu étudies? 🎓", en: "Where do you study? 🎓"),
                    subtitle: AppCopy.t("Ton école, ta filière, ou le campus où tu passes tes journées.", en: "Your school, major, or the campus where you spend your days.")
                )

                TextField("", text: $education, prompt:
                    Text(AppCopy.t("Ajoute ton école", en: "Add your school"))
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
                title: AppCopy.save,
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
                    title: AppCopy.t("Intérêts", en: "Interests"),
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
                                headline: AppCopy.t("Qu'est-ce qui te passionne en ce moment ? ✨", en: "What are you into right now? ✨"),
                                subtitle: AppCopy.t("Musique, mèmes, cueillette de champignons : tout ce qui te passionne. Ajoute le tien si ce n'est pas répertorié.", en: "Music, memes, mushroom hunting—anything you're into. Add yours if it's not listed.")
                            )
                            .padding(.bottom, 4)
                        }

                        TextField("", text: $searchText, prompt:
                            Text(AppCopy.t("Trouve ou ajoute ce que tu aimes...", en: "Find or add something you like..."))
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
            Text(AppCopy.t("Choisis-en jusqu'à \(ProfileInterestsCatalog.maxSelection)", en: "Choose up to \(ProfileInterestsCatalog.maxSelection)"))
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
