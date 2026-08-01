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

    init(
        id: String,
        name: String,
        beforeImageName: String? = nil,
        afterImageName: String? = nil,
        beforeVideoName: String? = nil,
        afterVideoName: String? = nil,
        durationWeeks: Int,
        memberSince: String
    ) {
        self.id = id
        self.name = name
        self.beforeImageName = beforeImageName
        self.afterImageName = afterImageName
        self.beforeVideoName = beforeVideoName
        self.afterVideoName = afterVideoName
        self.durationWeeks = durationWeeks
        self.memberSince = memberSince
    }

    var usesVideo: Bool {
        beforeVideoName != nil && afterVideoName != nil
    }
}

enum TransformationCaseStudyCatalog {
    /// Ajoute une paire `avant` / `après` dans Assets + ProcessAssetCatalog pour l'afficher.
    static let all: [TransformationCaseStudy] = [
        .init(
            id: "imran",
            name: "Imran",
            beforeVideoName: "imran",
            afterVideoName: "imranprime",
            durationWeeks: 5,
            memberSince: "📅 Membre depuis mai 2026"
        ),
        .init(
            id: "daniel",
            name: "Daniel",
            beforeVideoName: "daniel",
            afterVideoName: "danielprime",
            durationWeeks: 4,
            memberSince: "📅 Membre depuis juin 2026"
        ),
        .init(
            id: "leo",
            name: "Léo",
            beforeImageName: "leo",
            afterImageName: "leoprime",
            durationWeeks: 3,
            memberSince: "📅 Membre depuis juin 2026"
        ),
        .init(
            id: "esteban",
            name: "Esteban",
            beforeImageName: "esteban",
            afterImageName: "estebanprime",
            durationWeeks: 8,
            memberSince: "📅 Membre depuis avr. 2026"
        ),
    ]

    static let transformedPeopleCount = 8500

    static func availableStudies() -> [TransformationCaseStudy] {
        all.filter { study in
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
    let onComplete: () -> Void

    private let availableCaseStudies = TransformationCaseStudyCatalog.availableStudies()

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
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
            (Text("Visualise ta ") + Text("transformation").foregroundColor(OnboardingTheme.accentHighlight))
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

            (Text("+\(TransformationCaseStudyCatalog.transformedPeopleCount) personnes")
                .fontWeight(.bold)
                .foregroundColor(OnboardingTheme.accentHighlight)
                + Text(" ont dégonflé leur visage avec Process"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OnboardingTheme.bodyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var communityAvatarNames: [String] {
        ["fille1", "gars1", "leo", "estebanprime", "imranprime"]
            .filter { ProcessAssetCatalog.contains($0) }
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
            Text("CONTINUER")
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
