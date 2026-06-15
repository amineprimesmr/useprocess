import SwiftUI

struct CoachDailyBriefCard: View {
    let content: CoachDailyBriefContent
    var theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(content.verdict)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !content.why.isEmpty {
                Text(content.why)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !content.actions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("À faire")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .textCase(.uppercase)

                    ForEach(Array(content.actions.enumerated()), id: \.offset) { index, action in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.primaryText)
                                .frame(width: 20, height: 20)
                                .background(theme.cardStroke.opacity(theme.isDark ? 0.35 : 0.6))
                                .clipShape(Circle())

                            Text(action)
                                .font(.subheadline)
                                .foregroundStyle(theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .textSelection(.enabled)
    }
}
