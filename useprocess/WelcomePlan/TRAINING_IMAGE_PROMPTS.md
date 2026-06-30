# Training image prompts — assets Process

Colle **STYLE LOCK** + **SCENE** dans ChatGPT Image 2 pour chaque fichier manquant.
Dépose le PNG dans `Assets.xcassets/Training/.../<nom>.imageset/<nom>.png` et mets `"filename": "<nom>.png"` dans `Contents.json`.

**Arborescence :**
```
Assets.xcassets/Training/
├── Exercises/       exercise_*
├── Cardio/          cardio_*
├── Posture/         posture_*
├── Mobility/        mobilite_*
├── Routines/        routine*
└── training_see_all.imageset   ← carte « Voir tout »
```

---

## Inventaire (état actuel)

### ✅ Déjà intégrés — ne pas regénérer

| Dossier | Assets |
|---|---|
| **Exercises/** | `exercise_developpe_halteres`, `exercise_elevations_laterales`, `exercise_face_pulls`, `exercise_shrugs`, `exercise_tractions_tirage`, `exercise_rowing`, `exercise_curl_marteau`, `exercise_squat`, `exercise_romanian_deadlift`, `exercise_hip_thrust`, `exercise_mollets` |
| **Cardio/** | `cardio_marche`, `cardio_velo`, `cardio_tapis_incline`, `cardio_tapis_course`, `cardio_course_pied`, `cardio_rameur`, `cardio_elliptique`, `cardio_escalier`, `cardio_natation`, `cardio_corde`, `cardio_hiit`, `cardio_velo_route`, `cardio_randonnee` |
| **Mobility/** | `mobilite_epaules_hanches` |
| **Posture/** | `posture_chin_tuck`, `posture_neck_curls`, `posture_neck_extension_prone`, `posture_wall_retraction`, `posture_wall_angels`, `posture_glute_bridge`, `posture_hip_flexor_stretch`, `posture_foot_release`, `posture_clamshell`, `posture_thoracic_opener`, `posture_cat_cow`, **`posture_breathing` (F)** |
| **Routines/** | `routinesoleil`, `routineau`, `routinemewing`, `routineposture`, `routinedormir` |
| **Racine Training/** | `training_see_all` (carte « Voir tout ») |

> Note : les 11 `exercise_*` et `mobilite_epaules_hanches` sont encore en carré 1254×1254 — OK pour l’app, refaire en 9:16 seulement si tu veux homogénéiser visuellement.

### ❌ Manquant (1)

| Asset | Dossier | Modèle |
|---|---|---|
| `posture_jaw_breath` | `Training/Posture/` | **Femme (F)** |

---

## Format obligatoire — cartes Plan

Ratio **9:16** — **1024×1820** ou **1080×1920** px.

- Sujet dans le **haut / centre**
- **Bas ~40 %** sombre et propre → overlay titre dans l’app
- **Aucune UI** dans l’image (pas de bandeau, miniatures, bookmark, timer, badges)

**Negative prompt :**
```
app interface, UI overlay, top toolbar, thumbnail carousel, frosted glass bar, bookmark icon, timer badge, progress circle, mockup phone frame, green selection border, mini exercise cards at top
```

---

## STYLE LOCK POSTURE MAISON 9:16

```
STYLE LOCK POSTURE MAISON 9:16:
Premium 3D fitness app render, Process visual style (matte white skin, orange muscles, cyan edge glow).
Female anatomical figure (unless noted), smooth white matte skin, highly defined muscles.
Active muscles highlighted in bright saturated orange with glowing neon cyan/blue edge outline.
Dark charcoal studio (#1a1a1e), soft cinematic rim light.
HOME SETTING ONLY: yoga mat, plain wall, bed edge or pillow — NO gym machines, NO cables, NO barbells.
Black athletic wear with white "Process" on waistband or sports bra.
Vertical portrait 9:16, 1024x1820 pixels. Subject upper two-thirds, bottom 40% dark/clean for text overlay.
NO app UI in image. No text except Process on clothing. No watermark.
```

---

## Posture manquant

### `posture_jaw_breath` (F)

```
SCENE (F):
Female figure seated on mat or chair, slight forced exhale through mouth, one hand lightly under jaw — digastric / submandibular activation breath.
Submental area and jawline subtle orange highlight. Neutral home background, clinical not exaggerated.
Calm instructional mood — same Process 3D female model as posture_breathing.
```

Dépose : `Assets.xcassets/Training/Posture/posture_jaw_breath.imageset/posture_jaw_breath.png`
