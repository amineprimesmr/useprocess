import SwiftUI
import SafariServices

// MARK: - Consentement IA tierce (Anthropic / Claude)

struct ThirdPartyAIConsentView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var onAccept: () -> Void
    var onDecline: () -> Void

    @State private var safariURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBlock

                    disclosureSection(
                        title: "Données envoyées",
                        items: [
                            "Messages écrits ou dictés au coach",
                            "Profil (prénom, âge, objectifs, sport, nutrition)",
                            "Résumés santé HealthKit (pas, sommeil, fréquence cardiaque, readiness)",
                            "Historique de scans et scores wellness",
                            "Photos que tu envoies volontairement au coach ou pour les repas"
                        ]
                    )

                    disclosureSection(
                        title: "Destinataire",
                        items: [
                            "Anthropic PBC — modèle Claude (IA conversationnelle)",
                            "Transmis via Google Firebase Cloud Functions (proxy sécurisé)",
                            "Anthropic ne utilise pas les données API pour entraîner ses modèles (conditions commerciales)"
                        ]
                    )

                    disclosureSection(
                        title: "Finalités",
                        items: [
                            "Réponses du coach personnalisées",
                            "Génération de protocole et suggestions repas",
                            "Analyses wellness (scan visage/corps, si tu l'autorises séparément)"
                        ]
                    )

                    Text("Tu peux refuser : le coach IA, les suggestions repas IA et les analyses cloud seront désactivés. Le suivi local (Santé, scans sans IA) reste disponible.")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)

                    privacyPolicyLink
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Coach IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Plus tard", action: onDecline)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("J'accepte — activer le coach IA")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.onboardingAccent)

                    Button("Refuser", action: onDecline)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                ProcessPrivacySafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Données personnelles et IA", systemImage: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.primaryText)
            Text("Process envoie certaines données à un service d'intelligence artificielle tiers pour le coach et les fonctionnalités IA. Apple exige que tu sois informé et que tu donnes ton accord explicite.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
    }

    private var privacyPolicyLink: some View {
        Button {
            safariURL = ProcessLegalURLs.privacyPolicy
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hand.raised.fill")
                Text("Lire la politique de confidentialité")
            }
            .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(theme.onboardingAccent)
    }

    private func disclosureSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primaryText)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Consentement scan visage (TrueDepth)

struct FaceScanPrivacyConsentView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @Binding var enableAIAnalysis: Bool
    var onAccept: () -> Void
    var onCancel: () -> Void

    @State private var safariURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Scan visage TrueDepth", systemImage: "face.smiling")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.primaryText)
                        Text("Ce scan utilise la caméra TrueDepth (Face ID) pour estimer des indicateurs wellness. Aucune reconnaissance d'identité n'est effectuée.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    disclosureSection(
                        title: "Données faciales collectées",
                        items: [
                            "Mesh 3D du visage (géométrie TrueDepth, stockée localement pour la baseline)",
                            "Photo JPEG et courte vidéo du scan (stockées localement ; la photo peut être envoyée seulement si tu actives l'analyse IA)",
                            "Scores wellness dérivés (gonflement, cernes, tension mâchoire, clarté peau)",
                            "Aucune identification biométrique et aucun modèle Face ID n'est créé"
                        ]
                    )

                    disclosureSection(
                        title: "Stockage",
                        items: [
                            "Mesh, photos et vidéos : uniquement sur ton appareil (stockage app protégé)",
                            "Scores et métadonnées : synchronisés sur Firebase Firestore si tu es connecté — max. 90 scans (purge auto cloud + local)",
                            "Révoquer dans Paramètres supprime scans, photos et données cloud",
                            "Suppression sous 30 jours après suppression du compte"
                        ]
                    )

                    Toggle(isOn: $enableAIAnalysis) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analyse IA de ma photo (Anthropic Claude)")
                                .font(.subheadline.weight(.semibold))
                            Text("Option désactivée par défaut. Si tu l'actives, la photo JPEG du scan est envoyée à Anthropic via Firebase pour une analyse wellness ponctuelle.")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryText)
                        }
                    }
                    .tint(theme.onboardingAccent)
                    .padding(14)
                    .background(theme.cardBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        safariURL = ProcessLegalURLs.privacyPolicyFaceData
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                            Text("Section « Données faciales » de la politique")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(theme.onboardingAccent)
                }
                .padding(20)
                .padding(.bottom, 12)
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Scan visage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("J'accepte et lancer le scan")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.onboardingAccent)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                ProcessPrivacySafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private func disclosureSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primaryText)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Gate scan visage

struct FaceScanPrivacyGateView: View {
    @Environment(\.appTheme) private var theme

    var onDismiss: () -> Void
    var onComplete: (FaceScanResult) -> Void

    @State private var consentStore = ProcessPrivacyConsentStore.shared
    @State private var showScanner = false
    @State private var enableAIAnalysis = false

    var body: some View {
        Group {
            if showScanner || consentStore.canCaptureFaceScan {
                FaceScanSessionView(
                    onDismiss: onDismiss,
                    onComplete: onComplete
                )
            } else {
                FaceScanPrivacyConsentView(
                    enableAIAnalysis: $enableAIAnalysis,
                    onAccept: acceptAndScan,
                    onCancel: onDismiss
                )
            }
        }
        .onAppear {
            if consentStore.canCaptureFaceScan {
                showScanner = true
            }
        }
    }

    private func acceptAndScan() {
        consentStore.acceptFaceScanCapture(enableAIAnalysis: enableAIAnalysis)
        showScanner = true
    }
}

/// Gate onboarding / welcome plan — capture directe sans session complète.
struct FaceScanCapturePrivacyGateView: View {
    var onBack: () -> Void
    var onSkip: () -> Void
    var onCapture: (FaceScanCapturePayload, FaceWellnessMarkers) -> Void

    @State private var consentStore = ProcessPrivacyConsentStore.shared
    @State private var showScanner = false
    @State private var enableAIAnalysis = false

    var body: some View {
        Group {
            if showScanner || consentStore.canCaptureFaceScan {
                FaceScanCaptureScreen(
                    onBack: onBack,
                    onSkip: onSkip,
                    onContinue: onCapture
                )
            } else {
                FaceScanPrivacyConsentView(
                    enableAIAnalysis: $enableAIAnalysis,
                    onAccept: acceptAndScan,
                    onCancel: onBack
                )
            }
        }
        .onAppear {
            if consentStore.canCaptureFaceScan {
                showScanner = true
            }
        }
    }

    private func acceptAndScan() {
        consentStore.acceptFaceScanCapture(enableAIAnalysis: enableAIAnalysis)
        showScanner = true
    }
}

// MARK: - Modifier consentement IA global

extension View {
    func processThirdPartyAIConsentSheet() -> some View {
        modifier(ProcessThirdPartyAIConsentModifier())
    }
}

private struct ProcessThirdPartyAIConsentModifier: ViewModifier {
    @State private var consentStore = ProcessPrivacyConsentStore.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $consentStore.isPresentingThirdPartyAIConsent) {
                ThirdPartyAIConsentView(
                    onAccept: { consentStore.acceptThirdPartyAI() },
                    onDecline: { consentStore.declineThirdPartyAI() }
                )
                .interactiveDismissDisabled()
            }
    }
}

private struct ProcessPrivacySafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
