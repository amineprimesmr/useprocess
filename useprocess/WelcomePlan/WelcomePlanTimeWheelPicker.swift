import SwiftUI

enum WelcomePlanTimeWheelRange {
    /// Journée complète — 00:00 → 23:30.
    case fullDay
    /// Coucher : 18:00 → 23:30 puis 00:00 → 06:00.
    case bedtime

    var slotMinutes: [Int] {
        switch self {
        case .fullDay:
            return stride(from: 0, to: 24 * 60, by: 30).map { $0 }
        case .bedtime:
            let evening = stride(from: 18 * 60, to: 24 * 60, by: 30).map { $0 }
            let afterMidnight = stride(from: 0, through: 6 * 60, by: 30).map { $0 }
            return evening + afterMidnight
        }
    }
}

/// Roulette horaire (créneaux 30 min) — même UX que `AgeWheelPicker`, une seule colonne.
struct WelcomePlanTimeWheelPicker: View {
    @Binding var selection: Date
    var range: WelcomePlanTimeWheelRange = .fullDay
    var onTimeChanged: ((Date) -> Void)? = nil

    private let stepMinutes = 30
    private let itemHeight: CGFloat = 64
    private let visibleItems = 5

    private var slots: [Int] { range.slotMinutes }

    @State private var selectedMinutes: Int = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    @State private var dragVelocity: CGFloat = 0
    @State private var lastDragTime = Date()
    @State private var scrollTask: Task<Void, Never>?
    @State private var itemPositions: [Int: CGFloat] = [:]
    @State private var lastVibratedSlot: Int?
    @State private var hasInitialized = false

