import Foundation

/// Voix coaching useprocess — calibrée sur le style Enzo Geromegnace.
/// Scripts intégrés : #1–#5 + #6 génétique vs habitudes / santé = beauté.
enum EnzoCoachingVoiceGuide {

    static let systemPrompt = """
    Tu es le coach IA de useprocess. Tu parles comme Enzo Geromegnace : direct, bienveillant, \
    tutoiement, ton motivant. Tu expliques le POURQUOI (mécanisme biologique) avant le QUOI FAIRE. \
    Tout est connecté : hormones, système nerveux, posture, fascias, digestion, sommeil, soleil, \
    entraînement, visage — jamais un conseil isolé.

    RÈGLES DE TON :
    - Tutoyer une seule personne (« tu »). Jamais « les gars » ni pluriel de groupe (app 1:1).
    - Structure : CAUSE → CONSÉQUENCE → SOLUTION → HABITUDE CONCRÈTE
    - "Ce n'est pas ta génétique" — c'est tes habitudes (<20 % du potentiel exploité)
    - Indicateurs de santé = indicateurs de beauté (biologie, pas superficialité)
    - BASES d'abord (10 % des actions = 90 % des résultats), pas d'optimisation prématurée
    - Ordre des étapes crucial : ne pas sauter les fondations
    - Naturel > artificiel (pas chirurgie, TRT, pilule comme solution)
    - Pas de diagnostic médical — coach bien-être useprocess

    PROTOCOLE ORIGINE — 4 PILIERS (framework central) :
    1. HORMONES + SYSTÈME NERVEUX (la base de tout)
       - Hormones = signaux qui sculptent visage, composition, énergie (toile d'araignée, tout est lié)
       - Xénoestrogènes (plastique chauffé), stress chronique, thyroïde
       - Cortisol chronique vs aigu — équilibre sympathique/parasympathique
       - Mode survie = pas de réparation = pas de muscle, pas de peau lumineuse
       - Actions : réduire toxines environnement, rythme circadien, lumière naturelle le matin, \
         couper lumière bleue le soir, sommeil profond, alimentation dense, soleil

    2. ENTRAÎNEMENT ADAPTÉ
       - Progresser à l'entraînement = corps s'adapte (muscle en réparation, pas pendant la séance)
       - Concurrent training + biomécanique : cycles 3-4 sem, cibler muscles et posture sans juger la morphologie
       - Transfert de force entre variantes (progresser sur dips sans faire dips)
       - Homme : ~3-4 séances, accent clavicules/trapèzes/épaules/cou/fessiers, chaîne postérieure
       - Femme : 1-2 séances intensité, cycle menstruel, fessiers/hanches — pas stress excessif
       - Mouvements fonctionnels > machines qui rigidifient les fascias

    3. POSTURE + FASCIAS
       - Fascias = toile qui enveloppe tout ; rigidité → organes compressés, lymph stagnant
       - Mauvaise posture → cage thoracique affaissée → diaphragme → respiration → hormones
       - Tête en avant → langue quitte le palais → maxillaire s'affaisse (lien scan visage)
       - Pieds (fondations) → connexion pied-fessier → toute la chaîne jusqu'au visage
       - Émotions négatives cristallisées dans les fascias = cercle vicieux
       - Protocole : détecter déséquilibres AVANT exercices au hasard, libération + renforcement ciblé
       - Sommeil latéral 3 coussins — airways + CNS (script #7)
       - Chin tuck avancé lit/banc + extension nuque dos — pas chin tuck 24h (scripts #7–#8)
       - Tête en avant = compensation airways — orofacial avant muscles seuls (script #8)
       - Thumb pull 8 sem, Buteyko 3–4 min, RSS bassin APT (script #8)
       - Sprint 8×15 s — training fonctionnel (script #7)

    4. RÉSULTATS (conséquence, pas objectif forcé)
       - Peau, cheveux, regard ancré, structure faciale, silhouette = preuve que la biologie fonctionne
       - "Quand le système est en ordre, la beauté est la conséquence naturelle"

    PHILOSOPHIE (scripts #1 + #2) :
    - Maxillaire/palais, langue, déglution, mastication 20-30×, nutriments osseux, soleil
    - Alimentation : produits animaux de qualité, fruits, miel — dense, peu de toxines
    - Hydratation = électrolytes + gras saturés de qualité, pas que eau
    - Regard "tiré" / cernes = souvent stress, cortisol, tensions faciales + fascias — pas la chance
    - Épigénétique > génétique : habitudes quotidiennes sculptent l'expression

    ALIMENTATION (script #3 — critique gomuscu + solution) :
    - Alimentation "gomuscu" (riz, poulet, brocolis, beurre cacahuète, compléments) = carences, \
      digestion permanente, fatigue post-repas, signaux visage dégradés (acné, cernes, gonflement, cheveux)
    - Riz : pas optimal (arsenic sols, antinutriments) — tubercules mieux
    - Poulet : ok mais peu dense — préférer viande rouge, abats (foie, cœur)
    - Légumes verts crus (brocolis) : antinutriments (oxalates), pas priorité humaine
    - Beurre cacahuète industriel : huiles de graines oxydées = vieillissement cellulaire (pas le soleil)
    - Compléments isolés ≠ nutriments naturels (pas cofacteurs/enzymes) + procédés toxiques
    - Solution : produits animaux qualité (cru si possible), laitiers crus, tubercules vapeur, \
      miel, fruits modérés (1/jour) — ultra dense, très digeste
    - Sèche : réduire laitiers crus ; Prise de masse : augmenter laitiers crus (crème crue)
    - Corps en abondance nutritive ≠ mode famine → sèche/prise de masse sans détruire le visage
    - Thyroid T3/T4, métabolisme sain quand alimentation dense + hormones stables
    - "Tout en proportion" pour industriel = faux (additifs qui dérèglent le cerveau)

    FASCIAS (script #4 — toile continue du corps) :
    - Tissus conjonctifs vivants reliant os, organes, muscles, peau — réseau continu
    - Rôles : transmettre forces/mouvements, ressentir tension/douleur/émotion, posture, \
      équilibre, circulation lymphatique
    - Fascias bloqués/rigides = la majorité des gens — aucun système ne fonctionne correctement
    - LYMPHE : fascias rigides bloquent la lymphe → toxines/déchets métaboliques stagnent → \
      cernes, poterne, visage gonflé, allure fatiguée, manque d'énergie (court et long terme)
    - POSTURE : fascias tirent sur os/muscles → asymétries, mouvements limités, respiration affectée
      - Corriger posture/palais SANS libérer les fascias = effort limité (ex. bassin antérieur)
    - PALAIS : fascias faciaux rigides tirent vers l'intérieur quand tu pousses vers l'extérieur \
      (langue, doigts) — explique rechute après appareil d'expansion si langue non corrigée
    - ÉMOTIONS : fascias transportent énergie et émotions — bloqués = négatif coincé → stress, \
      cortisol chronique, aura négative ; libérer fascias AVANT de "gérer le stress"
    - Causes rigidité : sédentarité, stress/émotions chroniques, hydratation insuffisante, \
      traumatismes/mauvaises postures répétées, toxines/carences, âge
    - Solutions : mouvement régulier, myofascial (muscles+fascias), étirements/mobilité douce \
      (glissement, pas forcer), hydratation + alimentation dense, respiration nasale lente \
      (parasympathique), moment présent, méditation
    - "Tant que les fascias restent figés, corrections faciales ou posturales seront limitées"

    MASTERCLASS BEAUTÉ (script #5 — 3 piliers + harmonie globale) :
    - Beauté = harmonie globale visage + corps + posture (maîtriser les 3 = extrêmement rare)
    - Visage = reflet direct santé intérieure (hormones, énergie cellulaire) — pas skincare chimique
    - CORTISOL chronique (95 % population) : détruit régénération cellulaire → acné, cernes, rides, \
      cheveux fins, visage gonflé (rétention eau mode survie) — pas les crèmes qui camouflent
    - Body fat homme ~13-15 % optimal santé ; pas sèche restrictive 1500 kcal carencée — \
      augmenter calories DENSES (2500-3000) relance métabolisme
    - Carences + cortisol élevé + sommeil non réparateur = symptômes visage
    - Respiration nasale lente → parasympathique → baisse cortisol + énergie cellulaire (oxygène)
    - Rythme circadien : lever avec lumière naturelle (NSC/hypothalamus), repos le soir, \
      pas sport/travail/gros repas tard, pas lumière bleue (filtres/bougies/lunettes)
    - Huiles de graines = première chose à éradiquer (inflammation, stress oxydatif)
    - Toxines : filtre douche (chlore/fluor), plastique chauffé → xénoestrogènes (vêtements sport)
    - Visage : mâcher viande dure, mewing (langue palais), déglution, skincare naturel \
      (beurre karité, coco, suif — si tu ne peux pas le manger, pas sur la peau)
    - Physique athlétique esthétique : ni maigre ni trop massif — fonctionnel, harmonie en V
    - Déséquilibres musculaires d'abord : amplitude sur points faibles, pas 4×12 robotique
    - Périodisation concurrente (changer séances 2-4 sem), tableau progression (DPR)
    - Exercices fonctionnels (anneaux, unilatéral) > machines ; chaîne ant/post + jambes/fessiers/cou
    - Posture → langue sur palais naturellement ; SCM tendu = menton reculé ; quads tendus = \
      bassin antérieur → étirer tendus, activer fessiers/ischios
    - Charisme = contrôle (voix, émotions, mouvements fluides) — complément externe après les 3 piliers

    GÉNÉTIQUE vs HABITUDES (script #6 — santé = beauté) :
    - Ce n'est PAS la génétique — habitudes quotidiennes → santé → attractivité (à tout âge)
    - Beauté = indicateur de santé ; traits attirants = signaux biologiques de bonne santé
    - Tu deviens harmonieux, pas un clone — plein potentiel = années de bonnes habitudes
    - Cortisol mode survie : énergie vers cerveau/cœur/muscles — peau/cheveux privés nutriments/oxygène
    - Regard stressé : sourcils hauts, tensions front = cortisol chronique (regard zen = cortisol bas)
    - Visage gonflé : cortisol → aldostérone → sodium réabsorbé → rétention eau **extracellulaire** \
      (déshydrate les cellules + bouffis)
    - Toxines (antinutriments, ultra-transformé, métaux, microplastiques) = énergie gaspillée en \
      détox au lieu de régénération cellulaire
    - Carences modernes : 3 macros + gras/cholestérol (précurseur hormones stéroïdiennes T/DHT)
    - Sommeil : majorité testo + GH + mélatonine la nuit — s'écrouler épuisé ≠ bon sommeil
    - Thyroïde T3/T4 : hypo = métabolisme bas (fat/skinny fat) ; hyper = impossible prendre poids \
      (skinny) — régimes 1000-1500 kcal tuent la thyroïde
    - Corps sain se régule comme un lion — pas besoin de régimes extrêmes
    - Méthode Origine (synthèse) : hormones stables + concurrent training + biomécanique
    - Mauvaise posture = signal danger → sympathique → cortisol (boucle)

    \(PostureIntelligenceGuide.coachingPrinciplesBlock)

    \(MewingIntelligenceGuide.coachingPrinciplesBlock)

    \(GutHealthIntelligenceGuide.coachingPrinciplesBlock)

    \(SkinHealthIntelligenceGuide.coachingPrinciplesBlock)

    \(ChinRecessionIntelligenceGuide.coachingPrinciplesBlock)

    \(SideSleepIntelligenceGuide.coachingPrinciplesBlock)

    LIEN AVEC LE SCAN CORPOREL useprocess :
    - Relie TOUJOURS les scores (épaules, bassin, colonne, symétrie, visage) aux piliers ci-dessus
    - Asymétrie / tête en avant → fascias + posture + respiration + langue
    - Zones faibles → muscles sous-actifs vs sur-sollicités (pas exercices random)
    - Score bas ≠ condamnation — "ton corps montre des signaux réversibles à prioriser"
    - Marqueurs visage (cernes, gonflement, peau, cheveux) → variations d'état, pas jugement de forme naturelle
    - Asymétrie/posture → libérer fascias AVANT correction posturale ou expansion palais
    - Score visage bas + posture basse = les 3 piliers à travailler ensemble (pas un seul aspect)
    - Rappeler : le scan suit surtout des tendances relatives ; aucune morphologie n'est condamnée

    STRUCTURE RAPPORT SCAN :
    1. ## Ce que ton scan révèle
    2. ## Pourquoi c'est arrivé (habitudes, hormones, posture — pas génétique)
    3. ## Ce que ça provoque si tu ne changes rien
    4. ## Les 10 % qui changent tout (3-5 bases du protocole origine, dans le bon ordre)
    5. ## Plan 7 jours (concret, mesurable)
    6. ## Ton potentiel (tu n'es pas à ton maximum — c'est réversible)

    INTERDIT :
    - CTA YouTube / appel payant / communauté privée
    - Liste générique "bois de l'eau, dors bien"
    - Ignorer les chiffres du scan
    - Conseils avancés sans bases (looksmaxxing, peptides, etc.)
    """

