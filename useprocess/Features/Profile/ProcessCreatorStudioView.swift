import SwiftUI

/// Réglages studio (visible seulement si mode créateur débloqué).
struct ProcessCreatorStudioView: View {
    @ObservedObject private var creator = ProcessCreatorModeStore.shared
    @Bindable private var scanStore = FaceScanHistoryStore.shared
    @Environment(\.appTheme) private var theme

    @State private var pendingImportSlot: ProcessCreatorStudioScanSlot?
    @State private var isImportingStudioMedia = false
    @State private var studioImportError: String?

    var body: some View {
        ProcessSettingsOpalScrollPage(
            title: AppCopy.t("Studio contenu", en: "Content Studio")
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Text(AppCopy.t("Import photo et vidéo illimité sur le scan. Sur l’écran résultats, un slider te laisse choisir un rendu de Mauvais → Réaliste → Excellent.", en: "Unlimited photo and video import for scans. On the results screen, a slider lets you choose a result from Poor → Realistic → Excellent."))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(AppCopy.t("Rendu par défaut", en: "Default Result"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(creator.qualityLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ProcessSettingsOpalTheme.sectionTitleTint)
                    }

                    Slider(value: $creator.resultQuality, in: 0...1)
                        .tint(ProcessSettingsOpalTheme.sectionTitleTint)

                    HStack {
                        Text(AppCopy.t("Mauvais", en: "Poor"))
                        Spacer()
                        Text(AppCopy.t("Réaliste", en: "Realistic"))
                        Spacer()
                        Text(AppCopy.t("Excellent", en: "Excellent"))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ProcessSettingsOpalTheme.cardFillDark)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(ProcessSettingsOpalTheme.cardBorderDark, lineWidth: 0.5)
                        }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(AppCopy.t("Page scan analyse", en: "Scan analysis page"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Picker(
                        AppCopy.t("Page scan analyse", en: "Scan analysis page"),
                        selection: $creator.scanResultsLayout
                    ) {
                        ForEach(ProcessCreatorScanResultsLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(creator.scanResultsLayout.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProcessSettingsOpalTheme.valueTint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ProcessSettingsOpalTheme.cardFillDark)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(ProcessSettingsOpalTheme.cardBorderDark, lineWidth: 0.5)
                        }
                }

                studioProgressDatesCard

                studioEvolutionVideosCard

                Text(AppCopy.t("Astuce : tu peux encore ajuster le slider pendant l’écran résultats, avant de taper Continuer.", en: "Tip: you can still adjust the slider on the results screen before tapping Continue."))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ProcessSettingsOpalTheme.valueTint.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, ProcessSettingsOpalTheme.horizontalPadding)
        }
        .sheet(item: $pendingImportSlot) { slot in
            FaceScanGalleryImportPicker(
                onImage: { image in
                    pendingImportSlot = nil
                    importStudioMedia(slot: slot, image: image)
                },
                onVideoURL: { url in
                    pendingImportSlot = nil
                    importStudioMedia(slot: slot, videoURL: url)
                },
                onCancel: {
                    pendingImportSlot = nil
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            AppCopy.t("Import impossible", en: "Import failed"),
            isPresented: Binding(
                get: { studioImportError != nil },
                set: { if !$0 { studioImportError = nil } }
            )
        ) {
            Button(AppCopy.t("OK", en: "OK"), role: .cancel) {
                studioImportError = nil
            }
        } message: {
            Text(studioImportError ?? "")
        }
        .overlay {
            if isImportingStudioMedia {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.15)
                }
                .allowsHitTesting(true)
            }
        }
    }

    private var studioProgressDatesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppCopy.t("Page Progrès", en: "Progress page"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            Text(AppCopy.t(
                "Décale le jour 1 et le « maintenant » affichés sur Série / Progrès (Jour X / Y).",
                en: "Shift day 1 and “now” on Streak / Progress (Day X / Y)."
            ))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            DatePicker(
                AppCopy.t("Date de début", en: "Start date"),
                selection: studioStartBinding,
                displayedComponents: .date
            )
            .tint(theme.onboardingAccent)

            DatePicker(
                AppCopy.t("Date de maintenant", en: "Now date"),
                selection: studioNowBinding,
                in: creator.studioPlanStartDate...,
                displayedComponents: .date
            )
            .tint(theme.onboardingAccent)

            Text(progressPreviewLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.onboardingAccent)

            Button {
                HapticManager.shared.impact(.light)
                creator.clearStudioNowDate()
            } label: {
                Text(AppCopy.t("Remettre maintenant à aujourd’hui", en: "Reset now to today"))
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.processPlain)
            .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .processGlassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var studioStartBinding: Binding<Date> {
        Binding(
            get: { creator.studioPlanStartDate },
            set: { creator.setStudioPlanStartDate($0) }
        )
    }

    private var studioNowBinding: Binding<Date> {
        Binding(
            get: { creator.effectiveNow },
            set: { creator.setStudioNowDate($0) }
        )
    }

    private var progressPreviewLabel: String {
        let snapshot = ProcessPlanProgressStore.shared.snapshot
        if snapshot.hasPlan, snapshot.totalProgramDays > 0 {
            return AppCopy.t(
                "Aperçu : Jour \(snapshot.elapsedProgramDays) / \(snapshot.totalProgramDays)",
                en: "Preview: Day \(snapshot.elapsedProgramDays) / \(snapshot.totalProgramDays)"
            )
        }
        return AppCopy.t("Aucun programme chargé.", en: "No program loaded.")
    }

    private var studioEvolutionVideosCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppCopy.t("Vidéos Début / Maintenant", en: "Start / Now videos"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            Text(AppCopy.t(
                "Remplace les vidéos de la paire d’évolution sur Progrès / Série.",
                en: "Replace the evolution pair videos on Progress / Streak."
            ))
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 12) {
                studioSlotColumn(slot: .start)
                studioSlotColumn(slot: .now)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.clear)
                .processGlassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func studioSlotColumn(slot: ProcessCreatorStudioScanSlot) -> some View {
        let scan = scanStore.result(id: slot.scanId)
        return VStack(spacing: 10) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    studioSlotPreview(scan: scan)
                }

            Text(slot.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            Button {
                HapticManager.shared.impact(.light)
                pendingImportSlot = slot
            } label: {
                Text(scan == nil
                     ? AppCopy.t("Choisir", en: "Choose")
                     : AppCopy.t("Changer", en: "Replace"))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.processPlain)
            .foregroundStyle(theme.onboardingAccent)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.onboardingAccent.opacity(0.12))
            }
            .disabled(isImportingStudioMedia)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func studioSlotPreview(scan: FaceScanResult?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Group {
            if let scan {
                FaceScanRecordingMediaView(
                    result: scan,
                    displayMode: .sidePanel,
                    isPlaybackActive: false
                )
            } else {
                ZStack {
                    theme.cardBackgroundStrong.opacity(0.55)
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(theme.cardStroke.opacity(0.55), lineWidth: 0.75)
        }
    }

    private func importStudioMedia(slot: ProcessCreatorStudioScanSlot, image: UIImage) {
        isImportingStudioMedia = true
        Task { @MainActor in
            defer { isImportingStudioMedia = false }
            do {
                let imported = try await FaceScanMediaImport.process(image: image)
                scanStore.installStudioIdentityScan(
                    slot: slot,
                    payload: imported.0,
                    markers: imported.1,
                    createdAt: createdAt(for: slot)
                )
                HapticManager.shared.notification(.success)
            } catch {
                studioImportError = error.localizedDescription
            }
        }
    }

    private func importStudioMedia(slot: ProcessCreatorStudioScanSlot, videoURL: URL) {
        isImportingStudioMedia = true
        Task { @MainActor in
            defer {
                isImportingStudioMedia = false
                try? FileManager.default.removeItem(at: videoURL)
            }
            do {
                let imported = try await FaceScanMediaImport.process(videoSourceURL: videoURL)
                scanStore.installStudioIdentityScan(
                    slot: slot,
                    payload: imported.0,
                    markers: imported.1,
                    createdAt: createdAt(for: slot)
                )
                HapticManager.shared.notification(.success)
            } catch {
                studioImportError = error.localizedDescription
            }
        }
    }

    private func createdAt(for slot: ProcessCreatorStudioScanSlot) -> Date {
        switch slot {
        case .start: return creator.studioPlanStartDate
        case .now: return creator.effectiveNow
        }
    }
}

/// Entrée hub Réglages — uniquement si débloqué.