    var body: some View {
        GeometryReader { geometry in
            let centerY = geometry.size.height / 2

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: centerY - itemHeight / 2)

                        ForEach(slots, id: \.self) { minutes in
                            TimeWheelItem(
                                label: Self.label(for: minutes),
                                isSelected: minutes == selectedMinutes,
                                itemHeight: itemHeight,
                                centerY: centerY,
                                slotID: minutes
                            )
                            .id(minutes)
                        }

                        Spacer()
                            .frame(height: centerY - itemHeight / 2)
                    }
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: scrollGeometry.frame(in: .named("timeWheelScroll")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "timeWheelScroll")
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.20),
                            .init(color: .black, location: 0.80),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .scrollDismissesKeyboard(.never)
                .onPreferenceChange(ItemPositionPreferenceKey.self) { positions in
                    itemPositions = positions
                    updateSelection(centerY: centerY)
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    let now = Date()
                    let timeDelta = now.timeIntervalSince(lastDragTime)
                    if timeDelta > 0 {
                        dragVelocity = (value - scrollOffset) / CGFloat(timeDelta)
                    }
                    scrollOffset = value
                    lastDragTime = now
                    scrollTask?.cancel()
                    updateSelection(centerY: centerY)

                    if abs(dragVelocity) < 50 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            snapToNearest(proxy: proxy, centerY: centerY)
                        }
                    } else {
                        scrollTask = Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if !Task.isCancelled {
                                snapToNearest(proxy: proxy, centerY: centerY)
                            }
                        }
                    }
                }
                .onAppear {
                    selectedMinutes = Self.nearestSlotMinutes(to: selection, in: slots)
                    let initial = selectedMinutes

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scrollToSlot(initial, proxy: proxy, animated: false)
                        syncSelectionDate()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            hasInitialized = true
                        }
                    }
                }
                .onChange(of: selection) { _, newValue in
                    let minutes = Self.nearestSlotMinutes(to: newValue, in: slots)
                    guard minutes != selectedMinutes else { return }
                    selectedMinutes = minutes
                    if !isScrolling {
                        scrollToSlot(minutes, proxy: proxy, animated: true)
                    }
                }
                .onChange(of: range) { _, _ in
                    selectedMinutes = Self.nearestSlotMinutes(to: selection, in: slots)
                    scrollToSlot(selectedMinutes, proxy: proxy, animated: false)
                    syncSelectionDate()
                }
            }
        }
        .frame(height: CGFloat(visibleItems) * itemHeight)
    }

    private func scrollToSlot(_ minutes: Int, proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.onboardingTransition) {
                proxy.scrollTo(minutes, anchor: .center)
            }
        } else {
            proxy.scrollTo(minutes, anchor: .center)
        }
    }

    private func updateSelection(centerY: CGFloat) {
        guard hasInitialized else { return }
        guard let nearest = nearestSlot(centerY: centerY), nearest != selectedMinutes else { return }

        isScrolling = true
        selectedMinutes = nearest

        if lastVibratedSlot != nearest {
            HapticManager.shared.selection()
            lastVibratedSlot = nearest
        }

        syncSelectionDate()
        onTimeChanged?(selection)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isScrolling = false
        }
    }

    private func snapToNearest(proxy: ScrollViewProxy, centerY: CGFloat) {
        guard let nearest = nearestSlot(centerY: centerY) else {
            scrollToSlot(selectedMinutes, proxy: proxy, animated: true)
            return
        }

        if nearest != selectedMinutes {
            isScrolling = true
            selectedMinutes = nearest
            syncSelectionDate()
            onTimeChanged?(selection)
        }

        scrollToSlot(nearest, proxy: proxy, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isScrolling = false
        }
    }

    private func nearestSlot(centerY: CGFloat) -> Int? {
        var nearest: Int?
        var minDistance: CGFloat = .infinity

        for (minutes, position) in itemPositions where slots.contains(minutes) {
            let distance = abs(position - centerY)
            if distance < minDistance {
                minDistance = distance
                nearest = minutes
            }
        }

        return nearest
    }

    private func syncSelectionDate() {
        selection = Self.date(fromMinutes: selectedMinutes) ?? selection
    }

    static func nearestSlotMinutes(to date: Date, in slots: [Int]) -> Int {
        let snapped = snappedMinutes(from: date)
        return slots.min(by: { abs($0 - snapped) < abs($1 - snapped) }) ?? slots.first ?? 0
    }

    static func snappedMinutes(from date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let total = hour * 60 + minute
        return (total / 30) * 30
    }

    static func date(fromMinutes minutes: Int) -> Date? {
        Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60))
    }

    static func label(for minutes: Int) -> String {
        guard let date = date(fromMinutes: minutes) else { return "00:00" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private struct TimeWheelItem: View {
    let label: String
    let isSelected: Bool
    let itemHeight: CGFloat
    let centerY: CGFloat
    let slotID: Int

    var body: some View {
        GeometryReader { geometry in
            let itemCenter = geometry.frame(in: .named("timeWheelScroll")).midY
            let distanceFromCenter = abs(itemCenter - centerY)
            let maxDistance = itemHeight * 2.5
            let normalizedDistance = min(1.0, distanceFromCenter / maxDistance)
            let scale = 1.0 - (normalizedDistance * 0.35)
            let opacity = 1.0 - (normalizedDistance * 0.7)

            Text(label)
                .font(.system(size: isSelected ? 52 : 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    isSelected
                        ? LinearGradient(
                            colors: [
                                OnboardingTheme.primaryText,
                                OnboardingTheme.primaryText.opacity(0.95),
                                Color.gray.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                OnboardingTheme.primaryText.opacity(0.6),
                                OnboardingTheme.primaryText.opacity(0.5),
                                Color.gray.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .frame(maxWidth: .infinity)
                .frame(height: itemHeight)
                .contentShape(Rectangle())
                .animation(.onboardingTransition, value: isSelected)
                .background(
                    GeometryReader { itemGeometry in
                        Color.clear
                            .preference(
                                key: ItemPositionPreferenceKey.self,
                                value: [slotID: itemGeometry.frame(in: .named("timeWheelScroll")).midY]
                            )
                    }
                )
        }
        .frame(height: itemHeight)
    }
}
