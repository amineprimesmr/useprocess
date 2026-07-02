import SwiftUI
import UIKit

enum ProfileAnalyticsRange: String, CaseIterable, Identifiable {
    case week = "Semaine"
    case month = "Mois"
    case all = "Tout"

    var id: String { rawValue }
}

struct ProfileAnalyticsPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let value: Double
}

struct ProfileScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ProfileScrollOffsetReader: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ProfileScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named("profileScroll")).minY
            )
        }
        .frame(height: 0)
    }
}

enum ProfilePerformancePalette {
    static let background = Color.black
    static let muted = Color.white.opacity(0.5)
    static let subtle = Color.white.opacity(0.09)
    static let orange = Color(red: 1.0, green: 0.48, blue: 0.27)
    static let peach = Color(red: 1.0, green: 0.66, blue: 0.52)
    static let blue = Color(red: 0.33, green: 0.72, blue: 1.0)
    static let yellow = Color(red: 1.0, green: 0.88, blue: 0.24)

    static let warmCoolGradient = LinearGradient(
        colors: [orange, peach, Color(red: 0.68, green: 0.78, blue: 0.96), blue],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct ProfilePerformanceBackground: View {
    var body: some View {
        ZStack {
            ProfilePerformancePalette.background

            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.29).opacity(0.9),
                    Color(red: 0.08, green: 0.09, blue: 0.11).opacity(0.48),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: -0.02),
                startRadius: 10,
                endRadius: 390
            )
        }
        .ignoresSafeArea()
    }
}

struct ProfilePerformanceHero: View {
    let profile: SocialProfile
    let totalDays: Int
    let streak: Int
    let healthScore: Int

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: ProcessMainChromeMetrics.topSafeInset + 60)

            VStack(spacing: 13) {
                Color.clear
                    .frame(width: 176, height: 176)

                Text(profile.displayName)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                let tag = ProcessUsernameTag.display(profile.username)
                if !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }
            }
            .padding(.top, 42)

            HStack(alignment: .top, spacing: 8) {
                ProfilePerformanceMetric(
                    systemImage: "checkmark.seal.fill",
                    value: "\(totalDays)",
                    label: "JOURS RÉUSSIS",
                    colors: [ProfilePerformancePalette.orange, ProfilePerformancePalette.blue]
                )

                ProfilePerformanceMetric(
                    systemImage: "flame.fill",
                    value: "\(streak)",
                    label: "SÉRIE ACTUELLE",
                    colors: [ProfilePerformancePalette.yellow, Color(red: 1, green: 0.55, blue: 0.14)]
                )

                ProfilePerformanceMetric(
                    systemImage: "waveform.path.ecg",
                    value: healthScore > 0 ? "\(healthScore)" : "—",
                    label: "SCORE SANTÉ",
                    colors: [Color(red: 0.64, green: 0.75, blue: 1), ProfilePerformancePalette.blue]
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 58)
        }
    }
}

struct ProfilePerformanceStickyTopBar: View {
    let collapseProgress: CGFloat
    let onShare: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.12, blue: 0.14),
                    .black.opacity(0.97)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.22 + collapseProgress * 0.78)

            Rectangle()
                .fill(Color.white.opacity(0.12 * collapseProgress))
                .frame(height: 0.5)

            HStack {
                ProfilePerformanceRoundButton(
                    systemName: "square.and.arrow.up",
                    accessibilityLabel: "Partager le profil",
                    action: onShare
                )

                Spacer()

                ProfilePerformanceRoundButton(
                    systemName: "gearshape.fill",
                    accessibilityLabel: "Paramètres",
                    action: onSettings
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .frame(height: ProcessMainChromeMetrics.topSafeInset + 68)
        .ignoresSafeArea(edges: .top)
        .zIndex(20)
    }
}

struct ProfilePerformanceFloatingAvatar: View {
    let image: UIImage?
    let collapseProgress: CGFloat
    let onPhotoTap: (CGPoint) -> Void

    private var smoothProgress: CGFloat {
        collapseProgress * collapseProgress * (3 - 2 * collapseProgress)
    }

    private var scale: CGFloat {
        1 - smoothProgress * 0.54
    }

    private var centerY: CGFloat {
        let expanded = ProcessMainChromeMetrics.topSafeInset + 190
        let collapsed = ProcessMainChromeMetrics.topSafeInset + 34
        return expanded + (collapsed - expanded) * smoothProgress
    }

    var body: some View {
        ProfilePerformanceAvatar(
            image: image,
            chromeProgress: smoothProgress,
            onPhotoTap: onPhotoTap
        )
        .scaleEffect(scale)
        .offset(y: centerY - 88)
        .zIndex(30)
    }
}

private struct ProfilePerformanceAvatar: View {
    let image: UIImage?
    let chromeProgress: CGFloat
    let onPhotoTap: (CGPoint) -> Void

