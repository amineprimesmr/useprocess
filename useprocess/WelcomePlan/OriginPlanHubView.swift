import SwiftUI

struct OriginPlanHubView: View {
    let plan: FaceOriginPlan

    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var store = WelcomePlanStore.shared
    @State private var section: OriginPlanProgramSection = .today

    private var livePlan: FaceOriginPlan { store.plan ?? plan }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(OriginPlanProgramSection.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        OriginPlanHeaderCard(plan: livePlan)
                        OriginPlanProgramContent(section: $section, plan: plan, closesOnCoachAsk: true)
                    }
                    .padding()
                    .padding(.bottom, 24)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Protocole Origine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { openCoachOverview() } label: {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                    }
                    .accessibilityLabel("Parler au coach")
                }
            }
            .onAppear { store.reloadForCurrentUser() }
        }
    }

    private func openCoachOverview() {
        CoachPlanNavigationBridge.shared.askCoachAboutPlan(
            focus: CoachPlanFocus(
                sectionPath: "overview",
                sectionTitle: "Protocole Origine",
                sectionContent: OriginPlanPresenter.oneLineSummary(livePlan),
                mode: .ask
            )
        )
        dismiss()
    }
}
