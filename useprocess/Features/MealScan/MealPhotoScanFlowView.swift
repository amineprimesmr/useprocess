import SwiftUI
import UIKit

/// Flux complet scan repas — caméra / pellicule → analyse IA → score debloat → version optimisée.
struct MealPhotoScanFlowView: View {
    var onDismiss: () -> Void
    var onValidated: ((MealSuggestionContent, MealTimeSlot) -> Void)? = nil

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var viewModel = MealPhotoScanViewModel()
    @State private var isCameraPanelRevealed = false
    @State private var panelDragOffset: CGFloat = 0
    @State private var isClosingCamera = false
    @State private var hasRequestedDismiss = false
    @State private var dismissSessionToken = UUID()
    @Bindable private var planStore = WelcomePlanStore.shared

    private var livePlan: FaceOriginPlan? { planStore.plan }

    var body: some View {
        ZStack {
            switch viewModel.phase {
            case .camera:
                cameraPhase
            case .analyzing, .optimizing:
                analyzingPhase
            case .result:
                resultPhase
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.configureSlot(plan: livePlan)
        }
    }

    // MARK: - Caméra

    private var cameraPhase: some View {
        GeometryReader { geo in
            let panelHeight = geo.size.height * MealPhotoScanCameraPresentation.panelHeightRatio

            ZStack(alignment: .bottom) {
                cameraScrim
                    .opacity(isCameraPanelRevealed ? 1 : 0)
                    .onTapGesture { dismissCamera() }

                cameraPanel(panelHeight: panelHeight)
                    .offset(y: isCameraPanelRevealed ? 0 : panelHeight)
            }
            .animation(MealPhotoScanCameraPresentation.spring, value: isCameraPanelRevealed)
            .animation(MealPhotoScanCameraPresentation.spring, value: panelDragOffset)
            .onAppear {
                dismissSessionToken = UUID()
                isClosingCamera = false
                hasRequestedDismiss = false
                isCameraPanelRevealed = false
                panelDragOffset = 0
                withAnimation(MealPhotoScanCameraPresentation.spring) {
                    isCameraPanelRevealed = true
                }
            }
        }
        .ignoresSafeArea()
    }

    private var cameraScrim: some View {
        Rectangle()
            .fill(Color.black.opacity(0.14))
            .ignoresSafeArea()
            .contentShape(Rectangle())
    }

    private func cameraPanel(panelHeight: CGFloat) -> some View {
        ZStack(alignment: .top) {
            MealPhotoScanSheet(
                panelHeight: panelHeight,
                onCapture: { image in
                    viewModel.handleCapturedImage(
                        image,
                        plan: livePlan,
                        profile: profileService.currentProfile
                    )
                },
                onCancel: dismissCamera
            )

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.red.opacity(0.82))
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }
        }
        .offset(y: panelDragOffset)
        .gesture(cameraPanelDrag(panelHeight: panelHeight))
    }

    private func cameraPanelDrag(panelHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                guard value.translation.height > 0 else {
                    panelDragOffset = 0
                    return
                }
                panelDragOffset = value.translation.height
            }
            .onEnded { value in
                let shouldDismiss =
                    value.translation.height > MealPhotoScanCameraPresentation.dismissDragThreshold
                    || value.predictedEndTranslation.height > panelHeight * 0.22
                if shouldDismiss {
                    dismissCamera()
                } else {
                    withAnimation(MealPhotoScanCameraPresentation.spring) {
                        panelDragOffset = 0
                    }
                }
            }
    }

    private func dismissCamera() {
        guard viewModel.phase == .camera, !isClosingCamera else { return }
        isClosingCamera = true
        let token = dismissSessionToken

        HapticManager.shared.impact(.light)
        withAnimation(MealPhotoScanCameraPresentation.spring) {
            isCameraPanelRevealed = false
            panelDragOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            guard token == dismissSessionToken else { return }
            requestDismiss()
        }
    }

    private func requestDismiss() {
        guard !hasRequestedDismiss else { return }
        hasRequestedDismiss = true
        onDismiss()
    }

    // MARK: - Analyse

    private var analyzingPhase: some View {
        ZStack {
            ProcessScreenBackground()

            VStack(spacing: 24) {
                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(theme.onboardingAccent.opacity(0.35), lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                }

                ProgressView()
                    .controlSize(.large)
                    .tint(theme.onboardingAccent)

                VStack(spacing: 8) {
                    Text(viewModel.phase == .optimizing ? "Optimisation debloat" : "Analyse IA")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)

                    Text(viewModel.analysisStatus)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ProcessScreenBackground())
        .ignoresSafeArea()
    }

    // MARK: - Résultat

    private var resultPhase: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let image = viewModel.capturedImage {
                        scannedPhotoHeader(image: image)
                    }

                    if viewModel.optimizedMeal != nil {
                        resultTabPicker
                    }

                    if let meal = viewModel.activeMeal,
                       let assessment = viewModel.activeAssessment {
                        scoreHero(assessment: assessment, meal: meal)
                        MealDebloatScoreBreakdownView(assessment: assessment)
                        mealDetailsCard(meal: meal, assessment: assessment)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(ProcessScreenBackground())
            .navigationTitle("Analyse repas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer", action: requestDismiss)
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                stickySaveButton
            }
        }
        .background(ProcessScreenBackground())
        .ignoresSafeArea()
    }

    private var stickySaveButton: some View {
        Group {
            if let meal = viewModel.activeMeal {
                VStack(spacing: 0) {
                    Divider().opacity(theme.isDark ? 0.25 : 0.5)

                    Button {
                        validateMeal(meal)
                    } label: {
                        Text("Enregistrer le repas")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(theme.isDark ? Color.black : Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Capsule(style: .continuous).fill(theme.onboardingAccent))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    private func scannedPhotoHeader(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if viewModel.needsOptimization, viewModel.selectedResultTab == .optimized {
                    Text("Version optimisée")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(red: 0.35, green: 0.78, blue: 0.52)))
                        .padding(12)
                }
            }
    }

    private var resultTabPicker: some View {
        HStack(spacing: 8) {
            ForEach(MealPhotoScanViewModel.ResultTab.allCases, id: \.self) { tab in
                Button {
                    viewModel.selectResultTab(tab)
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(.bold))
                        if tab == .scanned, let score = viewModel.scannedAssessment?.score {
                            Text("\(score)/100")
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                        }
                        if tab == .optimized, let score = viewModel.optimizedAssessment?.score {
                            Text("\(score)/100")
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(
                        viewModel.selectedResultTab == tab ? theme.primaryText : theme.secondaryText
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                viewModel.selectedResultTab == tab
                                    ? theme.onboardingAccent.opacity(0.14)
                                    : theme.cardBackgroundStrong
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(tab == .optimized && viewModel.optimizedMeal == nil)
            }
        }
    }

    private func scoreHero(assessment: MealDebloatAssessment, meal: MealSuggestionContent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(viewModel.selectedResultTab == .optimized ? "Version optimisée debloat" : "Détecté sur ta photo")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.onboardingAccent)
                .textCase(.uppercase)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(meal.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.primaryText)

                    Text(meal.scoreSummary.isEmpty ? assessment.summary : meal.scoreSummary)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                MealDebloatScoreGlassPill(assessment: assessment)
            }

            if !assessment.balance.isDebloatOptimized,
               viewModel.selectedResultTab == .scanned,
               viewModel.optimizedMeal != nil {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(theme.onboardingAccent)
                    Text("Une version optimisée debloat a été générée automatiquement.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.onboardingAccent.opacity(0.10))
                )
            }
        }
        .padding(16)
        .background(resultCardBackground)
    }

    private func mealDetailsCard(meal: MealSuggestionContent, assessment: MealDebloatAssessment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Composition visible")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.primaryText)

            ForEach(meal.foodItems) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.roleIcon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.onboardingAccent)
                        .frame(width: 22)
                    Text(item.ingredientDisplayLine)
                        .font(.subheadline)
                        .foregroundStyle(theme.primaryText)
                    Spacer(minLength: 0)
                }
            }

            if !meal.coachTip.isEmpty {
                Divider().opacity(0.35)
                Label(meal.coachTip, systemImage: "lightbulb.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let caution = assessment.caution, !caution.isEmpty,
               viewModel.selectedResultTab == .scanned {
                Label(caution, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.96, green: 0.47, blue: 0.30))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(resultCardBackground)
    }

    private var resultCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(theme.isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(theme.cardStroke.opacity(0.35), lineWidth: 0.5)
            }
    }

    private func validateMeal(_ meal: MealSuggestionContent) {
        guard let plan = livePlan,
              let day = OriginPlanPresenter.programDay(in: plan)
                ?? OriginPlanPresenter.todayDay(in: plan),
              viewModel.validateActiveMeal(plan: plan, day: day) != nil else { return }

        HapticManager.shared.notification(.success)
        onValidated?(meal, viewModel.selectedSlot)
        requestDismiss()
    }
}

// MARK: - Présentation caméra scan repas

enum MealPhotoScanCameraPresentation {
    /// Panneau caméra — plus compact qu’avant (68 %).
    static let panelHeightRatio: CGFloat = 0.58
    static let spring = Animation.spring(response: 0.30, dampingFraction: 0.90)
    static let dismissDragThreshold: CGFloat = 64
}
