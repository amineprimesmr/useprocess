import SwiftUI

struct CoachConnectorsSheet: View {
    var onSelect: (CoachTool) -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(CoachTool.allCases.enumerated()), id: \.element.id) { index, tool in
                        if index > 0 {
                            Divider().padding(.leading, 64)
                        }

                        Button {
                            HapticManager.shared.impact(.light)
                            onSelect(tool)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.07))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: tool.icon)
                                        .font(.system(size: 17, weight: .medium))
                                }

                                Text(tool.label)
                                    .font(.system(size: 17, weight: .semibold))

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Connecteurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", action: onCancel)
                }
            }
        }
        .processAppPageBackground()
        .processAppPresentationBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
