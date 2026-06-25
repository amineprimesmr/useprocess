# Training image prompts — 20 assets Process

Colle **STYLE LOCK** + **SCENE** dans ChatGPT Image 2 pour chaque fichier.
Dépose le PNG dans `Assets.xcassets/<nom>.imageset/<nom>.png` et mets `"filename": "<nom>.png"` dans `Contents.json`.

---

## STYLE LOCK (identique pour heroes 941×1672)

```
STYLE LOCK:
Premium 3D fitness app render, same style as reference image (dossport).
Male anatomical figure, smooth white matte skin, highly defined muscles.
Active muscles highlighted in bright saturated orange with glowing neon cyan/blue edge outline.
Dark charcoal studio background (#1a1a1e), cinematic rim lighting, no white background.
Realistic gym equipment with accurate proportions.
Figure wears black athletic shorts with small white "Process" text on waistband.
Optional top UI: frosted glass morphism strip with 3 small muscle-view thumbnails, one selected with neon green border.
Vertical portrait composition 941x1672 pixels.
Leave bottom 40% relatively clean/dark for text overlay (headline + muscle tags).
Leave top 15% clean for bookmark icon and duration badge.
Ultra sharp, mobile app quality. No text except DENЄ on shorts. No watermark.
```

## STYLE LOCK (exercices / cardio / mobilité — 800×800)

```
STYLE LOCK:
Premium 3D fitness app render, same style as dossport reference.
Male figure, white matte skin, muscles active in orange with cyan edge glow.
Dark charcoal studio (#1a1a1e), realistic gym equipment.
Black Process shorts. Square 800x800, figure centered, single exercise focus.
No text except Process on shorts. No watermark.
```

---

## Heroes (6)

### 1. `dossport` — Pull (référence existante)

```
SCENE:
Male figure performing lat pulldown on cable machine, straight bar attachment.
Latissimus dorsi and mid-back highlighted bright orange with cyan edges.
Classic pull day hero shot.
```

### 2. `session_push`

```
SCENE:
Male figure performing incline dumbbell press on gym bench.
Chest and front deltoids highlighted orange with cyan glow.
Push day energy, bench and dumbbells visible.
```

### 3. `session_legs`

```
SCENE:
Male figure performing barbell back squat deep in squat rack.
Quadriceps, glutes and hamstrings highlighted orange.
Squat rack and plates visible.
```

### 4. `session_rest`

```
SCENE:
Calm recovery — male figure walking outdoors at golden hour OR gentle stretch on mat.
Soft green/blue muscle accents instead of aggressive orange.
Peaceful mood, no heavy lifting.
```

### 5. `session_posture`

```
SCENE:
Male figure at cable machine performing face pulls, rope at face level, elbows high.
Upper back, rear delts, rhomboids and neck alignment highlighted orange.
Posture correction energy — open chest, aligned head, not heavy pull day.
```

### 6. `session_cardio`

```
SCENE:
Male figure on gym cardio zone — stationary bike OR inclined treadmill walking.
Light cardio warmup mood, soft orange on legs and cardio, RPE 3-4 energy not sprint.
Treadmill incline or spin bike clearly visible.
```

---

## Exercices force (11)

### 7. `exercise_developpe_halteres`

```
SCENE:
Male figure dumbbell shoulder press or incline dumbbell press, arms extended.
Deltoids and upper chest orange highlight.
```

### 8. `exercise_elevations_laterales`

```
SCENE:
Male figure standing lateral dumbbell raise, arms at 90° abduction.
Side deltoids highlighted orange.
```

### 9. `exercise_face_pulls`

```
SCENE:
Male figure cable face pulls with rope, rear delts and upper back orange.
```

### 10. `exercise_shrugs`

```
SCENE:
Male figure holding heavy dumbbells, mid-shrug, trapezius orange highlighted.
```

### 11. `exercise_tractions_tirage`

```
SCENE:
Male figure pull-up on bar OR lat pulldown, lats fully engaged orange.
```

### 12. `exercise_rowing`

```
SCENE:
Male figure bent-over barbell row or seated cable row, mid-back orange.
```

### 13. `exercise_curl_marteau`

```
SCENE:
Male figure standing hammer curl, neutral grip dumbbells, biceps orange.
```

### 14. `exercise_squat`

```
SCENE:
Male figure barbell back squat or goblet squat, deep squat position, quads orange.
```

### 15. `exercise_romanian_deadlift`

```
SCENE:
Male figure Romanian deadlift, barbell at mid-shin, hamstrings and glutes orange.
```

### 16. `exercise_hip_thrust`

```
SCENE:
Male figure hip thrust on bench, glutes maximally highlighted orange.
```

### 17. `exercise_mollets`

```
SCENE:
Male figure standing calf raise on step, heels lifted, calves orange.
```

---

## Cardio / mobilité / posture (5)

### 18. `cardio_marche`

```
SCENE:
Male figure walking outdoors on path or slow treadmill walk, soft green/orange on legs.
Recovery pace, not sprint.
```

### 19. `cardio_velo`

```
SCENE:
Male figure on stationary spin bike, light resistance, easy warmup pace.
Gym cardio zone.
```

### 20. `cardio_tapis_incline`

```
SCENE:
Male figure walking on inclined treadmill, moderate incline, upright posture.
Gym treadmill visible.
```

### 21. `mobilite_epaules_hanches`

```
SCENE:
Male figure shoulder and hip mobility — arm circles or deep lunge stretch with band.
Shoulders and hips soft orange/green glow, mobility not max effort.
```

### 22. `posture_chin_tuck`

```
SCENE:
Male figure standing chin tuck / cervical retraction, neutral spine, chin drawn back.
Neck deep flexors and upper back alignment subtle orange highlight.
Clean instructional pose, gym background soft.
```

---

## Ordre de production

1. `session_posture`, `session_push`, `session_legs`, `session_rest`, `session_cardio`
2. `exercise_face_pulls`, `exercise_developpe_halteres`, `exercise_squat`, `posture_chin_tuck`
3. Reste des exercices + cardio/mobilité

