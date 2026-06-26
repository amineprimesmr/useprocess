# Meal image prompts — 17 assets Process (catalogue debloat)

Colle **STYLE LOCK** + **SCENE** dans ChatGPT Image / Midjourney / Grok pour chaque repas.

**Export** : PNG **900×900**, **fond transparent** (alpha), pas de JPEG.
Dépose dans `useprocess/Assets.xcassets/<nom>.imageset/<nom>.png`.

Repas définis dans `ProcessDebloatMealLibrary.swift` — rotation par jour (petit-déj ×3, déj ×6, dîner ×4, OMAD ×2, snack ×2).

**Règles catalogue** : zéro porc, zéro alcool — jamais dans les repas suggérés.

---

## STYLE LOCK (identique pour les 17 repas)

```
STYLE LOCK:
Premium 3D health-app meal asset, same visual series for all 17 images.
STRICT overhead top-down view (90° bird's eye), camera directly above the plate — NOT 45°, NOT side angle.
Single round plate or bowl centered in frame, seen from above like a food delivery app hero asset.
3D rendered food with realistic depth: ingredients have volume, height, and texture — not flat 2D illustration.
Soft studio lighting from above-left, subtle specular highlights on proteins, gentle shadows inside the plate.
Clean white or light cream ceramic plate/bowl with slight 3D rim visible from top view.
Appetizing grilled/roasted/sautéed debloat food — golden sear on meats, vibrant salad greens, colorful vegetables.
Debloat aesthetic: clean portions, no greasy pools, no creamy sauces, no fast-food look.
IMPORTANT: fully transparent background (PNG alpha channel). No table, no kitchen, no gradient backdrop, no surface under plate.
Optional soft drop shadow directly under the plate rim only (very subtle) to suggest floating 3D asset — shadow must not fill the frame.
Square 900x900 pixels. Plate occupies ~65-72% of frame width, centered.
No text, no logo, no watermark, no hands, no cutlery, no drinks in background (except snack scenes where glass is part of composition).
Ultra sharp mobile app quality. Isolated meal sticker / floating asset style.
```

### Astuce génération (ChatGPT / Grok)

Ajoute si besoin : *« transparent background, PNG cutout, isolated on alpha, top view food photography 3D »*

---

## Petit-déjeuner (3)

### 1. `meal_debloat_eggs_banana_kiwi` — Œufs Banane Kiwi

```
SCENE:
Overhead white plate — fluffy golden scrambled eggs center-left,
banana slices and kiwi rounds arranged beside eggs, colorful fruit pattern from above.
3D egg texture, fruit fresh. Transparent PNG, floating asset.
```

### 2. `meal_debloat_eggs_avocado` — Œufs Avocat Citron

```
SCENE:
Overhead plate — scrambled eggs golden mound, half avocado sliced in fan shape,
thin lemon slice for color. Pepper flecks on eggs. No bread. 3D volume, transparent background.
```

### 3. `meal_debloat_eggs_tomato_salad` — Œufs Tomates Salade Roquette

```
SCENE:
Overhead plate — two pan-seared eggs with golden edges, cherry tomatoes halved around eggs,
arugula and cucumber ribbons on one side, lemon oil gloss visible from top.
Savory breakfast layout, 3D ingredients, PNG transparent.
```

---

## Déjeuner (6)

### 4. `meal_debloat_chicken_sweet_potato` — Poulet Patate Douce Brocoli

```
SCENE:
Overhead plate — sliced grilled chicken breast with sear marks (center),
orange roasted sweet potato cubes and green broccoli florets arranged in sections.
Herbs scattered. Hearty lunch from above, 3D food render, transparent PNG.
```

### 5. `meal_debloat_chicken_avocado_salad` — Salade Poulet Avocat Composée

```
SCENE:
Overhead wide plate or shallow bowl — grilled chicken strips on top of green salad:
arugula, cherry tomatoes, cucumber coins, avocado half fan. Lemon sheen on leaves.
Fresh salad meal from above, vibrant greens, 3D depth, transparent background.
```

### 6. `meal_debloat_salmon_quinoa_salad` — Saumon Quinoa Salade Concombre

```
SCENE:
Overhead plate — salmon fillet golden skin top-right, fluffy quinoa mound,
cucumber mint salad section with lemon wedge. Colorful lunch layout from above.
3D fish texture, transparent PNG asset.
```

### 7. `meal_debloat_turkey_potato_salad` — Dinde Pommes Salade Verte

```
SCENE:
Overhead plate — sliced turkey escalope golden, roasted potato wedges with thyme,
green salad section with avocado slices. Balanced thirds layout from bird's eye view.
3D render, transparent background.
```

