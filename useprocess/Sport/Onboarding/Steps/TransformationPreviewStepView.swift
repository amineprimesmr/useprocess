//
//  TransformationPreviewStepView.swift
//  Process
//
//  Aperçu avant / après juste avant le paywall.
//

import SwiftUI

struct TransformationCaseStudy: Identifiable, Equatable {
    let id: String
    let name: String
    let beforeImageName: String?
    let afterImageName: String?
    let beforeVideoName: String?
    let afterVideoName: String?
    let durationWeeks: Int
    let memberSince: String
    /// Affiché aux utilisateurs de ce genre (`.other` / preferNotToSay → catalogue homme).
    let gender: Gender

    init(
        id: String,
        name: String,
        beforeImageName: String? = nil,
        afterImageName: String? = nil,
        beforeVideoName: String? = nil,
        afterVideoName: String? = nil,
        durationWeeks: Int,
        memberSince: String,
        gender: Gender = .male
    ) {
        self.id = id
        self.name = name
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self.beforeVideoName = beforeVideoName
        self.afterVideoName = afterVideoName
        self.durationWeeks = durationWeeks
        self.memberSince = memberSince
        self.gender = gender
    }

    var usesVideo: Bool {
        beforeVideoName != nil && afterVideoName != nil
    }

    @MainActor
    var localizedMemberSince: String {
        let monthEN: String
        switch memberSince {
        case "juin 2026": monthEN = "June 2026"
        case "avr. 2026": monthEN = "Apr 2026"
        case "juil. 2026": monthEN = "Jul 2026"
        case "mai 2026": monthEN = "May 2026"
        case "mars 2026": monthEN = "Mar 2026"
        default: monthEN = memberSince
        }
        return OnboardingCopy.t("📅 Membre depuis \(memberSince)", en: "📅 Member since \(monthEN)")
    }
}

enum TransformationCaseStudyCatalog {
    /// Ajoute une paire `avant` / `après` dans Assets + ProcessAssetCatalog pour l'afficher.
    static let all: [TransformationCaseStudy] = [
        // Hommes
        .init(
            id: "leo",
            name: "Enzo",
            beforeImageName: "leo",
            afterImageName: "leoprime",
            durationWeeks: 3,
            memberSince: "juin 2026",
            gender: .male
        ),
        .init(
            id: "daniel",
            name: "Daniel",
            beforeImageName: "daniel",
            afterImageName: "danielprime",
            durationWeeks: 4,
            memberSince: "juin 2026",
            gender: .male
        ),
        .init(
            id: "esteban",
            name: "Amir",
            beforeImageName: "esteban",
            afterImageName: "estebanprime",
            durationWeeks: 8,
            memberSince: "avr. 2026",
            gender: .male
        ),
        .init(
            id: "lucas",
            name: "Ken",
            beforeImageName: "lucas",
            afterImageName: "lucasprime",
            durationWeeks: 6,
            memberSince: "juil. 2026",
            gender: .male
        ),
        .init(
            id: "imran",
            name: "Malik",
            beforeImageName: "imran",
            afterImageName: "imranprime",
            durationWeeks: 5,
            memberSince: "mai 2026",
            gender: .male
        ),
        // Femmes
        .init(
            id: "ines",
            name: "Inès",
            beforeImageName: "ines",
            afterImageName: "inesprime",
            durationWeeks: 4,
            memberSince: "juin 2026",
            gender: .female
        ),
        .init(
            id: "maya",
            name: "Maya",
            beforeImageName: "maya",
            afterImageName: "mayaprime",
            durationWeeks: 5,
            memberSince: "mai 2026",
            gender: .female
        ),
        .init(
            id: "emma",
            name: "Emma",
            beforeImageName: "emma",
            afterImageName: "emmaprime",
            durationWeeks: 6,
            memberSince: "avr. 2026",
            gender: .female
        ),
        .init(
            id: "ava",
            name: "Ava",
            beforeImageName: "ava",
            afterImageName: "avaprime",
            durationWeeks: 7,
            memberSince: "mars 2026",
            gender: .female
        ),
    ]

    static let transformedPeopleCount = 8500

    static func catalogGender(for gender: Gender?) -> Gender {
        gender == .female ? .female : .male
    }

    static func availableStudies(for gender: Gender? = nil) -> [TransformationCaseStudy] {
        let target = catalogGender(for: gender)
        return all.filter { study in
            guard study.gender == target else { return false }
            if study.usesVideo {
                return TransformationBundledVideo.url(for: study.beforeVideoName) != nil
                    && TransformationBundledVideo.url(for: study.afterVideoName) != nil
            }
            guard let before = study.beforeImageName, let after = study.afterImageName else {
                return false
            }
            return ProcessAssetCatalog.contains(before)
                && ProcessAssetCatalog.contains(after)
        }
    }
}

struct TransformationPreviewStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    let gender: Gender?
    let onComplete: () -> Void

    private var availableCaseStudies: [TransformationCaseStudy] {
        TransformationCaseStudyCatalog.availableStudies(for: gender)
    }

    init(gender: Gender? = nil, onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.gender = gender
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 28) {
                    header

                    ForEach(Array(availableCaseStudies.enumerated()), id: \.element.id) { index, study in
                        TransformationCaseStudyCard(
                            study: study,
                            playsIntroHint: index == 0
                        )
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, OnboardingConstants.backOnlyContentTopInset)
                .padding(.bottom, 24)
            }

            continueButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(spacing: 14) {
            (Text(OnboardingCopy.t("Visualise ta ", en: "See your "))
                + Text(OnboardingCopy.t("transformation", en: "transformation")).foregroundColor(OnboardingTheme.accentHighlight))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)

            socialProofRow
        }
        .padding(.horizontal, 28)
    }

    private var socialProofRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: -10) {
                ForEach(communityAvatarNames, id: \.self) { name in
                    communityAvatar(name)
                }
            }

            (Text(OnboardingCopy.t(
                "+\(TransformationCaseStudyCatalog.transformedPeopleCount) personnes",
                en: "+\(TransformationCaseStudyCatalog.transformedPeopleCount) people"
            ))
                .fontWeight(.bold)
                .foregroundColor(OnboardingTheme.accentHighlight)
                + Text(OnboardingCopy.t(" ont dégonflé leur visage avec Process", en: " debloated their face with Process")))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OnboardingTheme.bodyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var communityAvatarNames: [String] {
        let female = ["fille1", "ines", "inesprime", "maya", "mayaprime", "emma", "emmaprime", "ava", "avaprime", "femme"]
        let male = ["gars1", "leo", "estebanprime", "lucasprime", "imranprime", "homme"]
        let preferred = TransformationCaseStudyCatalog.catalogGender(for: gender) == .female ? female : male
        return preferred.filter { ProcessAssetCatalog.contains($0) }
    }

    private func communityAvatar(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(OnboardingTheme.screenBackground, lineWidth: 2)
            }
    }

    private var continueButton: some View {
        Button {
            HapticManager.shared.impact(.medium)
            onComplete()
        } label: {
            Text(OnboardingCopy.continueCTAUpper)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
        }
        .onboardingPrimaryActionStyle()
        .padding(.horizontal, 34)
        .padding(.top, 8)
        .padding(.bottom, 50)
    }
}
