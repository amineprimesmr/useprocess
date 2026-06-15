//
//  ProgramCreationStepView.swift
//  Process
//
//  Page de création du programme avec animations
//

import SwiftUI

struct ProgramCreationStepView: View {

    let onComplete: () -> Void
    let onBack: (() -> Void)?
    let onValidationChanged: ((Bool) -> Void)?

    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var allAnimationsComplete = false

    @State private var overallProgress: Double = 0.0
    @State private var displayedPercentage: Int = 0
    @State private var showCreationText = false
    @State private var showObjectives = false
    @State private var currentObjectiveIndex = 0
    @State private var objectiveProgresses: [Double] = [0.0, 0.0, 0.0]
    @State private var showPopup = false
    @State private var popupQuestion = ""
    @State private var popupObjectiveIndex = -1
    @State private var selectedAnswer: Bool?
    @State private var isAnimationPaused = false
    @State private var popupOffset: CGFloat = 200

    @State private var currentImageIndex: Int = 0
    @State private var imageTimer: Timer?

    private let scienceImages = ["scienceapprouve", "scienceapprouve2", "scienceapprouve3"]

    private let objectives = ["Analyse des habitudes", "Generation du plan de 13 semaines", "Objectifs personnalisés quotidien"]

    private let questions = [
        "Es-tu prêt à terminer ce que tu commences?",
        "Sais-tu ce qui impact réellement ta récupération ?",
        "As-tu déjà téléchargé une application de tracking personnalisé ?"
    ]

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil, onValidationChanged: ((Bool) -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
        self.onValidationChanged = onValidationChanged
    }

    var body: some View {
        ZStack {
            OnboardingTheme.screenBackground
                .ignoresSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: OnboardingConstants.scrollContentTopInset)

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(displayedPercentage)")
                            .font(.system(size: 72, weight: .bold, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        OnboardingTheme.primaryText,
                                        OnboardingTheme.primaryText.opacity(0.95),
                                        Color.gray.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: OnboardingTheme.titleShadow, radius: 2, x: 1, y: 1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: displayedPercentage)

                        Text("%")
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        OnboardingTheme.primaryText,
                                        OnboardingTheme.primaryText.opacity(0.95),
                                        Color.gray.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: OnboardingTheme.titleShadow, radius: 2, x: 1, y: 1)
                    }
                    .padding(.bottom, 40)

