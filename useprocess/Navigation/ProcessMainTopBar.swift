import SwiftUI

struct ProcessWordmark: View {
    enum Style {
        case automatic
        case onDarkBackground
        case onLightBackground
    }

    var height: CGFloat = 22
    var style: Style = .automatic

    @Environment(\.colorScheme) private var colorScheme

    private var shouldInvert: Bool {
        switch style {
        case .onDarkBackground: false
        case .onLightBackground: true
        case .automatic: colorScheme == .light
        }
    }

    var body: some View {
        Group {
            if UIImage(named: "ProcessWordmark") != nil {
                wordmarkImage
            } else {
                Text("Process")
                    .font(.system(size: height * 0.85, weight: .bold, design: .rounded))
                    .tracking(-0.5)
            }
        }
        .accessibilityLabel("Process")
    }

    @ViewBuilder
    private var wordmarkImage: some View {
        let image = Image("ProcessWordmark")
            .resizable()
            .scaledToFit()
            .frame(height: height)
        if shouldInvert {
            image.colorInvert()
        } else {
            image
        }
    }
}

struct ProcessTopBarIconButton: View {
    let systemName: String
    var iconSize: CGFloat = 20
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? Color.primary : Color.primary.opacity(0.88))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(systemName.contains("person") ? "Profil" : systemName)
    }
}

struct ProcessFeedScrollHeader: View {
    var isScanActive: Bool = false
    var isProfileActive: Bool = false
    var onScan: () -> Void
    var onProfile: () -> Void

    var body: some View {
        HStack {
            ProcessTopBarIconButton(
                systemName: isScanActive ? "viewfinder.circle.fill" : "viewfinder",
                iconSize: 20,
                isActive: isScanActive,
                action: onScan
            )

            Spacer(minLength: 0)

            ProcessTopBarIconButton(
                systemName: isProfileActive ? "person.crop.circle.fill" : "person.crop.circle",
                iconSize: 20,
                isActive: isProfileActive,
                action: onProfile
            )
        }
        .font(.title3)
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 15)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

struct ProcessMainTopChrome: View {
    @Binding var selectedSection: ProcessMainSection
    let pageSection: ProcessMainSection

    var body: some View {
        ProcessMainFilterBar(selection: $selectedSection)
    }
}