    @State private var glowPulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(ProfilePerformancePalette.blue.opacity(glowPulse ? 0.18 : 0.08))
                .frame(width: 174, height: 174)
                .blur(radius: glowPulse ? 24 : 16)
                .opacity(1 - chromeProgress)

            Circle()
                .stroke(ProfilePerformancePalette.warmCoolGradient, lineWidth: 1)
                .frame(width: 146, height: 146)
                .opacity(0.24 * (1 - chromeProgress))

            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: "person.fill")
                            .font(.system(size: 43, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            .frame(width: 116, height: 116)
            .clipShape(ProfileAvatarGemShape())
            .overlay {
                ProfileAvatarGemShape()
                    .stroke(ProfilePerformancePalette.warmCoolGradient, lineWidth: 1.6)
            }
            .shadow(
                color: ProfilePerformancePalette.orange.opacity(0.2 * (1 - chromeProgress)),
                radius: 16,
                x: -8
            )
            .shadow(
                color: ProfilePerformancePalette.blue.opacity(0.23 * (1 - chromeProgress)),
                radius: 16,
                x: 8
            )
            .contentShape(ProfileAvatarGemShape())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onEnded { value in onPhotoTap(value.location) }
            )
        }
        .frame(width: 176, height: 176)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
        .accessibilityLabel("Photo de profil")
        .accessibilityHint("Touchez pour la modifier")
    }
}

private struct ProfilePerformanceRoundButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.095))
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(ProfilePressStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ProfilePerformanceMetric: View {
    let systemImage: String
    let value: String
    let label: String
    let colors: [Color]

    @State private var isVisible = false

    private var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(gradient)
                    .blur(radius: 12)
                    .opacity(0.6)

                Image(systemName: systemImage)
                    .font(.system(size: 43, weight: .bold))
                    .foregroundStyle(gradient)
            }
            .frame(height: 58)

            Text(value)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(gradient)
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 10.5, weight: .heavy))
                .tracking(0.55)
                .foregroundStyle(gradient)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isVisible ? 1 : 0.86)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.76)) {
                isVisible = true
            }
        }
    }
}

struct ProfileRegularitySection: View {
    @Binding var selectedRange: ProfileAnalyticsRange
    let points: [ProfileAnalyticsPoint]
    let average: Int
    let comparison: Int?
    let canGoForward: Bool
    let canGoBackward: Bool
    let onBackward: () -> Void
    let onForward: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            averageHeader
                .padding(.horizontal, 22)

            rangePicker
                .padding(.horizontal, 22)
                .padding(.top, 25)

            periodNavigation
                .padding(.horizontal, 22)
                .padding(.top, 27)

