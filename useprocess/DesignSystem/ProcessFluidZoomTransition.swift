import SwiftUI

/// Identifiants partagés entre `matchedTransitionSource` et `navigationTransition(.zoom)`.
enum ProcessZoomTransitionID: Hashable {
    case coach
    case faceScanHistory
    case streak
    case mealDetail(MealTimeSlot)
    case trainingDay
    case planResource(PlanResourceSheet)

    var sourceID: String {
        switch self {
        case .coach:
            return "PROCESS_COACH"
        case .faceScanHistory:
            return "PROCESS_FACE_SCAN_HISTORY"
        case .streak:
            return "PROCESS_STREAK"
        case .mealDetail(let slot):
            return "PROCESS_MEAL_DETAIL_\(slot.rawValue)"
        case .trainingDay:
            return "PROCESS_TRAINING_DAY"
        case .planResource(let sheet):
            return "PROCESS_PLAN_RESOURCE_\(sheet.id)"
        }
    }
}

enum ProcessCoachZoomTransition {
    static let sourceID = ProcessZoomTransitionID.coach.sourceID
}

/// Style bouton source — glass + matchedTransitionSource + haptique (pattern FluidZoom).
struct ProcessFluidZoomButtonStyle<S: InsettableShape>: ButtonStyle {
    let id: String
    let namespace: Namespace.ID
    let shape: S
    var usesGlass: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        ProcessFluidZoomButtonStyleBody(
            id: id,
            namespace: namespace,
            shape: shape,
            usesGlass: usesGlass,
            configuration: configuration
        )
    }
}

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
    func processZoomTransition(id: ProcessZoomTransitionID, namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id.sourceID, in: namespace))
        } else {
            self
        }
    }

    @ViewBuilder
    func processCoachZoomTransition(namespace: Namespace.ID) -> some View {
        processZoomTransition(id: .coach, namespace: namespace)
    }
}
