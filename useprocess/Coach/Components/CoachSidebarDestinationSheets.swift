import SwiftUI

enum CoachSidebarDestination: String, CaseIterable, Identifiable {
    case integration
    case healthRecords
    case files
    case tracking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .integration: return AppCopy.t("Configuration", en: "Setup")
        case .healthRecords: return AppCopy.t("Dossiers de santé", en: "Health records")
        case .files: return AppCopy.t("Fichiers", en: "Files")
        case .tracking: return AppCopy.t("Points de suivi", en: "Progress tracking")
        }
    }

    var icon: String {
        switch self {
        case .integration: return "circle.dashed"
        case .healthRecords: return "list.clipboard.fill"
        case .files: return "folder.fill"
        case .tracking: return "clock.badge.checkmark.fill"
        }
    }
}

// MARK: - Health records

struct CoachHealthRecordsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            HealthConnectedSourcesSettingsView()
                .processTransparentScrollSurface()
                .navigationTitle(AppCopy.t("Dossiers de santé", en: "Health records"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        closeButton
                    }
                }
        }
        .processAppPageBackground()
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.cardBackgroundStrong.opacity(0.95)))
        }
    }
}

// MARK: - Files

struct CoachFilesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var profileService: UnifiedProfileService

    @State private var faceHistoryStore = FaceScanHistoryStore.shared
    @Bindable private var processFilesStore = CoachProcessFilesStore.shared
    @State private var editingFile: CoachProcessFile?
    @State private var showsNewFileEditor = false

    var body: some View {
        NavigationStack {
            List {
                Section(AppCopy.t("Fichiers Process", en: "Process files")) {
                    if processFilesStore.files.isEmpty {
                        Text(AppCopy.t("Le coach crée des fichiers au fil des échanges (objectifs, synthèses, contraintes).", en: "The coach creates files as you chat (goals, summaries, constraints)."))
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        ForEach(processFilesStore.files) { file in
                            Button {
                                editingFile = file
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(theme.primaryText)
                                    Text(file.content)
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                        .lineLimit(4)
                                    Text(file.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(theme.secondaryText.opacity(0.8))
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.processPlain)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                processFilesStore.delete(id: processFilesStore.files[index].id)
                            }
                        }
                    }
                }

                Section(AppCopy.t("Scans visage", en: "Face scans")) {
                    if faceHistoryStore.history.isEmpty {
                        Text(AppCopy.t("Aucun scan enregistré.", en: "No scans saved."))
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        ForEach(faceHistoryStore.history) { scan in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppCopy.t("Scan du \(scan.createdAt.formatted(date: .abbreviated, time: .omitted))", en: "Scan from \(scan.createdAt.formatted(date: .abbreviated, time: .omitted))"))
                                        .font(.body.weight(.medium))
                                    Text(AppCopy.t("Score \(scan.displayWellnessScore)/100", en: "Score \(scan.displayWellnessScore)/100"))
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                Section(AppCopy.t("Conversations", en: "Conversations")) {
                    Text(AppCopy.t("Les photos partagées dans le coach restent liées à leurs conversations.", en: "Photos shared with the coach remain linked to their conversations."))
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .navigationTitle(AppCopy.t("Fichiers", en: "Files"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsNewFileEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingFile) { file in
                CoachProcessFileEditorSheet(file: file) { title, content in
                    processFilesStore.update(id: file.id, title: title, content: content)
                }
            }
            .sheet(isPresented: $showsNewFileEditor) {
                CoachProcessFileEditorSheet(file: nil) { title, content in
                    processFilesStore.upsert(title: title, content: content)
                }
            }
            .onAppear {
                faceHistoryStore.reloadForUser(userId: profileService.currentProfile?.userId)
                processFilesStore.reload()
            }
        }
        .processAppPageBackground()
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.cardBackgroundStrong.opacity(0.95)))
        }
    }
}

// MARK: - Tracking

struct CoachTrackingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @Bindable private var streakStore = ProcessStreakStore.shared
    @Bindable private var planStore = WelcomePlanStore.shared
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private var snapshot: ProcessStreakSnapshot { streakStore.snapshot }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    streakSummaryCard

                    if let plan = planStore.plan {
                        journalPreview(plan: plan)
                    } else {
                        Text(AppCopy.t("Termine l'intégration pour activer le suivi quotidien.", en: "Finish setup to activate daily tracking."))
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
            .processTransparentScrollSurface()
            .navigationTitle(AppCopy.t("Points de suivi", en: "Progress tracking"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    closeButton
                }
            }
            .onAppear {
                streakStore.sync(from: planStore.plan)
            }
        }
        .processAppPageBackground()
    }

    private var streakSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppCopy.t("Jours validés", en: "Completed days"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snapshot.totalCompletedDays)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                Text(AppCopy.t("jours", en: "days"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            Text(snapshot.totalCompletedDays <= 1
                 ? AppCopy.t("Journée cumulée", en: "Total day")
                 : AppCopy.t("Total cumulé", en: "Total days"))
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.cardBackgroundStrong.opacity(theme.isDark ? 0.92 : 0.98))
        )
    }

    private func journalPreview(plan: FaceOriginPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppCopy.t("Journal du jour", en: "Today's journal"))
                .font(.headline.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            DailyJournalChecklistView(
                plan: plan,
                selectedDate: $selectedDate,
                showHeader: false,
                showWeekStrip: false
            )
            .environmentObject(HealthManager.shared)
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .frame(width: 34, height: 34)
                .background(Circle().fill(theme.cardBackgroundStrong.opacity(0.95)))
        }
    }
}
