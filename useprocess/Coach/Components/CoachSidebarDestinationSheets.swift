import SwiftUI

enum CoachSidebarDestination: String, CaseIterable, Identifiable {
    case integration
    case healthRecords
    case files
    case tracking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .integration: return "Intégration"
        case .healthRecords: return "Dossiers de santé"
        case .files: return "Fichiers"
        case .tracking: return "Points de suivi"
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
                .navigationTitle("Dossiers de santé")
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
                Section("Fichiers Process") {
                    if processFilesStore.files.isEmpty {
                        Text("Le coach crée des fichiers au fil des échanges (objectifs, synthèses, contraintes).")
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
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                processFilesStore.delete(id: processFilesStore.files[index].id)
                            }
                        }
                    }
                }

                Section("Scans visage") {
                    if faceHistoryStore.history.isEmpty {
                        Text("Aucun scan enregistré.")
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        ForEach(faceHistoryStore.history) { scan in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Scan du \(scan.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.body.weight(.medium))
                                    Text("Score \(scan.displayWellnessScore)/100")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                }
                                Spacer()
                            }
                        }
                    }
                }

                Section("Conversations") {
                    Text("Les photos partagées dans le coach restent liées à leurs conversations.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .navigationTitle("Fichiers")
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
                        Text("Termine l'intégration pour activer le suivi quotidien.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
            .processTransparentScrollSurface()
            .navigationTitle("Points de suivi")
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
            Text("Streak actuel")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snapshot.currentStreak)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
                Text("jours")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }

            Text("Record : \(snapshot.longestStreak) jours")
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
            Text("Journal du jour")
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
