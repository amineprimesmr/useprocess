import SwiftUI
import UIKit

enum ProfileEditDestination: Hashable {
    case firstName
    case gender
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
        }
    }
    .processSettingsOpalPage()
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

@MainActor
private func saveProfileField(
    using profileService: UnifiedProfileService,
    dismiss: DismissAction,
    afterSave: (() -> Void)? = nil,
    update: @escaping (inout UnifiedUserProfile) -> Void
) {
    Task {
        await ProcessSettingsChangeFeedback.performSave {
            await persistProfileChanges(using: profileService, update: update)
            afterSave?()
        }
        dismiss()
    }
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
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(AppCopy.t("Comment t'appelles-tu ?", en: "What's your name?"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                Text(AppCopy.t("On l'utilisera quand on te parlera", en: "We'll use it when we talk to you"))
                    .font(.system(size: 17))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)

                ProcessSettingsOpalField(
                    text: $name,
                    placeholder: AppCopy.t("Ton prénom", en: "Your first name")
                )
                .focused($isFocused)
                .padding(.top, 32)

                Spacer(minLength: 0)
            }
        }
        .processSettingsStandardToolbar(
            title: AppCopy.t("Prénom", en: "First Name"),
            onBack: { dismiss() }
        )
        .processSettingsOpalPage()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProcessSettingsOpalGlowButton(
                title: AppCopy.continueCTA,
                disabled: trimmedName.isEmpty
            ) {
                saveProfileField(
                    using: profileService,
                    dismiss: dismiss,
                    afterSave: {
                        ProcessAnalytics.trackFirstNameSet(trimmedName, source: "profile_edit")
                        ProcessCreatorModeStore.shared.evaluate(firstName: trimmedName)
                    }
                ) {
                    $0.firstName = trimmedName
                }
            }
            .padding(.bottom, 10)
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
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(AppCopy.t("Quel est ton nom ?", en: "What's your last name?"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                Text(AppCopy.t("Il apparaît sur ton profil et dans les détails du compte.", en: "It appears on your profile and in your account details."))
                    .font(.system(size: 17))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)

                ProcessSettingsOpalField(
                    text: $lastName,
                    placeholder: AppCopy.t("Ton nom de famille", en: "Your last name")
                )
                .focused($isFocused)
                .padding(.top, 32)

                Spacer(minLength: 0)
            }
        }
        .processSettingsStandardToolbar(
            title: AppCopy.t("Nom de famille", en: "Last Name"),
            onBack: { dismiss() }
        )
        .processSettingsOpalPage()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProcessSettingsOpalGlowButton(
                title: AppCopy.save,
                disabled: trimmedLastName.isEmpty
            ) {
                saveProfileField(using: profileService, dismiss: dismiss) {
                    $0.lastName = trimmedLastName
                }
            }
            .padding(.bottom, 10)
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
    @State private var highlightedGender: Gender?

    init(initialValue: Gender) {
        _selectedGender = State(initialValue: initialValue)
    }

    var body: some View {
        ProcessSettingsOpalScrollPage(
            title: AppCopy.t("Sexe", en: "Gender")
        ) {
            ProcessSettingsOpalSectionTitle(title: AppCopy.t("Sexe", en: "Gender"))

            ProcessSettingsOpalCard {
                ForEach(Array(Gender.allCases.enumerated()), id: \.element) { index, gender in
                    if index > 0 { ProcessSettingsOpalRowDivider() }

                    Button {
                        ProcessSettingsChangeFeedback.performRowSelection(
                            highlight: $highlightedGender,
                            value: gender,
                            isSameValue: selectedGender == gender
                        ) {
                            selectedGender = gender
                        }
                    } label: {
                        ProcessSettingsOpalRow(
                            icon: "person.fill",
                            title: gender.displayName,
                            trailingIcon: selectedGender == gender
                                ? .status(AppCopy.t("Actif", en: "Active"))
                                : .none,
                            showsDivider: false
                        )
                        .processSettingsSelectionHighlight(
                            isHighlighted: highlightedGender == gender,
                            isActive: selectedGender == gender
                        )
                    }
                    .processSettingsOpalRowButton()
                }
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
        .processSettingsScrollToolBar(
            title: AppCopy.t("Sexe", en: "Gender"),
            titleAlignment: .center,
            onBack: { dismiss() },
            trailing: {
                ProcessSettingsSaveToolbarButton {
                    saveProfileField(using: profileService, dismiss: dismiss) {
                        $0.gender = selectedGender
                    }
                }
            }
        )
        .processSettingsOpalPage()
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
        ScrollView {
            VStack(spacing: 0) {
                Text(AppCopy.t("Écris quelque chose sur toi 💭", en: "Write something about yourself 💭"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                Text(AppCopy.t("Ce que tu aimes, ce que tu fais, ou tout ce qui te semble juste.", en: "What you like, what you do, or anything that feels right."))
                    .font(.system(size: 17))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)

                ProcessSettingsOpalField(
                    text: $bio,
                    placeholder: AppCopy.t("Ajoute ta bio", en: "Add your bio"),
                    axis: .vertical
                )
                .focused($isFocused)
                .padding(.top, 32)

                Text(bioCharacterLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processSettingsScrollToolBar(
            title: AppCopy.t("Bio", en: "Bio"),
            titleAlignment: .center,
            onBack: { dismiss() },
            trailing: {
                ProcessSettingsSaveToolbarButton {
                    Task {
                        await ProcessSettingsChangeFeedback.performSave {
                            save()
                        }
                        dismiss()
                    }
                }
            }
        )
        .processSettingsOpalPage()
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
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(AppCopy.t("Où tu étudies? 🎓", en: "Where do you study? 🎓"))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                Text(AppCopy.t("Ton école, ta filière, ou le campus où tu passes tes journées.", en: "Your school, major, or the campus where you spend your days."))
                    .font(.system(size: 17))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)

                ProcessSettingsOpalField(
                    text: $education,
                    placeholder: AppCopy.t("Ajoute ton école", en: "Add your school"),
                    textAlignment: .center
                )
                .focused($isFocused)
                .padding(.top, 32)

                Spacer(minLength: 0)
            }
        }
        .processSettingsStandardToolbar(
            title: AppCopy.t("Éducation", en: "Education"),
            onBack: { dismiss() }
        )
        .processSettingsOpalPage()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ProcessSettingsOpalGlowButton(
                title: AppCopy.save,
                disabled: trimmedEducation.isEmpty
            ) {
                Task {
                    await ProcessSettingsChangeFeedback.performSave {
                        save()
                    }
                    dismiss()
                }
            }
            .padding(.bottom, 10)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(spacing: 10) {
                        Text(AppCopy.t("Qu'est-ce qui te passionne en ce moment ? ✨", en: "What are you into right now? ✨"))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text(AppCopy.t("Musique, mèmes, cueillette de champignons : tout ce qui te passionne. Ajoute le tien si ce n'est pas répertorié.", en: "Music, memes, mushroom hunting—anything you're into. Add yours if it's not listed."))
                            .font(.system(size: 17))
                            .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }

                ProcessSettingsOpalField(
                    text: $searchText,
                    placeholder: AppCopy.t("Trouve ou ajoute ce que tu aimes...", en: "Find or add something you like...")
                )
                .focused($isSearchFocused)

                ForEach(filteredCategories) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category.title)
                            .font(.system(size: 13))
                            .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)

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
                        .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
                    }
                }

                Text(AppCopy.t("Choisis-en jusqu'à \(ProfileInterestsCatalog.maxSelection)", en: "Choose up to \(ProfileInterestsCatalog.maxSelection)"))
                    .font(.system(size: 13))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .processSettingsScrollToolBar(
            title: AppCopy.t("Intérêts", en: "Interests"),
            titleAlignment: .center,
            onBack: { dismiss() },
            trailing: {
                ProcessSettingsSaveToolbarButton {
                    Task {
                        await ProcessSettingsChangeFeedback.performSave {
                            save()
                        }
                        dismiss()
                    }
                }
            }
        )
        .processSettingsOpalPage()
    }

    private func toggle(_ interest: ProfileInterest) {
        if selectedIDs.contains(interest.id) {
            selectedIDs.remove(interest.id)
            ProcessSettingsChangeFeedback.playSelection()
            return
        }

        guard selectedIDs.count < ProfileInterestsCatalog.maxSelection else {
            HapticManager.shared.notification(.warning)
            return
        }
        selectedIDs.insert(interest.id)
        ProcessSettingsChangeFeedback.play()
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
