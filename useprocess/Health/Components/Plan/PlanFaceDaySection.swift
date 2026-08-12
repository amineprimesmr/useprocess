import SwiftUI

/// Circuit lymphatique — carousel + session live (caméra / tracking / démo).
struct PlanFaceDaySection: View {
    let plan: FaceOriginPlan
    let day: OriginProgramDay

    @Bindable private var planStore = WelcomePlanStore.shared
    @Bindable private var tutorialStore = PlanHomeTutorialStore.shared
    @Environment(\.appTheme) private var theme
    @Namespace private var protocolZoomNamespace
    @State private var selectedProtocolItem: PlanProtocolCarouselItem?
    @State private var sessionLaunch: LymphCircuitSessionLaunch?
    @State private var pendingSessionLaunch: LymphCircuitSessionLaunch?

    private var livePlan: FaceOriginPlan {
        planStore.plan ?? plan
    }

    private var targets: OriginPersonalizedDailyTargets {
        livePlan.personalizedTargets ?? .default
    }

    private var carouselItems: [PlanProtocolCarouselItem] {
        FaceMorningRoutineCatalog.carouselItems(targets: targets)
    }

    private var isEditableToday: Bool {
        OriginPlanPresenter.isEditableJournalDay(dayId: day.id, in: livePlan)
    }

    var body: some View {
        let items = carouselItems

        VStack(alignment: .leading, spacing: PlanHomeSectionDesign.headerContentSpacing) {
            headerRow

            if items.isEmpty {
                Text(AppCopy.t(
                    "Aucune action quotidienne planifiée.",
                    en: "No daily actions planned."
                ))
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            } else {
                protocolCarouselBody(items: items)
            }
        }
        .animation(.spring(response: 0.52, dampingFraction: 0.88), value: tutorialStore.currentStepIndex)
        .fullScreenCover(item: $selectedProtocolItem, onDismiss: {
            if let pending = pendingSessionLaunch {
                pendingSessionLaunch = nil
                sessionLaunch = pending
            }
        }) { item in
            if let step = FaceMorningRoutineCatalog.Step.from(carouselId: item.id) {
                LymphCircuitExerciseDetailView(
                    step: step,
                    sessionActionTitle: isEditableToday
                        ? AppCopy.t("Lancer cet exercice", en: "Start this exercise")
                        : nil,
                    onOpenSession: isEditableToday
                        ? {
                            pendingSessionLaunch = LymphCircuitSessionLaunch(startAt: step)
                            selectedProtocolItem = nil
                        }
                        : nil
                )
            } else {
                PlanProtocolItemDetailSheet(
                    item: item,
                    sessionActionTitle: isEditableToday
                        ? AppCopy.t("Lancer cet exercice", en: "Start this exercise")
                        : nil,
                    onOpenSession: isEditableToday
                        ? {
                            let mapped = FaceMorningRoutineCatalog.Step.from(carouselId: item.id)
                            pendingSessionLaunch = LymphCircuitSessionLaunch(startAt: mapped)
                            selectedProtocolItem = nil
                        }
                        : nil
                )
                .processZoomTransition(id: .protocolItem(item.id), namespace: protocolZoomNamespace)
            }
        }
        .fullScreenCover(item: $sessionLaunch) { launch in
            LymphCircuitSessionView(dayId: day.id, startAt: launch.startAt)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(PlanHomeSectionKind.faceRoutine.title)
                .font(.system(size: PlanHomeSectionDesign.titleSize, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            if isEditableToday {
                playButton
            }
        }
    }

    private var playButton: some View {
        Button {
            sessionLaunch = LymphCircuitSessionLaunch(startAt: nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                Text(AppCopy.t("Lancer", en: "Start"))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(HealthHubDesign.softCard(theme: theme))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppCopy.t("Lancer le circuit lymphatique", en: "Start lymphatic circuit"))
    }

    @ViewBuilder
    private func protocolCarouselBody(items: [PlanProtocolCarouselItem]) -> some View {
        if tutorialStore.isFocused(.faceRoutine) {
            PlanHomeTutorialFocusChrome(
                focus: .faceRoutine,
                cornerRadius: PlanProtocolCarouselLayout.cornerRadius
            ) {
                faceRoutineCarousel(items: items, highlightsItemStrip: false)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        } else {
            faceRoutineCarousel(items: items, highlightsItemStrip: false)
                .opacity(tutorialStore.isRevealed(.faceRoutine) ? 0.88 : 1)
        }
    }

    private func faceRoutineCarousel(
        items: [PlanProtocolCarouselItem],
        highlightsItemStrip: Bool
    ) -> some View {
        PlanDayProtocolCarousel(
            items: items,
            zoomNamespace: protocolZoomNamespace,
            zoomIDForItem: { .protocolItem($0.id) },
            onTap: { selectedProtocolItem = $0 },
            routineDayId: isEditableToday ? day.id : nil,
            isRoutineItemCompleted: { item in
                planStore.isDailyRoutineItemCompleted(
                    carouselItemId: item.id,
                    dayId: day.id
                )
            },
            onRoutineValidate: { item in
                planStore.completeDailyRoutineItem(
                    carouselItemId: item.id,
                    dayId: day.id
                )
            },
            highlightsItemStrip: highlightsItemStrip
        )
    }
}

/// Identifiant de présentation pour la session live.
private struct LymphCircuitSessionLaunch: Identifiable {
    let id = UUID()
    let startAt: FaceMorningRoutineCatalog.Step?
}