            ProfileRegularityChart(points: points)
                .frame(height: 236)
                .padding(.leading, 22)
                .padding(.trailing, 10)
                .padding(.top, 16)
        }
    }

    private var averageHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(average)%")
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .foregroundStyle(ProfilePerformancePalette.warmCoolGradient)
                .contentTransition(.numericText())

            Text("RÉGULARITÉ MOYENNE")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(ProfilePerformancePalette.muted)

            comparisonCopy
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.52))
                .padding(.top, 11)
        }
    }

    @ViewBuilder
    private var comparisonCopy: some View {
        if let comparison, comparison != 0 {
            let direction = comparison > 0 ? "augmenté" : "diminué"
            let accent = comparison > 0 ? ProfilePerformancePalette.peach : ProfilePerformancePalette.blue
            (
                Text("Ta régularité a ")
                + Text("\(direction) de \(abs(comparison)) points")
                    .foregroundColor(accent)
                    .bold()
                + Text(" sur la période précédente.")
            )
        } else {
            Text(average > 0
                 ? "Chaque journée complétée renforce ton Process."
                 : "Complète ta journée pour lancer ta courbe.")
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(ProfileAnalyticsRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selectedRange == range ? .black : .white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background {
                            if selectedRange == range {
                                Capsule().fill(.white)
                            } else {
                                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var periodNavigation: some View {
        HStack {
            Button(action: onBackward) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canGoBackward ? .white.opacity(0.55) : .white.opacity(0.12))
                    .frame(width: 44, height: 36, alignment: .leading)
            }
            .disabled(!canGoBackward)

            Spacer()

            Text(periodTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .contentTransition(.interpolate)

            Spacer()

            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(canGoForward ? .white.opacity(0.55) : .white.opacity(0.12))
                    .frame(width: 44, height: 36, alignment: .trailing)
            }
            .disabled(!canGoForward)
        }
    }

    private var periodTitle: String {
        guard let first = points.first?.date, let last = points.last?.date else {
            return "Aucune donnée"
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(last), selectedRange == .week {
            return "7 derniers jours"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }
}

private struct ProfileRegularityChart: View {
    let points: [ProfileAnalyticsPoint]
    @State private var drawProgress: CGFloat = 0

    private var values: [Double] {
        points.map { min(100, max(0, $0.value)) }
    }

    var body: some View {
        GeometryReader { geometry in
            let chartWidth = max(geometry.size.width - 45, 1)
            let chartHeight = max(geometry.size.height - 28, 1)

            ZStack(alignment: .topLeading) {
                chartGrid(width: chartWidth, height: chartHeight)

                ProfileAnalyticsAreaShape(values: values)
                    .fill(
                        LinearGradient(
                            colors: [
                                ProfilePerformancePalette.orange.opacity(0.3),
                                ProfilePerformancePalette.blue.opacity(0.12),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: chartWidth, height: chartHeight)
                    .opacity(drawProgress)

                ProfileAnalyticsLineShape(values: values)
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        ProfilePerformancePalette.warmCoolGradient,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: chartWidth, height: chartHeight)
                    .shadow(color: ProfilePerformancePalette.blue.opacity(0.14), radius: 8)

                xAxis(width: chartWidth, height: chartHeight)
            }
            .padding(.leading, 0)
        }
        .id(points.map(\.id).joined())
        .onAppear {
            drawProgress = 0
            withAnimation(.easeInOut(duration: 0.9)) {
                drawProgress = 1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Courbe de régularité")
        .accessibilityValue("\(points.filter { $0.value >= 99 }.count) jours complétés sur \(points.count)")
    }

    private func chartGrid(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<5, id: \.self) { index in
                let y = height * CGFloat(index) / 4
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
                .stroke(Color.white.opacity(0.075), lineWidth: 0.7)

                Text("\(100 - index * 25)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.32))
                    .offset(x: width + 7, y: y - 7)
            }

            ForEach(0..<4, id: \.self) { index in
                let x = width * CGFloat(index) / 3
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                .stroke(Color.white.opacity(0.065), lineWidth: 0.7)
            }
        }
    }

    private func xAxis(width: CGFloat, height: CGFloat) -> some View {
        let labels = axisLabels
        return ZStack(alignment: .topLeading) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.34))
                    .position(
                        x: width * CGFloat(index) / CGFloat(max(labels.count - 1, 1)),
                        y: height + 18
                    )
            }
        }
        .frame(width: width, height: height + 28)
    }

    private var axisLabels: [String] {
        guard !points.isEmpty else { return ["—", "—", "—", "—"] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("EEE")

        let indices = [0, points.count / 3, points.count * 2 / 3, points.count - 1]
        return indices.map { formatter.string(from: points[min($0, points.count - 1)].date).capitalized }
    }
}

private struct ProfileAnalyticsLineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        smoothPath(in: rect, closesToBottom: false)
    }

    fileprivate func smoothPath(in rect: CGRect, closesToBottom: Bool) -> Path {
        var path = Path()
        guard !values.isEmpty else { return path }

        let points = values.enumerated().map { index, value in
            CGPoint(
                x: values.count == 1 ? rect.midX : rect.width * CGFloat(index) / CGFloat(values.count - 1),
                y: rect.height * (1 - CGFloat(value / 100))
            )
        }

        if closesToBottom {
            path.move(to: CGPoint(x: points[0].x, y: rect.maxY))
            path.addLine(to: points[0])
        } else {
            path.move(to: points[0])
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            let midpoint = (previous.x + current.x) / 2
            path.addCurve(
                to: current,
                control1: CGPoint(x: midpoint, y: previous.y),
                control2: CGPoint(x: midpoint, y: current.y)
            )
        }

        if closesToBottom, let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

private struct ProfileAnalyticsAreaShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        ProfileAnalyticsLineShape(values: values).smoothPath(in: rect, closesToBottom: true)
    }
}

struct ProfileReferralSection: View {
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Invite tes proches")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)

                Text("Progressez ensemble et débloquez vos avantages.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.48))
            }

            ProfileReferralInteractiveCard()

            Button(action: onOpen) {
                Text("Voir les avantages")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white, in: Capsule())
            }
            .buttonStyle(ProfilePressStyle())
        }
        .padding(.horizontal, 22)
    }
}

private struct ProfileAvatarGemShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [
            CGPoint(x: 0.50, y: 0.00),
            CGPoint(x: 0.82, y: 0.09),
            CGPoint(x: 1.00, y: 0.39),
            CGPoint(x: 0.91, y: 0.78),
            CGPoint(x: 0.59, y: 1.00),
            CGPoint(x: 0.23, y: 0.91),
            CGPoint(x: 0.00, y: 0.61),
            CGPoint(x: 0.08, y: 0.23)
        ].map { CGPoint(x: $0.x * rect.width, y: $0.y * rect.height) }

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
