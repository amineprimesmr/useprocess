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
            showsBackButton: false,
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


// MARK: - Education


// MARK: - Interests

