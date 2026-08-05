import Foundation

/// Synthèse déterministe de l'analyse structurelle onboarding à partir des markers locaux.
enum OnboardingFaceDeepAnalysisBuilder {

    static func build(from result: FaceScanResult) -> OnboardingFaceDeepAnalysis {
        let markers = result.markers
        let seed = stableSeed(from: result.id)

        let retention = FaceScanIndicators.displayPercent(for: .retention, result: result)
        let cortisol = FaceScanIndicators.displayPercent(for: .stressLoad, result: result)
        let retentionZone = FaceScanIndicators.displayZone(for: .retention, result: result)
        let cortisolZone = FaceScanIndicators.displayZone(for: .stressLoad, result: result)

        let unlocked: [OnboardingFaceDeepAnalysis.UnlockedMetric] = [
            .init(
                kind: .retention,
                percent: retention,
                zone: retentionZone,
                phrase: FaceScanIndicators.adverseFacePhrase(for: .retention, load: retention)
            ),
            .init(
                kind: .stressLoad,
                percent: cortisol,
                zone: cortisolZone,
                phrase: FaceScanIndicators.adverseFacePhrase(for: .stressLoad, load: cortisol)
            )
        ]

        let lockedMetrics = OnboardingFaceDeepAnalysis.Kind.allCases.map { kind in
            let percent = score(for: kind, markers: markers, seed: seed)
            return OnboardingFaceDeepAnalysis.LockedMetric(
                kind: kind,
                percent: percent,
                zone: zone(for: kind, percent: percent)
            )
        }

        let flaws = primaryFlaws(from: lockedMetrics, retention: retention, cortisol: cortisol)
        let strengths = strengths(from: lockedMetrics)
        let summary = summaryText(
            retention: retention,
            cortisol: cortisol,
            flaws: flaws,
            strengths: strengths
        )
        let volumeComposition = facialVolumeComposition(
            from: result,
            retention: retention
        )

        return OnboardingFaceDeepAnalysis(
            unlocked: unlocked,
            volumeComposition: volumeComposition,
            lockedMetrics: lockedMetrics,
            primaryFlaws: flaws,
            strengths: strengths,
            summary: summary
        )
    }

    private static func facialVolumeComposition(
        from result: FaceScanResult,
        retention: Int
    ) -> OnboardingFaceDeepAnalysis.FacialVolumeComposition {
        let markers = result.markers
        let puffiness = markers.puffinessScore
        let definition = FaceScanIndicators.definitionScore(from: markers)

        var bloated = 88.0
        bloated += Double(retention - 52) * 0.07
        bloated += Double(puffiness - 50) * 0.06
        bloated -= Double(definition - 50) * 0.05

        let bloatedPercent = Int(min(94, max(84, bloated.rounded())))
        let fatPercent = 100 - bloatedPercent

        let phrase: String = {
            if fatPercent <= 10 {
                return AppCopy.tSync(
                    "Peu de graisse — surtout de la rétention",
                    en: "Little fat — mostly retention"
                )
            }
            if bloatedPercent >= 90 {
                return AppCopy.tSync(
                    "Volume surtout dû à la rétention, pas à la graisse",
                    en: "Volume mostly from retention, not fat"
                )
            }
            return AppCopy.tSync(
                "La rétention pèse plus que la graisse faciale",
                en: "Retention outweighs facial fat"
            )
        }()

        let goodNewsPhrase: String = {
            if bloatedPercent >= 90 {
                return AppCopy.tSync(
                    "Bonne nouvelle : c’est surtout de la rétention — donc réversible avec ton plan, pas de la graisse.",
                    en: "Good news: it’s mostly retention — reversible with your plan, not fat."
                )
            }
            return AppCopy.tSync(
                "Bonne nouvelle : ton volume facial se corrige — la rétention part plus vite que la graisse.",
                en: "Good news: your facial volume can improve — retention clears faster than fat."
            )
        }()

        return .init(
            fatPercent: fatPercent,
            bloatedPercent: bloatedPercent,
            phrase: phrase,
            goodNewsPhrase: goodNewsPhrase
        )
    }

    // MARK: - Scores