                    if showCreationText {
                        creationSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.bottom, 5)
                    }

                    if showCreationText {
                        testimonialSection
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            .padding(.top, 5)
                            .padding(.bottom, 20)
                    }

                    if showObjectives {
                        objectivesSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.top, 10)
                            .padding(.bottom, 40)
                    }

                    Spacer()
                        .frame(height: 100)
                }
            }

            if showPopup {
                popupView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .onAppear {
                        popupOffset = 100
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.1)) {
                            popupOffset = 0
                        }
                    }
            }
        }
        .onAppear {
            onValidationChanged?(false)
            startAnimations()
            startImageCarousel()
        }
        .onDisappear {
            imageTimer?.invalidate()
            imageTimer = nil
        }
    }

    private var testimonialSection: some View {
        Group {
            Image(scienceImages[currentImageIndex])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: LayoutConstants.isIPad ? 300 : 200)
                .id(currentImageIndex)
        }
        .frame(height: LayoutConstants.isIPad ? 300 : 200)
        .adaptiveHorizontalPadding()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.5), value: currentImageIndex)
    }

    private var creationSection: some View {
        VStack(spacing: 20) {
            Text("Creation du programme")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(OnboardingTheme.narrativeText)
                .padding(.horizontal, 40)
        }
    }

    private var objectivesSection: some View {
        VStack(alignment: .leading, spacing: 30) {
            ForEach(0..<objectives.count, id: \.self) { index in
                if index <= currentObjectiveIndex {
                    objectiveRow(index: index)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func objectiveRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(objectives[index])
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OnboardingTheme.bodyText)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(OnboardingTheme.mutedFill)
                        .frame(height: 10)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.7, green: 0.55, blue: 0.85),
                                    Color(red: 0.5, green: 0.3, blue: 0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * objectiveProgresses[index], height: 10)
                        .animation(.easeInOut(duration: 0.2), value: objectiveProgresses[index])
                }
            }
            .frame(height: 10)
        }
    }

    private var popupView: some View {
        VStack {
            Spacer()
            Spacer()

            Button(action: {}) {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("Pour pouvoir continuer, précise")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(OnboardingTheme.bodyText)

                        Text(popupQuestion)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.narrativeText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    HStack(spacing: 16) {
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            selectedAnswer = false
                            handlePopupAnswer(false)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Non")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                        }
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.98),
                                    Color(red: 0.92, green: 0.95, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)

                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            selectedAnswer = true
                            handlePopupAnswer(true)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Oui")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                        }
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.98),
                                    Color(red: 0.92, green: 0.95, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 30))
            .controlSize(.large)
            .padding(.horizontal, 20)
            .offset(y: popupOffset)
            .scaleEffect(popupOffset == 0 ? 1.0 : 0.9)
            .opacity(popupOffset == 0 ? 1.0 : 0.0)
        }
        .padding(.bottom, 40)
    }

    private func startImageCarousel() {
        imageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentImageIndex = (currentImageIndex + 1) % scienceImages.count
            }
        }
    }

    private func startAnimations() {
        Task {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showCreationText = true
                showObjectives = true
            }

            let objectivesTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000)

                for index in 0..<objectives.count {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        currentObjectiveIndex = index
                    }

                    await animateObjectiveProgress(index: index)
                }
            }

            await objectivesTask.value

            allAnimationsComplete = true
            onValidationChanged?(true)

            if ClaudeConfiguration.isConfigured,
               let summary = await CoachEngine.generateProgramSummary(profile: profileService.currentProfile) {
                let programMessage = CoachMessage(
                    role: .assistant,
                    text: "## Ton plan \(AppBranding.name)\n\n\(summary)",
                    modelUsed: ClaudeModel.preferred(for: .programSummary).rawValue
                )
                CoachConversationStore.appendMessage(programMessage)
            }
        }
    }

    private func animateObjectiveProgress(index: Int) async {
        var currentProgress: Double = 0.0
        while currentProgress < 0.5 {
            while isAnimationPaused {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            try? await Task.sleep(nanoseconds: 40_000_000)
            currentProgress += 0.005
            withAnimation(.easeInOut(duration: 0.2)) {
                objectiveProgresses[index] = min(currentProgress, 0.5)
                let percentagePerObjective = 100.0 / Double(objectives.count)
                let basePercentage = Double(index) * percentagePerObjective
                let progressPercentage = currentProgress * percentagePerObjective
                let totalPercentage = Int(basePercentage + progressPercentage)
                displayedPercentage = min(totalPercentage, 100)
            }
        }

        isAnimationPaused = true

        popupQuestion = questions[index]
        popupObjectiveIndex = index
        popupOffset = 200
        showPopup = true

        while isAnimationPaused {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        while currentProgress < 1.0 {
            while isAnimationPaused {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            try? await Task.sleep(nanoseconds: 40_000_000)
            currentProgress += 0.005
            withAnimation(.easeInOut(duration: 0.2)) {
                objectiveProgresses[index] = min(currentProgress, 1.0)
                let percentagePerObjective = 100.0 / Double(objectives.count)
                let basePercentage = Double(index) * percentagePerObjective
                let progressPercentage = currentProgress * percentagePerObjective
                let totalPercentage = Int(basePercentage + progressPercentage)
                if index == objectives.count - 1 && currentProgress >= 1.0 {
                    displayedPercentage = 100
                } else {
                    displayedPercentage = min(totalPercentage, 100)
                }
            }
        }
    }

    private func handlePopupAnswer(_ answer: Bool) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            popupOffset = 200
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showPopup = false
            popupOffset = 200
        }

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            isAnimationPaused = false

            withAnimation(.easeInOut(duration: 1.0)) {
                objectiveProgresses[popupObjectiveIndex] = 1.0
                let percentagePerObjective = 100.0 / Double(objectives.count)
                let basePercentage = Double(popupObjectiveIndex) * percentagePerObjective
                let totalPercentage = Int(basePercentage + percentagePerObjective)
                if popupObjectiveIndex == objectives.count - 1 {
                    displayedPercentage = 100
                } else {
                    displayedPercentage = min(totalPercentage, 100)
                }
            }
        }
    }
}
