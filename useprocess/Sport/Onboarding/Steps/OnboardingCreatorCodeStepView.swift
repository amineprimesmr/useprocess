import SwiftUI

struct OnboardingCreatorCodeStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @Binding var draftCode: String
    @Binding var isVerified: Bool
    var continueAttempt: Int = 0
    var onAutoContinue: () -> Void = {}
    var onSkip: () -> Void = {}

    @State private var resolvedDisplayName: String?
    @State private var resolvedKind: ProcessAffiliateCodeKind?
    @State private var showsLifetimePass = false
    @State private var showsInvalidCodeFeedback = false
    @State private var showsIncompleteCodeFeedback = false
    @State private var codeShakePhase: CGFloat = 0
    @State private var isResolving = false
    @State private var resolveGeneration = 0
    @FocusState private var isFocused: Bool

    private let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
    private let maxCodeLength = ProcessReferralCode.length

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing + 72)

                TextField(
                    "",
                    text: $draftCode,
                    prompt: Text(
                        AppCopy.t(
                            "As-tu un code de parrainage ?",
                            en: "Do you have a referral code?"
                        )
                    )
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(OnboardingTheme.mutedText)
                )
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .tint(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .keyboardType(.asciiCapable)
                .submitLabel(.continue)
                .onSubmit(handleKeyboardSubmit)
                .modifier(OnboardingHorizontalShakeEffect(shakes: codeShakePhase))
                .padding(.horizontal, 40)
                .accessibilityLabel(
                    AppCopy.t("Code de parrainage", en: "Referral code")
                )

                Text(
                    AppCopy.t(
                        "Tu peux passer cette étape",
                        en: "You can skip this step"
                    )
                )
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(OnboardingTheme.mutedText)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 40)

                if showsLifetimePass {
                    lifetimePassBadge
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if let resolvedDisplayName, let resolvedKind {
                    resolvedBadge(kind: resolvedKind, name: resolvedDisplayName)
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if showsInvalidCodeFeedback {
                    invalidCodeMessage
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if showsIncompleteCodeFeedback {
                    incompleteCodeMessage
                        .padding(.top, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingTransitionTiming.earlyKeyboardFocusDelay) {
                isFocused = true
            }
            resolveGeneration += 1
            let generation = resolveGeneration
            Task { await resolveDraftIfNeeded(generation: generation) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .inactive || phase == .background {
                isFocused = false
            }
        }
        .onChange(of: continueAttempt) { _, newValue in
            guard newValue > 0 else { return }
            handleContinueRejected()
        }
        .onChange(of: draftCode) { _, newValue in
            let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
            let clipped = String(filtered.prefix(maxCodeLength))
            if clipped != newValue {
                draftCode = clipped
                return
            }
            if showsInvalidCodeFeedback || showsIncompleteCodeFeedback {
                withAnimation(.smooth(duration: 0.18)) {
                    clearCodeFeedback()
                }
            }
            if isVerified {
                isVerified = false
            }
            if showsLifetimePass {
                showsLifetimePass = false
            }
            resolveGeneration += 1
            let generation = resolveGeneration
            Task { await resolveDraftIfNeeded(generation: generation) }
        }
        .onDisappear {
            isFocused = false
        }
    }

    private var incompleteCodeMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.orange.opacity(0.92))

            Text(
                AppCopy.t(
                    "Entre les 5 caractères du code.",
                    en: "Enter all 5 code characters."
                )
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(OnboardingTheme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.14 : 0.10))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private var invalidCodeMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.red.opacity(0.88))

            Text(
                AppCopy.t(
                    "Code introuvable. Vérifie et réessaie.",
                    en: "Code not found. Check and try again."
                )
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(OnboardingTheme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(Color.red.opacity(colorScheme == .dark ? 0.14 : 0.10))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.red.opacity(0.28), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func resolvedBadge(kind: ProcessAffiliateCodeKind, name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: kind == .affiliate ? "checkmark.seal.fill" : "person.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accentBlue)

            Text(resolvedLabel(kind: kind, name: name))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(accentBlue.opacity(colorScheme == .dark ? 0.14 : 0.10))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(accentBlue.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var lifetimePassBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text(
                AppCopy.t(
                    "Accès offert à vie",
                    en: "Lifetime access unlocked"
                )
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(OnboardingTheme.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule(style: .continuous)
                .fill(Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.10))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.28), lineWidth: 1)
                }
        }
    }

    private func handleKeyboardSubmit() {
        if isVerified {
            HapticManager.shared.impact(.medium)
            isFocused = false
            onAutoContinue()
            return
        }
        if normalizedDraft.isEmpty {
            HapticManager.shared.impact(.medium)
            isFocused = false
            onSkip()
            return
        }
        handleContinueRejected()
    }

    private var normalizedDraft: String {
        ProcessReferralCode.normalize(draftCode)
    }

    private func resolvedLabel(kind: ProcessAffiliateCodeKind, name: String) -> String {
        switch kind {
        case .affiliate:
            return AppCopy.t("Clipper : \(name)", en: "Clipper: \(name)")
        case .referral:
            return AppCopy.t("Parrainage : \(name)", en: "Referral: \(name)")
        }
    }

    private func resolveDraftIfNeeded(generation: Int) async {
        guard generation == resolveGeneration else { return }

        let normalized = normalizedDraft
        guard ProcessReferralCode.isValid(normalized) else {
            await MainActor.run {
                guard generation == resolveGeneration else { return }
                withAnimation(.smooth(duration: 0.22)) {
                    resolvedDisplayName = nil
                    resolvedKind = nil
                    showsLifetimePass = false
                    clearCodeFeedback()
                }
                isVerified = false
            }
            return
        }

        if ProcessAffiliateLifetimePass.matches(normalized) {
            await MainActor.run {
                guard generation == resolveGeneration else { return }
                isResolving = false
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showsLifetimePass = true
                    resolvedDisplayName = nil
                    resolvedKind = nil
                    clearCodeFeedback()
                }
                isVerified = true
            }
            return
        }

        await MainActor.run {
            guard generation == resolveGeneration else { return }
            isResolving = true
        }

        let resolved = await AffiliateService.shared.resolveCode(normalized)

        await MainActor.run {
            guard generation == resolveGeneration else { return }
            isResolving = false

            if let resolved {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    resolvedDisplayName = resolved.displayName ?? normalized
                    resolvedKind = resolved.type
                    showsLifetimePass = false
                    clearCodeFeedback()
                }
                isVerified = true
            } else if ProcessAffiliateLifetimePass.matches(normalized) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showsLifetimePass = true
                    resolvedDisplayName = nil
                    resolvedKind = nil
                    clearCodeFeedback()
                }
                isVerified = true
            } else if canValidateCodeOnline {
                isVerified = false
                presentInvalidCodeFeedback()
            } else {
                withAnimation(.smooth(duration: 0.22)) {
                    resolvedDisplayName = nil
                    resolvedKind = nil
                    showsLifetimePass = false
                    clearCodeFeedback()
                }
                isVerified = false
            }
        }
    }

    private func handleContinueRejected() {
        guard !isVerified else { return }
        if isResolving { return }

        let normalized = normalizedDraft
        if ProcessReferralCode.isValid(normalized) {
            presentInvalidCodeFeedback()
        } else {
            presentIncompleteCodeFeedback()
        }
    }

    private func presentIncompleteCodeFeedback() {
        resolvedDisplayName = nil
        resolvedKind = nil
        showsLifetimePass = false

        let wasAlreadyIncomplete = showsIncompleteCodeFeedback
        withAnimation(.smooth(duration: 0.22)) {
            showsIncompleteCodeFeedback = true
            showsInvalidCodeFeedback = false
        }

        guard !wasAlreadyIncomplete else { return }
        HapticManager.shared.warning()
        triggerCodeShake()
    }

    private var canValidateCodeOnline: Bool {
        FirebaseBootstrap.isConfigured && ClaudeConfiguration.functionsBaseURL != nil
    }

    private func clearCodeFeedback() {
        showsInvalidCodeFeedback = false
        showsIncompleteCodeFeedback = false
    }

    private func presentInvalidCodeFeedback() {
        resolvedDisplayName = nil
        resolvedKind = nil
        showsLifetimePass = false

        let wasAlreadyInvalid = showsInvalidCodeFeedback
        withAnimation(.smooth(duration: 0.22)) {
            showsInvalidCodeFeedback = true
            showsIncompleteCodeFeedback = false
        }

        guard !wasAlreadyInvalid else { return }

        HapticManager.shared.notification(.error)
        triggerCodeShake()
    }

    private func triggerCodeShake() {
        guard !reduceMotion else { return }
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.34)) {
            codeShakePhase += 1
        }
    }
}
