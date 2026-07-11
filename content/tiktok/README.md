# Process — TikTok Carousel System (gratuit)

Système local pour produire des carrousels TikTok en illimité.

**Stack gratuite :**
1. Tu drops les images dans `raw/`
2. Je génère slides + titres + captions dans `queue/`
3. Tu postes (manuel CapCut/TikTok, ou plus tard auto)

---

## Workflow (30 secondes)

1. Ajoute tes images dans le bon dossier `raw/...`
2. Respecte le **naming** (voir `NAMING.md`)
3. Dis-moi : `génère 7 carrousels pour demain`
4. Je remplis `queue/YYYY-MM-DD_XX_format/`
5. Tu ouvres chaque dossier → poste sur TikTok Photo Mode
6. Une fois posté, déplace le dossier vers `posted/`

---

## Dossiers

### Imran (le plus important pour toi)

| Dossier | Quoi mettre |
|---|---|
| `raw/imran-normal/` | Photos **normales** d’Imran (avant / gonflé / réel) |
| `raw/imran-prime/` | Photos **Imran Prime** (après / transformé / IA) |

### Autres assets

| Dossier | Rôle |
|---|---|
| `raw/before-after/` | Autres paires avant/après (clients, etc.) |
| `raw/faces/` | Autres visages |
| `raw/meals/` | Repas, assiettes, hydratation |
| `raw/lifestyle/` | Gym, sommeil, routine |
| `raw/screenshots-app/` | Screens Process |
| `raw/proofs/` | Preuves / résultats |
| `raw/misc/` | Secours |
| `branded/` | Logo |
| `queue/` | Posts prêts |
| `posted/` | Déjà publiés |

---

## Pinterest → images auto

Pour remplir `raw/meals`, `raw/lifestyle`, etc. depuis Pinterest :

```bash
# Toutes les sources du fichier pinterest_sources.yaml
python3 content/tiktok/scripts/fetch_pinterest.py

# Uniquement un dossier
python3 content/tiktok/scripts/fetch_pinterest.py --only meals

# Recherche one-shot
python3 content/tiktok/scripts/fetch_pinterest.py --query "protein bowl" --folder meals --limit 20

# Board Pinterest
python3 content/tiktok/scripts/fetch_pinterest.py --board "https://www.pinterest.com/USER/BOARD/" --folder lifestyle
```

Édite `pinterest_sources.yaml` pour ajouter tes recherches / boards.

**Note droits :** utilise les images pour du contenu original (texte/overlays). Évite de republier des photos brandées telles quelles si tu n’as pas les droits.

---

## Règles contenu (v3)

- **1 carrousel = 1 thème** (pas de mélange)
- Texte style TikTok natif : **blanc + contour noir** (pas de boîtes blanches)
- Layouts variés : hook plein cadre, split AVANT/APRÈS, grille 2×2, tips denses, CTA
- Caption = **full valeur** (protocole applicable, pas juste un hook)
- Process AI = soft reco (`cherche Process AI`), jamais “notre app”

## Formats (rotation 4–7/jour)

| Code | Format | Layout typique |
|---|---|---|
| `guide` | 1 thème protocole | hook + split + tips denses |
| `top` | Top 5 / classement | hook + grille + ranked slides |
| `vs` | Avant vs maintenant | hook + splits verticaux |
| `ba` | Avant / Après | split photo |
| `check` | Checklist | liste actionable |

Générer :
```bash
python3 content/tiktok/scripts/generate_carousels.py
```

---

## Planning type (5 posts/jour)

| Heure | Format |
|---|---|
| 09:00 | `top` |
| 12:00 | `ba` |
| 15:00 | `exp` |
| 18:00 | `plan` |
| 21:00 | `check` |

---

## CTA par défaut

- Caption : valeur d’abord, puis soft CTA
- CTA standard : `Commente PLAN` / `Lien en bio` / `Process dans l’App Store`
- Langue : **FR**

---

## Règles assets

- JPG/PNG/WebP, idéalement vertical **1080×1920** (9:16)
- Avant/après : même angle, même lumière si possible
- Pas de texte déjà brûlé sur l’image (je l’ajoute sur les slides)
- Droits : uniquement des images que tu as le droit d’utiliser