    private static func score(
        for kind: OnboardingFaceDeepAnalysis.Kind,
        markers: FaceWellnessMarkers,
        seed: UInt64
    ) -> Int {
        let jitter = seededJitter(kind: kind, seed: seed)

        let raw: Double
        switch kind {
        case .eyes:
            raw = Double(100 - markers.underEyeFatigueScore) * 0.72
                + Double(markers.facialSymmetryScore) * 0.18
                + jitter
        case .midFace:
            raw = Double(100 - markers.puffinessScore) * 0.45
                + Double(FaceScanIndicators.definitionScore(from: markers)) * 0.40
                + jitter
        case .lowerThird:
            raw = Double(FaceScanIndicators.definitionScore(from: markers)) * 0.62
                + Double(100 - markers.jawTensionScore) * 0.28
                + jitter
        case .upperThird:
            raw = Double(markers.skinClarityScore) * 0.38
                + Double(100 - markers.underEyeFatigueScore) * 0.42
                + jitter
        case .orbitalDepth:
            raw = Double(100 - markers.underEyeFatigueScore) * 0.55
                + Double(markers.facialSymmetryScore) * 0.30
                + jitter
        case .underEyeHealth:
            raw = Double(markers.underEyeFatigueScore) * 0.85 + jitter
        case .nasolabialFold:
            raw = Double(markers.puffinessScore) * 0.48
                + Double(100 - markers.skinClarityScore) * 0.32
                + Double(markers.jawTensionScore) * 0.12
                + jitter
        case .cheekbones:
            raw = Double(FaceScanIndicators.definitionScore(from: markers)) * 0.70
                + Double(100 - markers.puffinessScore) * 0.22
                + jitter
        case .maxillary:
            raw = Double(FaceScanIndicators.definitionScore(from: markers)) * 0.58
                + Double(100 - markers.jawTensionScore) * 0.28
                + jitter
        case .nose:
            raw = 58 + Double(markers.facialSymmetryScore) * 0.22 + jitter
        case .skin:
            raw = Double(markers.skinClarityScore) * 0.92 + jitter
        case .harmony:
            raw = Double(markers.facialSymmetryScore) * 0.42
                + Double(FaceScanIndicators.definitionScore(from: markers)) * 0.28
                + Double(markers.skinClarityScore) * 0.18
                + jitter
        case .symmetry:
            raw = Double(markers.facialSymmetryScore) * 0.90 + jitter
        case .neckWidth:
            raw = 52 + Double(100 - markers.jawTensionScore) * 0.24
                + Double(FaceScanIndicators.definitionScore(from: markers)) * 0.14
                + jitter
        case .boneMass:
            raw = 50 + Double(FaceScanIndicators.definitionScore(from: markers)) * 0.28
                + Double(markers.facialSymmetryScore) * 0.12
                + jitter
        }

        return Int(max(18, min(96, raw.rounded())))
    }

    private static func zone(
        for kind: OnboardingFaceDeepAnalysis.Kind,
        percent: Int
    ) -> FaceScanIndicators.WellnessZone {
        if kind.higherIsWorse {
            switch percent {
            case ..<48: return .optimal
            case 48..<78: return .sufficient
            default: return .insufficient
            }
        }
        return FaceScanIndicators.wellnessZone(forPercent: percent)
    }

    // MARK: - Insights

    private static func primaryFlaws(
        from metrics: [OnboardingFaceDeepAnalysis.LockedMetric],
        retention: Int,
        cortisol: Int
    ) -> [String] {
        var flaws: [String] = []

        if retention >= 62 {
            flaws.append(AppCopy.tSync(
                "Rétention faciale marquée — volume et gonflement visibles",
                en: "Marked facial retention — visible volume and puffiness"
            ))
        }
        if cortisol >= 62 {
            flaws.append(AppCopy.tSync(
                "Charge cortisol élevée — tension et fatigue lisibles",
                en: "High cortisol load — readable tension and fatigue"
            ))
        }

        let weakQuality = metrics
            .filter { !$0.kind.higherIsWorse && $0.zone == .insufficient }
            .sorted { $0.percent < $1.percent }
        let strongAdverse = metrics
            .filter { $0.kind.higherIsWorse && $0.zone == .insufficient }
            .sorted { $0.percent > $1.percent }

        for metric in strongAdverse.prefix(2) {
            flaws.append(flawPhrase(for: metric.kind, percent: metric.percent))
        }
        for metric in weakQuality.prefix(3) {
            flaws.append(flawPhrase(for: metric.kind, percent: metric.percent))
        }

        if flaws.isEmpty {
            flaws = [
                AppCopy.tSync(
                    "Léger déséquilibre de la jawline à surveiller",
                    en: "Slight jawline imbalance to watch"
                ),
                AppCopy.tSync(
                    "Définition maxillaire encore perfectible",
                    en: "Maxillary definition still improvable"
                )
            ]
        }

        return Array(flaws.prefix(4))
    }

