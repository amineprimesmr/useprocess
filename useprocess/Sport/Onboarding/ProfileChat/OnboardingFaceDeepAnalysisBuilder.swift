import Foundation

/// Synthèse déterministe de l'analyse bloating onboarding à partir des markers locaux.
enum OnboardingFaceDeepAnalysisBuilder {

    static func build(from result: FaceScanResult) -> OnboardingFaceDeepAnalysis {
        let markers = result.markers
        let seed = stableSeed(from: result.id)

        let retention = FaceScanIndicators.displayPercent(for: .retention, result: result)
        let cortisol = FaceScanIndicators.displayPercent(for: .stressLoad, result: result)
        let retentionZone = FaceScanIndicators.displayZone(for: .retention, result: result)
        let cortisolZone = FaceScanIndicators.displayZone(for: .stressLoad, result: result)

        let potential = potentialPercent(
            retention: retention,
            markers: markers,
            seed: seed
        )
        let potentialZone = FaceScanIndicators.wellnessZone(forPercent: potential)

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
            ),
            .init(
                kind: .definition,
                percent: potential,
                zone: potentialZone,
                phrase: potentialPhrase(for: potential),
                customTitle: AppCopy.tSync("POTENTIEL", en: "POTENTIAL"),
                customSystemImage: "chart.line.uptrend.xyaxis",
                customID: "potential",
                customHigherIsWorse: false
            )
        ]

        let lockedMetrics = OnboardingFaceDeepAnalysis.Kind.allCases.map { kind in
            let percent = score(for: kind, markers: markers, seed: seed)
            return OnboardingFaceDeepAnalysis.LockedMetric(
                kind: kind,
                percent: percent,
                zone: zone(forPercent: percent)
            )
        }

        let priorities = bloatPriorities(
            retention: retention,
            cortisol: cortisol
        )
        let triggers = bloatTriggers(
            markers: markers,
            retention: retention,
            seed: seed
        )
        let volumeComposition = facialVolumeComposition(
            from: result,
            retention: retention
        )

        return OnboardingFaceDeepAnalysis(
            unlocked: unlocked,
            volumeComposition: volumeComposition,
            lockedMetrics: lockedMetrics,
            priorities: priorities,
            triggers: triggers
        )
    }

    /// Potentiel de transformation — plus haut = mieux (rétention réversible + base structurelle).
    private static func potentialPercent(
        retention: Int,
        markers: FaceWellnessMarkers,
        seed: UInt64
    ) -> Int {
        let definition = FaceScanIndicators.definitionScore(from: markers)
        let symmetry = markers.facialSymmetryScore

        var value = 64.0
        value += Double(retention) * 0.16
        value += Double(definition) * 0.10
        value += Double(symmetry - 50) * 0.04
        value += Double(Int(seed % 5)) - 2.0

        return Int(min(96, max(70, value.rounded())))
    }

    private static func potentialPhrase(for percent: Int) -> String {
        switch percent {
        case 88...:
            return AppCopy.tSync(
                "Très fort potentiel avec ton plan",
                en: "Very high potential with your plan"
            )
        case 78..<88:
            return AppCopy.tSync(
                "Belle marge de transformation",
                en: "Strong room to transform"
            )
        default:
            return AppCopy.tSync(
                "Du potentiel clairement atteignable",
                en: "Clear, achievable potential"
            )
        }
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
                    "Bonne nouvelle : c’est surtout de la rétention — réversible avec ton plan, pas de la graisse.",
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

    // MARK: - Scores (charge de gonflement)

    private static func score(
        for kind: OnboardingFaceDeepAnalysis.Kind,
        markers: FaceWellnessMarkers,
        seed: UInt64
    ) -> Int {
        let jitter = seededJitter(kind: kind, seed: seed)
        let puffiness = Double(markers.puffinessScore)
        let underEye = Double(markers.underEyeFatigueScore)
        let jawTension = Double(markers.jawTensionScore)
        let softness = Double(100 - FaceScanIndicators.definitionScore(from: markers))

        let raw: Double
        switch kind {
        case .cheeks:
            raw = puffiness * 0.78 + softness * 0.14 + jitter
        case .underEyes:
            raw = underEye * 0.82 + puffiness * 0.12 + jitter
        case .jawline:
            raw = softness * 0.48 + puffiness * 0.32 + jawTension * 0.12 + jitter
        case .chin:
            raw = puffiness * 0.52 + softness * 0.38 + jitter
        case .neckLymph:
            raw = jawTension * 0.42 + puffiness * 0.38 + underEye * 0.12 + jitter
        }

        return Int(max(28, min(94, raw.rounded())))
    }

    private static func zone(forPercent percent: Int) -> FaceScanIndicators.WellnessZone {
        switch percent {
        case ..<48: return .optimal
        case 48..<78: return .sufficient
        default: return .insufficient
        }
    }

    // MARK: - Priorités debloat

    private static func bloatPriorities(
        retention: Int,
        cortisol: Int
    ) -> [OnboardingFaceDeepAnalysis.BloatPriority] {
        [
            .init(
                id: "volume",
                title: AppCopy.tSync("Volume liquide", en: "Fluid volume"),
                note: retentionNote(retention),
                systemImage: "drop.fill",
                hidesTitle: false
            ),
            .init(
                id: "underEyes",
                title: AppCopy.tSync("Sous les yeux", en: "Under-eyes"),
                note: AppCopy.tSync(
                    "Poches et fluide orbital : le drainage et le sommeil pèsent plus que la graisse.",
                    en: "Bags and orbital fluid: drainage and sleep weigh more than fat."
                ),
                systemImage: "eye.fill",
                hidesTitle: true
            ),
            .init(
                id: "cortisol",
                title: AppCopy.tSync("Inflammation stress", en: "Stress inflammation"),
                note: cortisolNote(cortisol),
                systemImage: "waveform.path.ecg",
                hidesTitle: true
            )
        ]
    }

    private static func bloatTriggers(
        markers: FaceWellnessMarkers,
        retention: Int,
        seed: UInt64
    ) -> [OnboardingFaceDeepAnalysis.BloatTrigger] {
        let saltLoad = Int(min(92, max(36, Double(markers.puffinessScore) * 0.62 + Double(retention) * 0.22 + seededJitter(kind: .cheeks, seed: seed))))
        let sleepLoad = Int(min(92, max(34, Double(markers.underEyeFatigueScore) * 0.78 + seededJitter(kind: .underEyes, seed: seed))))

        return [
            .init(
                id: "salt",
                title: AppCopy.tSync("Sel & eau", en: "Salt & water"),
                note: saltLoad >= 62
                    ? AppCopy.tSync(
                        "Le sodium retient l’eau dans les joues et le menton — c’est souvent le levier le plus rapide.",
                        en: "Sodium holds water in the cheeks and chin — often the fastest lever."
                    )
                    : AppCopy.tSync(
                        "Le sel joue encore, mais moins que le drainage et le sommeil sur ton scan.",
                        en: "Salt still plays a role, but less than drainage and sleep on your scan."
                    ),
                systemImage: "aqi.medium",
                hidesTitle: false
            ),
            .init(
                id: "sleep",
                title: AppCopy.tSync("Sommeil", en: "Sleep"),
                note: sleepLoad >= 62
                    ? AppCopy.tSync(
                        "Un sommeil court gonfle le visage au réveil — surtout sous les yeux et au milieu du visage.",
                        en: "Short sleep puffs the face on waking — especially under the eyes and mid-face."
                    )
                    : AppCopy.tSync(
                        "Le sommeil tient encore le visage — quelques nuits plus stables suffisent souvent.",
                        en: "Sleep still holds the face — a few more stable nights often help."
                    ),
                systemImage: "moon.zzz.fill",
                hidesTitle: false
            ),
            .init(
                id: "alcohol",
                title: AppCopy.tSync("Alcool", en: "Alcohol"),
                note: AppCopy.tSync(
                    "L’alcool bloque le drainage et gonfle le visage dès le lendemain matin.",
                    en: "Alcohol blocks drainage and puffs the face the next morning."
                ),
                systemImage: "wineglass.fill",
                hidesTitle: true
            ),
            .init(
                id: "lateMeal",
                title: AppCopy.tSync("Repas tardif", en: "Late meal"),
                note: AppCopy.tSync(
                    "Manger tard garde le liquide dans le visage toute la nuit.",
                    en: "Eating late keeps fluid in the face overnight."
                ),
                systemImage: "fork.knife",
                hidesTitle: true
            )
        ]
    }

    private static func retentionNote(_ retention: Int) -> String {
        switch retention {
        case ..<48:
            return AppCopy.tSync(
                "Peu de rétention globale — le plan affine surtout les zones encore gonflées.",
                en: "Little overall retention — the plan mainly refines the zones still puffy."
            )
        case 48..<78:
            return AppCopy.tSync(
                "Rétention modérée : le volume vient surtout de l’eau, pas de la graisse faciale.",
                en: "Moderate retention: the volume is mostly water, not facial fat."
            )
        default:
            return AppCopy.tSync(
                "Rétention marquée : c’est elle qui alourdit le visage, et elle part plus vite que la graisse.",
                en: "Marked retention: that’s what weighs the face down, and it clears faster than fat."
            )
        }
    }

    private static func cortisolNote(_ cortisol: Int) -> String {
        switch cortisol {
        case ..<42:
            return AppCopy.tSync(
                "Charge stress contenue — le gonflement vient surtout du liquide, pas de l’inflammation.",
                en: "Contained stress load — the puffiness is mostly fluid, not inflammation."
            )
        case 42..<78:
            return AppCopy.tSync(
                "Cortisol encore actif : il retient l’eau et gonfle les tissus en plus de la lymphe.",
                en: "Cortisol still active: it holds water and puffs tissue on top of lymph."
            )
        default:
            return AppCopy.tSync(
                "Cortisol élevé : inflammation et rétention se renforcent — le plan casse cette boucle.",
                en: "High cortisol: inflammation and retention feed each other — the plan breaks that loop."
            )
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
        return (unit - 0.5) * 8
    }
}
