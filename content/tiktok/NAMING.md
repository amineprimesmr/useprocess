# Naming — comment nommer tes images

Le nom du fichier = le contexte. Plus c’est clair, plus je peux générer sans te poser de questions.

## Règle générale

```text
{sujet}_{detail}_{contexte}.{ext}
```

Utilise :
- minuscules
- underscores `_`
- FR ou EN ok, mais **cohérent**
- dates optionnelles : `2026-07-09`

---

## 0) Imran — le plus simple

### Photos normales → `raw/imran-normal/`
```text
imran_normal_01.jpg
imran_normal_02_selfie.jpg
imran_normal_03_face.jpg
```

### Photos Imran Prime → `raw/imran-prime/`
```text
imran_prime_01.jpg
imran_prime_02_mirror.jpg
imran_prime_03_gym.jpg
```

Pas besoin de paires parfaites. Je mélange normal vs prime pour les avant/après.

---

## 1) Autres avant / après → `raw/before-after/`

**Obligatoire :** même `id` pour la paire.

```text
ba_01_before.jpg
ba_01_after.jpg

ba_02_m_face_before.jpg
ba_02_m_face_after.jpg

ba_03_f_21j_before.jpg
ba_03_f_21j_after.jpg
```

Codes utiles :
- `m` / `f` = homme / femme
- `face` / `body` / `jaw` / `belly`
- `7j` / `14j` / `21j` / `30j` = durée

Optionnel (encore mieux) : un petit fichier texte à côté :

```text
ba_01.txt
```

Contenu exemple :
```text
sexe: m
zone: face
duree: 21 jours
note: moins de sel + sommeil + marche
```

---

## 2) Visages → `raw/faces/`

```text
face_m_bloated_01.jpg
face_m_lean_01.jpg
face_f_side_profile_02.jpg
face_closeup_jaw_03.jpg
```

---

## 3) Repas → `raw/meals/`

```text
meal_debloat_salmon_salad.jpg
meal_breakfast_eggs.jpg
meal_hydration_water_lemon.jpg
meal_bad_example_fastfood.jpg
```

---

## 4) Lifestyle → `raw/lifestyle/`

```text
life_sleep_dark_room.jpg
life_walk_morning.jpg
life_gym_simple.jpg
life_stress_phone_bed.jpg
```

---

## 5) Screenshots app → `raw/screenshots-app/`

```text
app_plan_home.jpg
app_face_scan_result.jpg
app_coach_chat.jpg
app_meal_day.jpg
app_progress_streak.jpg
```

---

## 6) Preuves → `raw/proofs/`

```text
proof_weight_minus3kg.jpg
proof_face_score_up.jpg
proof_testimonial_01.jpg
```

---

## 7) Brand → `branded/`

```text
logo_process_white.png
logo_process_black.png
overlay_badge_21jours.png
```

---

## Ce que je déduis automatiquement

| Si je vois… | Je l’utilise pour… |
|---|---|
| `ba_*_before/after` | Carrousels avant/après |
| `face_*bloated*` | Slide “problème” |
| `face_*lean*` / after | Slide “résultat” |
| `meal_debloat_*` | Plans / top aliments |
| `app_*` | Preuve produit / CTA |
| `life_sleep_*` | Explicatifs sommeil |
| `proof_*` | Social proof |

---

## À éviter

- `IMG_4521.jpg` ← inutile
- `finalfinal2.jpg`
- Mettre before et after sans le même id
- Mélanger tout dans `misc/` (ok en secours seulement)
