import SwiftUI

struct OnboardingCreatorCodeStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var referralCode: String?
    @State private var draftCode: String = ""
    @State private var resolvedDisplayName: String?
    @State private var resolvedKind: ProcessAffiliateCodeKind?
    @State private var isResolving = false
    @FocusState private var isFocused: Bool

    var onContinue: () -> Void
    var onSkip: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                VStack(spacing: 12) {
                    Text(AppCopy.t("Un code créateur ?", en: "Got a creator code?"))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(
                        AppCopy.t(
                            "Facultatif — entre le code de ton créateur ou d’un ami.",
                            en: "Optional — enter your creator or friend’s code."
                        )
                    )
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing + 48)

                TextField(
                    "",
                    text: $draftCode,
                    prompt: Text(AppCopy.t("Ex. MANNY", en: "e.g. MANNY"))
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(OnboardingTheme.mutedText)
                )
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .tint(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .focused($isFocused)
                .submitLabel(.continue)
                .onSubmit { submit() }
                .padding(.horizontal, 24)

                if let resolvedDisplayName, let resolvedKind {
                    Text(resolvedLabel(kind: resolvedKind, name: resolvedDisplayName))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(OnboardingTheme.mutedText)
                        .padding(.top, 12)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: submit) {
                        Text(AppCopy.continueCTA)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.onboardingPrimaryActionText(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .onboardingPrimaryActionStyle()
                    .disabled(normalizedDraft.isEmpty)
                    .opacity(normalizedDraft.isEmpty ? 0.45 : 1)

                    Button(action: skip) {
                        Text(AppCopy.t("Passer", en: "Skip"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OnboardingTheme.mutedText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            if let existing = referralCode, !existing.isEmpty {
                draftCode = existing
            } else if let pending = ProcessReferralAttribution.pendingCode ?? ProcessAffiliateAttribution.pendingCode {
                draftCode = pending
            }
            isFocused = true
            Task { await resolveDraftIfNeeded() }
        }
        .onChange(of: draftCode) { _, _ in
            Task { await resolveDraftIfNeeded() }
        }
    }

    private var normalizedDraft: String {
        ProcessAffiliateLink.normalizeCode(draftCode)
    }

    private func resolvedLabel(kind: ProcessAffiliateCodeKind, name: String) -> String {
        switch kind {
        case .affiliate:
            return AppCopy.t("Créateur : \(name)", en: "Creator: \(name)")
        case .referral:
            return AppCopy.t("Parrainage : \(name)", en: "Referral: \(name)")
        }
    }

    private func submit() {
        let normalized = normalizedDraft
        if normalized.isEmpty {
            skip()
            return
        }
        referralCode = normalized
        ProcessAcquisitionAttribution.captureReferralCode(normalized)
        ProcessAcquisitionAttribution.captureAffiliateCode(normalized)
        HapticManager.shared.impact(.medium)
        onContinue()
    }

    private func skip() {
        referralCode = nil
        ProcessReferralAttribution.clearPending()
        ProcessAffiliateAttribution.clearPending()
        onSkip()
    }

    private func resolveDraftIfNeeded() async {
        let normalized = normalizedDraft
        guard normalized.count >= 3 else {
            resolvedDisplayName = nil
            resolvedKind = nil
            return
        }
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false }

        if let resolved = await AffiliateService.shared.resolveCode(normalized) {
            resolvedDisplayName = resolved.displayName ?? normalized
            resolvedKind = resolved.type
        } else {
            resolvedDisplayName = nil
            resolvedKind = nil
        }
    }
}
