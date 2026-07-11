# Templates de formats

Chaque carrousel généré dans `queue/` suit un de ces formats.

---

## `ba` — Avant / Après (4–7 slides)

1. Hook (texte fort)
2. AVANT
3. APRÈS
4. Ce qu’il a changé (3 bullets)
5. Erreurs à éviter
6. Plan simple 3 étapes
7. CTA (Process / commente PLAN)

**Assets prioritaires :** `raw/before-after/` + éventuellement `app_*`

---

## `exp` — Explicatif (6–9 slides)

1. Hook problème
2. Mythe courant
3. Vraie cause #1
4. Vraie cause #2
5. Vraie cause #3
6. Ce que ça change concrètement
7. Action immédiate
8. CTA

**Assets :** faces bloated, meals, lifestyle, screenshots

---

## `top` — Top 5 (6–7 slides)

1. Hook “Top 5 …”
2. #5
3. #4
4. #3
5. #2
6. #1 (le plus fort)
7. CTA / récap

**Assets :** meals, lifestyle, faces, proofs

---

## `plan` — Plan étape par étape (7–10 slides)

1. Hook résultat
2. Étape 1
3. Étape 2
4. Étape 3
5. Étape 4
6. Étape 5
7. Erreur fatale
8. Résultat attendu
9. CTA

**Assets :** mix meals + lifestyle + app screenshots

---

## `myth` — Mythe vs réalité (5–7 slides)

1. Hook “On t’a menti”
2. Mythe
3. Réalité
4. Preuve / explication
5. Que faire à la place
6. CTA

---

## `check` — Checklist / routine (5–8 slides)

1. Hook “Fais ça demain matin”
2. Item 1
3. Item 2
4. Item 3
5. Item 4
6. Item 5
7. CTA save

---

## Fichier `meta.json` (dans chaque post queue)

```json
{
  "format": "ba",
  "lang": "fr",
  "hook": "Il a perdu le gonflé en 21 jours",
  "caption": "Pas magique. Juste un plan simple.\n\n1) Sel\n2) Sommeil\n3) Marche\n\nCommente PLAN",
  "hashtags": ["#debloat", "#visage", "#process", "#avantapres"],
  "cta": "Commente PLAN",
  "slides": [
    {"file": "slide_01.jpg", "text": "HOOK"},
    {"file": "slide_02.jpg", "text": "AVANT"},
    {"file": "slide_03.jpg", "text": "APRÈS"}
  ],
  "sources": ["raw/before-after/ba_01_before.jpg", "raw/before-after/ba_01_after.jpg"],
  "post_at": "2026-07-10T12:00:00+02:00",
  "status": "ready"
}
```
