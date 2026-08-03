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
                return "Peu de graisse — surtout de la rétention"
            }
            if bloatedPercent >= 90 {
                return "Volume surtout dû à la rétention, pas à la graisse"
            }
            return "La rétention pèse plus que la graisse faciale"
        }()

        let goodNewsPhrase: String = {
            if bloatedPercent >= 90 {
                return "Bonne nouvelle : c’est surtout de la rétention — donc réversible avec ton plan, pas de la graisse."
            }
            return "Bonne nouvelle : ton volume facial se corrige — la rétention part plus vite que la graisse."
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
            flaws.append("Rétention faciale marquée — volume et gonflement visibles")
        }
        if cortisol >= 62 {
            flaws.append("Charge cortisol élevée — tension et fatigue lisibles")
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
                "Léger déséquilibre de la jawline à surveiller",
                "Définition maxillaire encore perfectible"
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
                "Structure osseuse globalement cohérente",
                "Symétrie dans une fourchette exploitable"
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
            case ..<48: return "peu de rétention visible"
            case 48..<78: return "une rétention modérée à traiter"
            default: return "une rétention marquée qui alourdit le visage"
            }
        }()
        let cortisolBit: String = {
            switch cortisol {
            case ..<42: return "une charge stress contenue"
            case 42..<78: return "une tension cortisol encore active"
            default: return "un cortisol clairement élevé"
            }
        }()

        let flawHint = flaws.first.map { "Priorité : \($0.prefix(1).lowercased() + $0.dropFirst())." } ?? ""
        let strengthHint = strengths.first.map { "Atout : \($0.prefix(1).lowercased() + $0.dropFirst())." } ?? ""

        return "\(retentionBit.prefix(1).uppercased() + retentionBit.dropFirst()), \(cortisolBit). \(flawHint) \(strengthHint) L’analyse structurelle complète détaille yeux, jawline, pommettes, maxillaire et harmonie."
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func flawPhrase(for kind: OnboardingFaceDeepAnalysis.Kind, percent: Int) -> String {
        switch kind {
        case .eyes: return "Regard moins ouvert — fatigue oculaire détectée"
        case .midFace: return "Milieu du visage alourdi / moins sculpté"
        case .lowerThird: return "Jawline peu définie"
        case .upperThird: return "Jawline en retrait de fraîcheur"
        case .orbitalDepth: return "Cernes peu contrastés"
        case .underEyeHealth: return "Santé sous les yeux fragilisée"
        case .nasolabialFold: return "Ligne nasogénienne plus marquée"
        case .cheekbones: return "Projection des pommettes limitée"
        case .maxillary: return "Soutien maxillaire à renforcer"
        case .nose: return "Équilibre nasal légèrement décalé"
        case .skin: return "Clarté de peau en dessous du potentiel"
        case .harmony: return "Harmonie globale encore irrégulière"
        case .symmetry: return "Asymétrie visible sur certains axes"
        case .neckWidth: return "Transition cou / mâchoire à affiner"
        case .boneMass: return "Lecture osseuse peu marquée (\(percent)%)"
        }
    }

    private static func strengthPhrase(for kind: OnboardingFaceDeepAnalysis.Kind, percent: Int) -> String {
        switch kind {
        case .eyes: return "Yeux expressifs et bien ancrés"
        case .midFace: return "Milieu du visage équilibré"
        case .lowerThird: return "Bonne définition de la jawline"
        case .upperThird: return "Jawline claire et aérée"
        case .orbitalDepth: return "Cernes discrets"
        case .underEyeHealth: return "Zone sous les yeux relativement saine"
        case .nasolabialFold: return "Ligne nasogénienne discrète"
        case .cheekbones: return "Pommettes bien projetées"
        case .maxillary: return "Soutien maxillaire solide"
        case .nose: return "Nez harmonieux dans le cadre facial"
        case .skin: return "Peau globalement claire"
        case .harmony: return "Bonne cohérence des proportions"
        case .symmetry: return "Symétrie faciale favorable"
        case .neckWidth: return "Largeur de cou proportionnée"
        case .boneMass: return "Structure osseuse lisible (\(percent)%)"
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
