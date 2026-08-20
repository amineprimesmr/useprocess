import SwiftUI

struct OnboardingCreatorCodeStepView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var draftCode: String
    @Binding var isVerified: Bool
    var onAutoContinue: () -> Void = {}

    @State private var resolvedDisplayName: String?
    @State private var resolvedKind: ProcessAffiliateCodeKind?
    @State private var showsInvalidCodeFeedback = false
    @State private var showsIncompleteCodeFeedback = false
    @State private var codeShakePhase: CGFloat = 0
    @State private var isResolving = false
    @State private var resolveGeneration = 0
    @State private var showsHero = false
    @State private var showsInput = false
    @State private var showsResolvedHint = false
    @FocusState private var isFocused: Bool

    private let accentBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
    private let accentBlueSoft = Color(red: 0.22, green: 0.58, blue: 1.0)
    private let maxCodeLength = ProcessReferralCode.length

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: contentTopInset)

                VStack(spacing: 12) {
                    Text(AppCopy.t("As-tu un code ?", en: "Got a code?"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(
                        AppCopy.t(
                            "Facultatif — code à 5 caractères (créateur ou ami).",
                            en: "Optional — 5-character code (creator or friend)."
                        )
                    )
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(OnboardingTheme.mutedText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                }
                .opacity(showsHero ? 1 : 0)

                Spacer()
                    .frame(height: 40)

                OnboardingCreatorCodeCircleInput(
                    code: $draftCode,
                    maxLength: maxCodeLength,
                    accentBlue: accentBlue,
                    isInvalid: showsInvalidCodeFeedback || showsIncompleteCodeFeedback,
                    isFocused: $isFocused,
                    onSubmit: handleKeyboardSubmit
                )
                .modifier(OnboardingHorizontalShakeEffect(shakes: codeShakePhase))
                .opacity(showsInput ? 1 : 0)
                .frame(height: 52)

                if let resolvedDisplayName, let resolvedKind, showsResolvedHint {
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

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, bottomChromeReserve)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack(alignment: .top) {
                OnboardingTheme.screenBackground
                    .ignoresSafeArea()

                creatorCodeHeroGradient
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            runEntrance()
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingTransitionTiming.earlyKeyboardFocusDelay) {
                isFocused = true
            }
            resolveGeneration += 1
            let generation = resolveGeneration
            Task { await resolveDraftIfNeeded(generation: generation) }
        }
        .onChange(of: draftCode) { _, _ in
            if showsInvalidCodeFeedback || showsIncompleteCodeFeedback {
                withAnimation(.smooth(duration: 0.18)) {
                    clearCodeFeedback()
                }
            }
            if isVerified {
                isVerified = false
            }
            resolveGeneration += 1
            let generation = resolveGeneration
            Task { await resolveDraftIfNeeded(generation: generation) }
        }
    }

    private var contentTopInset: CGFloat {
        OnboardingConstants.headerBackButtonTopPadding
            + OnboardingConstants.backButtonSize
            + 28
    }

    private var bottomChromeReserve: CGFloat {
        OnboardingConstants.standardContinueBottomOffset + 58 + 16
    }

    private var creatorCodeHeroGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    accentBlue.opacity(0.16),
                    accentBlueSoft.opacity(0.07),
                    Color.clear
                ]
                : [
                    accentBlue.opacity(0.10),
                    accentBlueSoft.opacity(0.04),
                    Color.clear
                ],
            startPoint: .top,
            endPoint: .bottom
        )
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

    private func handleKeyboardSubmit() {
        if isVerified {
            HapticManager.shared.impact(.medium)
            isFocused = false
            onAutoContinue()
            return
        }
        handleContinueRejected()
    }

    private func runEntrance() {
        if reduceMotion {
            showsHero = true
            showsInput = true
            showsResolvedHint = true
            return
        }

        withAnimation(.smooth(duration: 0.22)) {
            showsHero = true
            showsInput = true
            showsResolvedHint = true
        }
    }

    private var normalizedDraft: String {
        ProcessReferralCode.normalize(draftCode)
    }

    private func resolvedLabel(kind: ProcessAffiliateCodeKind, name: String) -> String {
        switch kind {
        case .affiliate:
            return AppCopy.t("Créateur : \(name)", en: "Creator: \(name)")
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
                    clearCodeFeedback()
                }
                isVerified = false
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
                    clearCodeFeedback()
                }
                isVerified = true
                scheduleAutoContinue(generation: generation)
            } else if canValidateCodeOnline {
                isVerified = false
                presentInvalidCodeFeedback()
            } else {
                withAnimation(.smooth(duration: 0.22)) {
                    resolvedDisplayName = nil
                    resolvedKind = nil
                    clearCodeFeedback()
                }
                isVerified = false
            }
        }
    }

    private func scheduleAutoContinue(generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            guard generation == resolveGeneration, isVerified else { return }
            HapticManager.shared.impact(.medium)
            isFocused = false
            onAutoContinue()
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

// MARK: - Saisie en ronds

private struct OnboardingCreatorCodeCircleInput: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var code: String
    var maxLength: Int
    var accentBlue: Color
    var isInvalid: Bool
    @FocusState.Binding var isFocused: Bool
    var onSubmit: () -> Void = {}

    private var slotCount: Int {
        ProcessReferralCode.length
    }

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .focused($isFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.continue)
                .onSubmit(onSubmit)
                .opacity(0.015)
                .frame(width: 1, height: 1)
                .accessibilityLabel(AppCopy.t("Code créateur", en: "Creator code"))

            HStack(spacing: circleSpacing) {
                ForEach(0..<slotCount, id: \.self) { index in
                    codeCircle(at: index)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onChange(of: code) { _, newValue in
            let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
            code = String(filtered.prefix(maxLength))
        }
    }

    private var circleSpacing: CGFloat {
        14
    }

    private var circleSize: CGFloat {
        52
    }

    private func codeCircle(at index: Int) -> some View {
        let character = character(at: index)
        let isActive = isFocused && index == code.count && !isInvalid
        let strokeColor = resolvedStrokeColor(isActive: isActive)

        return ZStack {
            Color.clear
                .frame(width: circleSize, height: circleSize)
                .processGlassEffect(in: Circle(), interactive: false)
                .overlay {
                    Circle()
                        .strokeBorder(strokeColor, lineWidth: isActive || isInvalid ? 2 : 1)
                }
                .shadow(
                    color: isActive ? accentBlue.opacity(colorScheme == .dark ? 0.28 : 0.18) : .clear,
                    radius: isActive ? 8 : 0,
                    y: isActive ? 2 : 0
                )

            if let character {
                Text(String(character))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isInvalid ? Color.red.opacity(0.88) : OnboardingTheme.primaryText)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: code)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isFocused)
        .animation(.smooth(duration: 0.22), value: isInvalid)
    }

    private func resolvedStrokeColor(isActive: Bool) -> Color {
        if isInvalid {
            return Color.red.opacity(colorScheme == .dark ? 0.82 : 0.72)
        }
        if isActive {
            return accentBlue.opacity(0.85)
        }
        return idleCircleStrokeColor
    }

    private var idleCircleStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : accentBlue.opacity(0.20)
    }

    private func character(at index: Int) -> Character? {
        guard index < code.count else { return nil }
        let stringIndex = code.index(code.startIndex, offsetBy: index)
        return code[stringIndex]
    }
}
