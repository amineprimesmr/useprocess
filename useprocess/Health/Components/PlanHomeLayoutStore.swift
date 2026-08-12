import Foundation

@MainActor
@Observable
final class PlanHomeLayoutStore {
    static let shared = PlanHomeLayoutStore()

    private(set) var orderedSections: [PlanHomeSectionKind] = PlanHomeSectionKind.defaultOrder
    private(set) var hiddenSectionIDs: Set<String> = []

    private let storageKeyBase = "plan.home.layout"
    private let swappedTrainingFaceRoutineMigrationKey = "plan.home.layout.swappedTrainingFaceRoutine.v1"
    private let hideTrainingOnHomeMigrationKey = "plan.home.layout.hideTrainingOnHome.v1"

    private init() {
        reload()
    }

    var visibleSections: [PlanHomeSectionKind] {
        orderedSections
            .filter { !hiddenSectionIDs.contains($0.rawValue) && $0 != .resources && $0 != .training }
    }

    var visibleSectionIDs: [String] {
        visibleSections.map(\.rawValue)
    }

    func isVisible(_ section: PlanHomeSectionKind) -> Bool {
        !hiddenSectionIDs.contains(section.rawValue)
    }

    func reload() {
        let key = UserScopedStorage.key(storageKeyBase)
        guard let data = UserDefaults.standard.data(forKey: key),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            orderedSections = PlanHomeSectionKind.defaultOrder
            hiddenSectionIDs = []
            return
        }

        orderedSections = Self.normalizedOrder(payload.order)
        hiddenSectionIDs = Set(payload.hidden.filter { PlanHomeSectionKind(rawValue: $0) != nil })
        // Migration : les repas debloat restent toujours visibles sur l'accueil.
        if hiddenSectionIDs.remove(PlanHomeSectionKind.nutrition.rawValue) != nil {
            persist()
        }
        migrateSwapTrainingAndFaceRoutineIfNeeded()
        migrateHideTrainingOnHomeIfNeeded()
    }

    /// Cardio et Circuit — uniquement dans Réglages, plus sur l'accueil.
    private func migrateHideTrainingOnHomeIfNeeded() {
        let migrationKey = UserScopedStorage.key(hideTrainingOnHomeMigrationKey)
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        hiddenSectionIDs.insert(PlanHomeSectionKind.training.rawValue)
        orderedSections.removeAll { $0 == .training }
        persist()

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Circuit lymphatique avant Cardio et Circuit (legacy).
    private func migrateSwapTrainingAndFaceRoutineIfNeeded() {
        let migrationKey = UserScopedStorage.key(swappedTrainingFaceRoutineMigrationKey)
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        if let trainingIndex = orderedSections.firstIndex(of: .training),
           let faceRoutineIndex = orderedSections.firstIndex(of: .faceRoutine),
           trainingIndex < faceRoutineIndex {
            orderedSections.swapAt(trainingIndex, faceRoutineIndex)
            persist()
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    func moveSection(_ section: PlanHomeSectionKind, before target: PlanHomeSectionKind) {
        guard section != target else { return }
        let ordered = orderedSections
        guard let from = ordered.firstIndex(of: section),
              let to = ordered.firstIndex(of: target),
              from != to else { return }
        moveSections(
            fromOffsets: IndexSet(integer: from),
            toOffset: to > from ? to + 1 : to
        )
    }

    func moveSections(fromOffsets source: IndexSet, toOffset destination: Int) {
        var sections = orderedSections
        guard !source.isEmpty else { return }

        let moving = source.map { sections[$0] }
        for index in source.sorted(by: >) {
            sections.remove(at: index)
        }

        var insertIndex = destination
        for index in source where index < destination {
            insertIndex -= 1
        }
        sections.insert(contentsOf: moving, at: insertIndex)

        orderedSections = Self.normalizedOrder(sections.map(\.rawValue))
        persist()
    }

    func setVisible(_ section: PlanHomeSectionKind, visible: Bool) {
        if visible {
            hiddenSectionIDs.remove(section.rawValue)
        } else {
            hiddenSectionIDs.insert(section.rawValue)
        }
        persist()
    }

    func toggleVisibility(for section: PlanHomeSectionKind) {
        setVisible(section, visible: !isVisible(section))
    }

    func resetToDefault() {
        orderedSections = PlanHomeSectionKind.defaultOrder
        hiddenSectionIDs = []
        persist()
    }

    private func persist() {
        let payload = Payload(
            order: orderedSections.map(\.rawValue),
            hidden: Array(hiddenSectionIDs)
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: UserScopedStorage.key(storageKeyBase))
    }

    private static func normalizedOrder(_ rawIDs: [String]) -> [PlanHomeSectionKind] {
        var result: [PlanHomeSectionKind] = []
        for raw in rawIDs {
            guard let kind = PlanHomeSectionKind(rawValue: raw),
                  !result.contains(kind) else { continue }
            result.append(kind)
        }
        for kind in PlanHomeSectionKind.defaultOrder where !result.contains(kind) {
            result.append(kind)
        }
        return result.filter { $0 != .resources }
    }

    private struct Payload: Codable {
        var order: [String]
        var hidden: [String]
    }
}
