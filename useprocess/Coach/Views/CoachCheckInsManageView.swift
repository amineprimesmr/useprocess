import SwiftUI

struct CoachCheckInsManageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Bindable private var store = CoachCheckInStore.shared

    @State private var showsAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Check-ins actifs", isOn: $store.proactiveCheckInsEnabled)
                        .tint(.green)
                } footer: {
                    Text("Les rappels ouvrent le coach avec un prompt contextualisé.")
                }

                Section("Programmés") {
                    if store.checkIns.isEmpty {
                        Text("Aucun check-in.")
                            .foregroundStyle(theme.secondaryText)
                    } else {
                        ForEach(store.checkIns) { checkIn in
                            checkInRow(checkIn)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.delete(id: store.checkIns[index].id)
                            }
                        }
                    }
                }

                Section("Modèles") {
                    ForEach(CoachCheckInTemplate.allCases) { template in
                        Button {
                            store.add(from: template, hour: defaultHour(for: template), minute: 0)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.title)
                                    .foregroundStyle(theme.primaryText)
                                Text(template.defaultPrompt)
                                    .font(.caption)
                                    .foregroundStyle(theme.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Check-ins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func checkInRow(_ checkIn: CoachCheckIn) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(checkIn.title)
                    .font(.body.weight(.medium))
                Text(String(format: "%02d:%02d · %@", checkIn.hour, checkIn.minute, checkIn.prompt))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { checkIn.isEnabled },
                set: { store.toggle(id: checkIn.id, enabled: $0) }
            ))
            .labelsHidden()
            .tint(.green)
        }
    }

    private func defaultHour(for template: CoachCheckInTemplate) -> Int {
        switch template {
        case .morningOutlook: return 7
        case .journalReminder: return 12
        case .scanReminder: return 18
        case .streakGuard: return 20
        }
    }
}
