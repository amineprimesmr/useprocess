//
//  OnboardingProfileChatSportPicker.swift
//  useprocess
//

import SwiftUI

struct OnboardingProfileChatSportPicker: View {
    @Binding var isSearching: Bool
    let isSubmitting: Bool
    var revealedOptionIDs: Set<String> = []
    let onSelectFeatured: (String) -> Void
    let onSelectSearched: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    private let buttonShape = Capsule()
    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.84)

    private var searchResults: [String] {
        OnboardingSportCatalog.search(searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isSearching {
                searchPanel
                    .transition(.opacity)
            } else {
                featuredPanel
                    .transition(.opacity)
            }
        }
        .animation(spring, value: isSearching)
        .onChange(of: isSearching) { _, searching in
            if !searching {
                searchText = ""
                isSearchFocused = false
            }
        }
    }

    private func isOptionRevealed(_ id: String) -> Bool {
        revealedOptionIDs.contains(id)
    }

    private var featuredPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(OnboardingSportCatalog.featuredChoices) { choice in
                sportButton(
                    title: OnboardingSportCatalog.localizedName(choice.label),
                    emoji: choice.emoji,
                    systemImage: nil
                ) {
                    guard !isSubmitting else { return }
                    onSelectFeatured(choice.id)
                }
                .onboardingChatAnswerReveal(isRevealed: isOptionRevealed(choice.id))
            }

            sportButton(
                title: OnboardingCopy.t("Chercher un sport", en: "Search for a sport"),
                emoji: nil,
                systemImage: "magnifyingglass"
            ) {
                guard !isSubmitting else { return }
                HapticManager.shared.selection()
                withAnimation(spring) {
                    isSearching = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    isSearchFocused = true
                }
            }
            .onboardingChatAnswerReveal(isRevealed: isOptionRevealed("sport_search"))
        }
    }

    private var searchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.mutedText)

                TextField(
                    OnboardingCopy.t("Rechercher un sport…", en: "Search for a sport…"),
                    text: $searchText
                )
                    .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize, weight: .medium))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .tint(OnboardingTheme.primaryText)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(spring) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(OnboardingTheme.mutedText)
                    }
                    .buttonStyle(.processPlain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .processGlassEffect(in: buttonShape)

            if !searchText.isEmpty {
                ForEach(searchResults, id: \.self) { sport in
                    sportButton(
                        title: OnboardingSportCatalog.localizedName(sport),
                        emoji: OnboardingSportCatalog.emoji(from: sport),
                        systemImage: nil
                    ) {
                        guard !isSubmitting else { return }
                        onSelectSearched(sport)
                    }
                }
            }
        }
    }

    private func sportButton(
        title: String,
        emoji: String?,
        systemImage: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 12) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 20))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme).opacity(0.72))
                        .frame(width: 22)
                }

                Text(title)
                    .font(.system(size: OnboardingProfileChatDepthStyle.answerFontSize, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                OnboardingTheme.filledButtonBackground(for: colorScheme),
                in: buttonShape
            )
            .contentShape(buttonShape)
        }
        .buttonStyle(MossChipPress())
        .disabled(isSubmitting)
    }
}