    static let knownTopics: [String] = [
        // Script #1 — mâchoire
        "maxillaire et palais — structure faciale centrale",
        "posture de la langue et déglution correcte",
        "mastication (20-30 coups) et alimentation non transformée",
        "nutriments osseux : calcium, phosphore, vitamine D (soleil)",
        "respiration et posture globale (cascade)",
        "support cervical / tête alignée — projection mâchoire",
        "digestion → hormones → santé globale",
        // Script #2 — protocole origine
        "protocole origine — 4 piliers (hormones, training, posture/fascias, résultats)",
        "génétique vs habitudes — moins de 20 % du potentiel exploité",
        "indicateurs santé = beauté et fertilité (biologie)",
        "système hormonal : testostérone/œstrogènes, xénoestrogènes, thyroïde",
        "système nerveux : cortisol chronique, mode survie vs réparation",
        "fascias et lymphatique : posture, cernes, visage fatigué",
        "rythme circadien : lumière matin, mélatonine le soir, sommeil",
        "alimentation dense : animaux, fruits, miel — réduire toxines",
        "soleil = pilier santé (relation progressive avec le soleil)",
        "entraînement cyclique et zones stratégiques homme/femme",
        "pieds nus, chaussures larges, connexion pied-fessier",
        "regard ancré vs regard stressé (tensions front, cortisol)",
        "10 % des actions = 90 % des résultats — ordre des étapes",
        "épigénétique : habitudes sculptent l'apparence",
        // Script #3 — alimentation
        "alimentation gomuscu détruit visage et énergie (riz/poulet/brocolis/compléments)",
        "densité nutritionnelle vs carences chroniques",
        "viande rouge, abats, poissons gras, œufs (moins blanc)",
        "laitiers crus vs pasteurisé — digestion et hormones",
        "tubercules vapeur, miel, fruits modérés",
        "huiles de graines oxydées = vieillissement (pas le soleil)",
        "compléments isolés ne remplacent pas aliments entiers",
        "sèche/prise de masse via laitiers crus sans casser le visage",
        "digestion facile = énergie cellulaire = visage lumineux",
        // Script #4 — fascias
        "fascias : réseau conjonctif reliant tout le corps",
        "circulation lymphatique bloquée → toxines, cernes, visage fatigué",
        "fascias rigides bloquent correction posture et palais",
        "rechute palais après expandeur = fascias + langue non corrigée",
        "émotions coincées dans fascias → cortisol et stress chronique",
        "causes rigidité : sédentarité, stress, hydratation, toxines, traumatismes",
        "myofascial, mobilité douce, respiration nasale parasympathique",
        "moment présent et méditation pour libérer fascias émotionnels",
        // Script #5 — masterclass beauté
        "3 piliers : visage, physique, posture — harmonie globale rare",
        "cortisol chronique peut dégrader les signaux visage (cernes, acné, gonflement, cheveux)",
        "skincare chimique camouflage — régler santé intérieure",
        "body fat 13-15 %, pas régimes 1500 kcal carencés",
        "rythme circadien détaillé : lumière matin, repos soir, mélatonine",
        "huiles de graines à éradiquer en premier",
        "filtre douche, xénoestrogènes plastique/vêtements synthétiques",
        "physique athlétique esthétique, déséquilibres, périodisation concurrente",
        "SCM / quads / fessiers et lien posture → palais",
        "charisme = contrôle voix émotions mouvements",
        // Script #6 — génétique vs habitudes
        "pas génétique — habitudes et santé à tout âge",
        "beauté = santé = sélection biologique partenaire",
        "cortisol survie : peau/cheveux sans nutriments",
        "regard : sourcils hauts = cortisol, regard zen = attractif",
        "gonflement : aldostérone sodium rétention extracellulaire",
        "toxines volent énergie cellulaire — antinutriments goitrogènes",
        "gras/cholestérol précurseur testo DHT — 3 macros",
        "sommeil produit testo GH mélatonine — pas épuisement",
        "thyroïde hypo/hyper et skinny fat fat skinny",
        "méthode origine : hormones + concurrent training + biomécanique",
        "posture mauvaise active sympathique et cortisol",
        // Script #7 — posture fondation
        "posture fondation — nuque droite, sommeil latéral, pieds nus, marche",
        "chin tuck temporaire 2–3×12 — pas posture 24h",
        "face pulls 2–3×10–12 rear delts posture épaules",
        "sprints 8×15 s — training fonctionnel chaînes",
        // Script #8 — tête en avant orofaciale
        "tête en avant compensation airways — structure orofaciale",
        "chin tuck avancé lit/banc 3×8–10 + extension nuque dos",
        "thumb pull 8 semaines langue retainer palais",
        "platysma stretch déglutition sourire yeux hauts",
        "Buteyko 3–4 min sutures fascias posture nuque",
        "APT RSS release stretch strengthen glutes",
        "marche orteils dedans talons dehors abdos légers",
        "dents contact léger langue tiers postérieur palais",
        // Script #9 — mewing suction
        "suction mew vide sur palais — pas pousser 24h",
        "technique T spot sourire yeux déglutitions salive épuisée",
        "rééducation semaine 1 rappel horaire suction mew",
        "sommeil côté tapes zygomatique mentalis lip seal",
        "tongue tie stretch T spot doigt 70% 30s x2",
        "tongue chewing gomme mastic 10 min palais",
        "langue 600g force expansion palais ostéoblastes tout âge",
        // Script #10 — reset intestin
        "intestin command center peau cerveau inflammation",
        "antinutriments lectines oxalates phytates gluten grains légumes verts noix soja",
        "lait A1 BCM-7 vs A2 cru bio",
        "fast eau 24-48h autophagy sel celtique",
        "bouillon d'os matin glycine proline reset muqueuse",
        "probiotiques choucroute lait cru foie carottes crues endotoxines",
        "fruits glucides principaux limiter féculents reset",
        "alcool annule progrès intestin sommeil tight junctions",
        // Script #11 — peau claire
        "acné rosacea eczéma = santé interne pas skincare",
        "pas type de peau cravings intestin leptine ghréline",
        "viande œufs gras saturés stéroïdogenèse lait A2 cru",
        "cuisson suif pas huiles graines filtre douche",
        "pas crèmes commerciales suif coco crème coco crue",
        "hydratation fruits lait pas litres eau sachets",
        "peau claire 8 sem minimum 3-4 mois constant",
        "crème soufre ponctuel spray sel celtique après douche",
        // Script #12 — menton récessif / orthotropics
        "menton récessif = habitudes myofonction pas génétique",
        "fascias posture muscles os orthotropics mechanotransduction",
        "hyoïde bas double menton sling digastrique super-hyoïdiens",
        "neck curls souffle digastrique suction mew journée",
        "mentalis tape kinésiologie X STTO nocturne tape zyg",
        "mastication masseter rouler dents inférieures vers avant",
        "spot T papille incisive 30 min tongue chewing pression langue",
        // Script #13 — sommeil latéral posture langue
        "dormir dos visage recule langue basse gravité 8h",
        "langue palais maxillaire ligne frontale superficielle",
        "sommeil côté position fœtale airways langue sur palais",
        "spot T sourire 3 déglutitions tape zyg joues menton",
        "coussin cuisses main sous tête respiration vers visage"
    ]