### 8. `meal_debloat_beef_rice_peppers` — Bœuf Haché Riz Poivrons

```
SCENE:
Overhead plate — browned ground beef section, basmati rice fluffy white mound,
roasted red and yellow bell pepper strips with onions. No sauce pool.
Savory 3D lunch asset, PNG transparent.
```

### 9. `meal_debloat_white_fish_green_salad` — Lieu Noir Haricots Salade Fenouil

```
SCENE:
Overhead plate — white fish fillet golden lemon sear, green beans aligned,
shaved fennel and cucumber salad section. Light fish lunch from above.
Clean 3D render, transparent PNG.
```

---

## Dîner (4)

### 10. `meal_debloat_steak_salad_potato` — Steak Salade Roquette Pommes

```
SCENE:
Overhead plate — grilled steak slices with grill marks, small roasted potato pieces,
arugula and cherry tomato salad section. Evening dinner layout from top.
3D meat texture, transparent background.
```

### 11. `meal_debloat_chicken_salad_bowl` — Poulet Rôti Salade Avocat

```
SCENE:
Overhead large shallow bowl — roasted chicken breast sliced in strips,
mixed salad roquette cucumber, avocado half, cherry tomatoes scattered.
Salad-forward dinner from bird's eye, 3D depth, PNG transparent.
```

### 12. `meal_debloat_turkey_broccoli_rice` — Dinde Brocoli Riz Basmati

```
SCENE:
Overhead plate — turkey escalope golden center, broccoli florets green section,
basmati rice white fluffy section. Warm dinner thirds layout from above.
3D food asset, transparent background.
```

### 13. `meal_debloat_cod_carrot_salad` — Cabillaud Carottes Salade Mâche

```
SCENE:
Overhead plate — white cod fillet golden roasted, orange roasted carrot sticks,
small mâche salad with cucumber. Color contrast from top view.
3D render, transparent PNG.
```

---

## OMAD (2)

### 14. `meal_debloat_omad_steak_sweet_potato` — Assiette OMAD Steak Patate Avocat

```
SCENE:
Overhead large plate OMAD — thick steak slice, big roasted sweet potato chunks,
avocado half, arugula cucumber salad section. Generous full plate from above, dense meal.
3D portions look substantial but clean, transparent PNG.
```

### 15. `meal_debloat_omad_chicken_quinoa_bowl` — Bowl OMAD Poulet Quinoa Salade

```
SCENE:
Overhead deep bowl — grilled chicken strips, quinoa base visible,
mixed salad roquette tomato cucumber, avocado slices on top. Bowl OMAD from bird's eye.
Healthy bowl 3D asset, transparent background.
```

---

## Snack (2)

### 16. `meal_debloat_coconut_banana` — Eau de Coco Banane

```
SCENE:
Overhead snack layout on small round plate or grouped composition —
tall glass coconut water center, banana beside, small yogurt dollop in mini bowl.
All items arranged for top-down view, 3D glass and fruit, transparent PNG.
No table surface visible.
```

### 17. `meal_debloat_pineapple_turkey_snack` — Ananas Jambon de Dinde

```
SCENE:
Overhead small plate — pineapple chunks golden arranged, folded turkey slices pink,
cucumber rounds on side. Tropical snack from above, fresh colors, 3D render.
Transparent PNG, isolated asset.
```

---

## Checklist déploiement

1. Générer **17 PNG 900×900** avec **fond transparent**
2. Vérifier dans Preview / Photoshop : fond alpha (damier), pas de fond gris/blanc baked-in
3. Déposer dans `Assets.xcassets/<nom>.imageset/<nom>.png`
4. `Contents.json` → `"filename": "<nom>.png"`
5. Rebuild — carousel nutrition affiche l’asset via `ProcessAssetCatalog`

## Assets existants

- `meal_debloat_chicken_sweet_potato.png` — **à regénérer** (vue de haut + transparent + brocoli)
- `epinardomelette.png` — legacy, hors catalogue actuel

## Alias images (fallback si ancien nom)

- `meal_debloat_salmon_rice_zucchini` → `meal_debloat_salmon_quinoa_salad`
- `meal_debloat_beef_sweet_potato_zucchini` → `meal_debloat_beef_rice_peppers`
- `meal_debloat_steak_potato_zucchini` → `meal_debloat_steak_salad_potato`
- `meal_debloat_chicken_carrot_potato` → `meal_debloat_chicken_salad_bowl`
- `meal_debloat_turkey_rice_zucchini` → `meal_debloat_turkey_broccoli_rice`
- `meal_debloat_turkey_potato_spinach` → `meal_debloat_turkey_potato_salad`