    private static func strengths(
        from metrics: [OnboardingFaceDeepAnalysis.LockedMetric]
    ) -> [String] {
        let strongQuality = metrics
            .filter { !$0.kind.higherIsWorse && $0.zone == .optimal }
            .sorted { $0.percent > $1.percent }
        let calmAdverse = metrics
            .filter { $0.kind.higherIsWorse && $0.zone == .optimal }
            .sorted { $0.percent < $1.percent }

        var items: [String] = []
        for metric in strongQuality.prefix(3) {
            items.append(strengthPhrase(for: metric.kind, percent: metric.percent))
        }
        for metric in calmAdverse.prefix(2) {
            items.append(strengthPhrase(for: metric.kind, percent: metric.percent))
        }

        if items.isEmpty {
            items = [
                AppCopy.tSync(
                    "Structure osseuse globalement cohérente",
                    en: "Overall coherent bone structure"
                ),
                AppCopy.tSync(
                    "Symétrie dans une fourchette exploitable",
                    en: "Symmetry in a workable range"
                )
            ]
        }
        return Array(items.prefix(4))
    }

    private static func summaryText(
        retention: Int,
        cortisol: Int,
        flaws: [String],
        strengths: [String]
    ) -> String {
        let retentionBit: String = {
            switch retention {
            case ..<48: return AppCopy.tSync("peu de rétention visible", en: "little visible retention")
            case 48..<78: return AppCopy.tSync("une rétention modérée à traiter", en: "moderate retention to address")
            default: return AppCopy.tSync("une rétention marquée qui alourdit le visage", en: "marked retention that weighs down the face")
            }
        }()
        let cortisolBit: String = {
            switch cortisol {
            case ..<42: return AppCopy.tSync("une charge stress contenue", en: "contained stress load")
            case 42..<78: return AppCopy.tSync("une tension cortisol encore active", en: "still-active cortisol tension")
            default: return AppCopy.tSync("un cortisol clairement élevé", en: "clearly elevated cortisol")
            }
        }()

        let flawPrefix = AppCopy.tSync("Priorité", en: "Priority")
        let strengthPrefix = AppCopy.tSync("Atout", en: "Strength")
        let closing = AppCopy.tSync(
            "L’analyse structurelle complète détaille yeux, jawline, pommettes, maxillaire et harmonie.",
            en: "The full structural analysis covers eyes, jawline, cheekbones, maxilla, and harmony."
        )

        let flawHint = flaws.first.map { "\(flawPrefix) : \($0.prefix(1).lowercased() + $0.dropFirst())." } ?? ""
        let strengthHint = strengths.first.map { "\(strengthPrefix) : \($0.prefix(1).lowercased() + $0.dropFirst())." } ?? ""

        return "\(retentionBit.prefix(1).uppercased() + retentionBit.dropFirst()), \(cortisolBit). \(flawHint) \(strengthHint) \(closing)"
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func flawPhrase(for kind: OnboardingFaceDeepAnalysis.Kind, percent: Int) -> String {
        switch kind {
        case .eyes: return AppCopy.tSync("Regard moins ouvert — fatigue oculaire détectée", en: "Less open gaze — eye fatigue detected")
        case .midFace: return AppCopy.tSync("Milieu du visage alourdi / moins sculpté", en: "Mid-face heavier / less sculpted")
        case .lowerThird: return AppCopy.tSync("Jawline peu définie", en: "Softly defined jawline")
        case .upperThird: return AppCopy.tSync("Jawline en retrait de fraîcheur", en: "Upper third lacking freshness")
        case .orbitalDepth: return AppCopy.tSync("Cernes peu contrastés", en: "Under-eyes lacking contrast")
        case .underEyeHealth: return AppCopy.tSync("Santé sous les yeux fragilisée", en: "Fragile under-eye health")
        case .nasolabialFold: return AppCopy.tSync("Ligne nasogénienne plus marquée", en: "Deeper nasolabial fold")
        case .cheekbones: return AppCopy.tSync("Projection des pommettes limitée", en: "Limited cheekbone projection")
        case .maxillary: return AppCopy.tSync("Soutien maxillaire à renforcer", en: "Maxillary support to strengthen")
        case .nose: return AppCopy.tSync("Équilibre nasal légèrement décalé", en: "Slightly off nasal balance")
        case .skin: return AppCopy.tSync("Clarté de peau en dessous du potentiel", en: "Skin clarity below potential")
        case .harmony: return AppCopy.tSync("Harmonie globale encore irrégulière", en: "Overall harmony still uneven")
        case .symmetry: return AppCopy.tSync("Asymétrie visible sur certains axes", en: "Visible asymmetry on some axes")
        case .neckWidth: return AppCopy.tSync("Transition cou / mâchoire à affiner", en: "Neck–jaw transition to refine")
        case .boneMass: return AppCopy.tSync("Lecture osseuse peu marquée (\(percent)%)", en: "Soft bone reading (\(percent)%)")
        }
    }

    private static func strengthPhrase(for kind: OnboardingFaceDeepAnalysis.Kind, percent: Int) -> String {
        switch kind {
        case .eyes: return AppCopy.tSync("Yeux expressifs et bien ancrés", en: "Expressive, well-anchored eyes")
        case .midFace: return AppCopy.tSync("Milieu du visage équilibré", en: "Balanced mid-face")
        case .lowerThird: return AppCopy.tSync("Bonne définition de la jawline", en: "Good jawline definition")
        case .upperThird: return AppCopy.tSync("Jawline claire et aérée", en: "Clear, open upper third")
        case .orbitalDepth: return AppCopy.tSync("Cernes discrets", en: "Subtle under-eyes")
        case .underEyeHealth: return AppCopy.tSync("Zone sous les yeux relativement saine", en: "Relatively healthy under-eye area")
        case .nasolabialFold: return AppCopy.tSync("Ligne nasogénienne discrète", en: "Subtle nasolabial fold")
        case .cheekbones: return AppCopy.tSync("Pommettes bien projetées", en: "Well-projected cheekbones")
        case .maxillary: return AppCopy.tSync("Soutien maxillaire solide", en: "Solid maxillary support")
        case .nose: return AppCopy.tSync("Nez harmonieux dans le cadre facial", en: "Nose harmonious in the facial frame")
        case .skin: return AppCopy.tSync("Peau globalement claire", en: "Generally clear skin")
        case .harmony: return AppCopy.tSync("Bonne cohérence des proportions", en: "Good proportion coherence")
        case .symmetry: return AppCopy.tSync("Symétrie faciale favorable", en: "Favorable facial symmetry")
        case .neckWidth: return AppCopy.tSync("Largeur de cou proportionnée", en: "Proportionate neck width")
        case .boneMass: return AppCopy.tSync("Structure osseuse lisible (\(percent)%)", en: "Readable bone structure (\(percent)%)")
        }
    }

    // MARK: - Seed

    private static func stableSeed(from id: String) -> UInt64 {
        var hash: UInt64 = 1469598103934665603
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return hash
    }

    private static func seededJitter(kind: OnboardingFaceDeepAnalysis.Kind, seed: UInt64) -> Double {
        var value = seed
            &+ UInt64(kind.rawValue.utf8.reduce(0) { $0 &+ UInt64($1) })
        value = value &* 6364136223846793005 &+ 1
        let unit = Double(value % 1000) / 1000.0
        return (unit - 0.5) * 10
    }
}
