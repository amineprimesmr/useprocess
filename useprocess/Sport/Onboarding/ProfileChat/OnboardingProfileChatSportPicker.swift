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

    private let buttonShape = Capsule(style: .continuous)
    private let spring = Animation.spring(response: 0.42, dampingFraction: 0.84)

    private var searchResults: [String] {
        OnboardingSportCatalog.search(searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MossAnswerChipMetrics.stackSpacing) {
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
        VStack(alignment: .leading, spacing: MossAnswerChipMetrics.stackSpacing) {
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
        VStack(alignment: .leading, spacing: MossAnswerChipMetrics.stackSpacing) {
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
            HStack(spacing: 8) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 16))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme).opacity(0.72))
                        .frame(width: 18)
                }

                Text(title)
                    .font(.system(size: MossAnswerChipMetrics.fontSize, weight: .medium))
                    .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: MossAnswerChipMetrics.maxChipWidth, alignment: .leading)
            }
            .padding(.horizontal, MossAnswerChipMetrics.horizontalPadding)
            .padding(.vertical, MossAnswerChipMetrics.verticalPadding)
            .contentShape(buttonShape)
        }
        .processGlassButton(in: buttonShape)
        .fixedSize(horizontal: true, vertical: false)
        .disabled(isSubmitting)
    }
}
