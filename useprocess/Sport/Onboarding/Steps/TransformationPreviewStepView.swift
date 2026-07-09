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

    static let additionalTransformationsCount = 450

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

                    communityProofBanner
                }
                .padding(.top, OnboardingConstants.backOnlyContentTopInset)
                .padding(.bottom, 24)
            }

            continueButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(spacing: 12) {
            (Text("Visualise ta ") + Text("transformation").foregroundColor(OnboardingTheme.accentHighlight))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)

            Text("Swipe le curseur pour comparer · scroll pour voir les autres")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OnboardingTheme.bodyText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private var communityProofBanner: some View {
        VStack(spacing: 14) {
            HStack(spacing: -12) {
                communityAvatar("fille1")
                communityAvatar("gars1")
                plusCountBadge
            }

            (Text("Et ") + Text("+\(TransformationCaseStudyCatalog.additionalTransformationsCount) personnes")
                .fontWeight(.bold)
                .foregroundColor(OnboardingTheme.accentHighlight)
                + Text(" ont transformé leur physique avec Process"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OnboardingTheme.bodyText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OnboardingTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1)
                }
        }
        .padding(.horizontal, 24)
    }

    private func communityAvatar(_ imageName: String) -> some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(OnboardingTheme.screenBackground, lineWidth: 2)
            }
    }

    private var plusCountBadge: some View {
        Text("+\(TransformationCaseStudyCatalog.additionalTransformationsCount)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(OnboardingTheme.primaryText)
            .frame(width: 40, height: 40)
            .background {
                Circle()
                    .fill(OnboardingTheme.mutedFill)
                    .overlay {
                        Circle()
                            .strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1)
                    }
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