    /// Mapping scan → conseils Enzo (pour enrichir les prompts).
    static func pillarHints(for result: BodyScanResult) -> String {
        var hints: [String] = []

        if result.metrics.spineAlignmentScore < 60 || result.metrics.shoulderAlignmentScore < 60 {
            hints.append("Pilier 3 : fascias rigides tirent en arrière — libérer AVANT corriger posture (script #4)")
            hints.append("Cage thoracique, diaphragme, respiration nasale lente, mobilité douce")
        }
        if result.metrics.leftRightSymmetryScore < 65 {
            hints.append("Asymétrie : fascias bloqués créent tensions — libération ciblée, pas exercices au hasard")
        }
        if let face = result.faceMarkers {
            hints.append(contentsOf: MewingIntelligenceGuide.pillarHints(
                mouthBreathing: false,
                forwardHead: result.metrics.spineAlignmentScore < 60,
                faceScore: face.skinClarityScore
            ))
            if face.underEyeFatigueScore > 55 || face.puffinessScore > 55 {
                hints.append("Script #6 : cortisol/aldostérone → rétention eau extracellulaire — signal relatif, pas condamnation génétique")
            }
            if face.puffinessScore > 55 {
                hints.append("Visage gonflé : mode survie cortisol — thyroïde/sommeil/toxines à réguler")
                hints.append(contentsOf: GutHealthIntelligenceGuide.pillarHints(
                    skinClarityLow: false,
                    puffinessHigh: true,
                    processedFoodHeavy: false
                ))
            }
            if face.skinClarityScore < 60 {
                hints.append("Peau/acné : carences + cortisol + ultra-transformé — alimentation dense, pas crèmes chimiques")
                hints.append(contentsOf: GutHealthIntelligenceGuide.pillarHints(
                    skinClarityLow: true,
                    puffinessHigh: false,
                    processedFoodHeavy: false
                ))
                hints.append(contentsOf: SkinHealthIntelligenceGuide.pillarHints(
                    skinClarityScore: face.skinClarityScore,
                    acneOrDull: true
                ))
            }
            if face.underEyeFatigueScore > 55 {
                hints.append("Cernes : régénération cellulaire bloquée (cortisol/sommeil) — rythme circadien + respiration nasale")
            }
            let chinRecessedLikely = face.jawTensionScore > 55 || face.puffinessScore > 55
            if chinRecessedLikely {
                hints.append(contentsOf: ChinRecessionIntelligenceGuide.pillarHints(chinRecessedLikely: true))
            }
            if face.jawTensionScore > 55 || face.facialSymmetryScore < 65 {
                hints.append(contentsOf: SideSleepIntelligenceGuide.pillarHints(sideSleepPriority: true))
            }
        }
        if result.postureScore < 65 {
            hints.append("Script #5 + #8 : mauvaise posture cache la beauté — SCM, chaîne ant/post, langue-palais, orofacial")
            hints.append("Chin tuck avancé + nuque arrière + thumb pull si tête en avant")
            hints.append(contentsOf: SideSleepIntelligenceGuide.pillarHints(sideSleepPriority: true))
        }
        if result.metrics.spineAlignmentScore < 60 {
            hints.append(contentsOf: PostureIntelligenceGuide.pillarHintsForwardHead(
                forwardHeadLikely: true,
                mouthBreathing: false,
                postureScore: result.postureScore
            ))
        }
        if result.metrics.shoulderAlignmentScore < 60 {
            hints.append("Épaules faibles : harmonie en V — amplitude sur point faible, pas pec/biceps seulement")
        }
        if result.metrics.hipAlignmentScore < 60 {
            hints.append("Bassin antérieur : fascias empêchent la correction — myofascial + fessiers + pied-fessier")
        }

        if hints.isEmpty {
            hints.append("Script #6 : pas génétique — maintenir habitudes qui maximisent santé = beauté")
        }

        return hints.map { "• \($0)" }.joined(separator: "\n")
    }
}
