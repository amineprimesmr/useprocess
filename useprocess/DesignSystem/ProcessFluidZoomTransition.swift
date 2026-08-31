import SwiftUI

/// Identifiants partagés entre `matchedTransitionSource` et `navigationTransition(.zoom)`.
enum ProcessZoomTransitionID: Hashable {
    case coach
    case faceScanHistory
    case faceScanCapture
    case faceScanDetail(String)
    case mealDetail(MealTimeSlot)
    case mealCatalog
    case trainingDay
    case postureCircuit
    case protocolItem(String)
    case homeLayoutEditor
    case activityStatus
    case settings
    case planResource(PlanResourceSheet)
    case planCalendar

    /// Spring partagé — ouverture/fermeture zoom (repas, calendrier, protocoles).
    static let presentationSpring = Animation.spring(response: 0.32, dampingFraction: 0.9)

    var sourceID: String {
        switch self {
        case .coach:
            return "PROCESS_COACH"
        case .faceScanHistory:
            return "PROCESS_FACE_SCAN_HISTORY"
        case .faceScanCapture:
            return "PROCESS_FACE_SCAN_CAPTURE"
        case .faceScanDetail(let scanID):
            return "PROCESS_FACE_SCAN_DETAIL_\(scanID)"
        case .mealDetail(let slot):
            return "PROCESS_MEAL_DETAIL_\(slot.rawValue)"
        case .mealCatalog:
            return "PROCESS_MEAL_CATALOG"
        case .trainingDay:
            return "PROCESS_TRAINING_DAY"
        case .postureCircuit:
            return "PROCESS_POSTURE_CIRCUIT"
        case .protocolItem(let itemID):
            return "PROCESS_PROTOCOL_ITEM_\(itemID)"
        case .homeLayoutEditor:
            return "PROCESS_HOME_LAYOUT_EDITOR"
        case .activityStatus:
            return "PROCESS_ACTIVITY_STATUS"
        case .settings:
            return "PROCESS_SETTINGS"
        case .planResource(let sheet):
            return "PROCESS_PLAN_RESOURCE_\(sheet.id)"
        case .planCalendar:
            return "PROCESS_PLAN_CALENDAR"
        }
    }
}

enum ProcessCoachZoomTransition {
    static let sourceID = ProcessZoomTransitionID.coach.sourceID
}

/// Style bouton source — glass + matchedTransitionSource + haptique (pattern FluidZoom).

private struct ProcessFluidZoomButtonStyleBody<S: InsettableShape>: View {
    let id: String
    let namespace: Namespace.ID
    let shape: S
    let usesGlass: Bool
    let configuration: ButtonStyleConfiguration

    var body: some View {
        Group {
            if usesGlass {
                configuration.label
                    .modifier(ProcessFluidZoomGlassModifier(shape: shape))
            } else {
                configuration.label
            }
        }
        .matchedTransitionSource(id: id, in: namespace)
    }
}

private struct ProcessFluidZoomGlassModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(ProcessGlass.regularSurface, in: shape)
        } else {
            content.processGlassEffect(in: shape, interactive: false)
        }
    }
}

extension View {
    @ViewBuilder
    func processZoomSource(id: ProcessZoomTransitionID, namespace: Namespace.ID) -> some View {
        matchedTransitionSource(id: id.sourceID, in: namespace)
    }

    @ViewBuilder
    func processZoomSource(id: ProcessZoomTransitionID, namespace: Namespace.ID?) -> some View {
        if let namespace {
            processZoomSource(id: id, namespace: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func processZoomSource(id: ProcessZoomTransitionID?, namespace: Namespace.ID?) -> some View {
        if let id, let namespace {
            processZoomSource(id: id, namespace: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func processZoomTransition(id: ProcessZoomTransitionID, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id.sourceID, in: namespace))
        } else {
            transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    @ViewBuilder
    func processZoomTransition(id: ProcessZoomTransitionID, namespace: Namespace.ID?) -> some View {
        if let namespace {
            processZoomTransition(id: id, namespace: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func processCoachZoomTransition(namespace: Namespace.ID) -> some View {
        processZoomTransition(id: .coach, namespace: namespace)
    }
}
