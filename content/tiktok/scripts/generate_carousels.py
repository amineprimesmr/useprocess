#!/usr/bin/env python3
"""TikTok carousel generator v3 — native TikTok text style + varied layouts.

Rules:
- 1 carousel = 1 theme
- Text looks like TikTok Classic: white bold + black outline (NOT white boxes)
- Layouts vary: full hook, 2x2 grid, vertical split, tip slides, CTA
- Dense real value in slides + caption
- Process AI = soft reco only (never "notre app")
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "raw"
QUEUE = ROOT / "queue"
W, H = 1080, 1920

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_EMOJI = "/System/Library/Fonts/Apple Color Emoji.ttc"

PROCESS_SOFT = "Perso j'utilise Process AI pour suivre le plan (cherche Process AI sur l'App Store)"


def imgs(folder: str) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png", ".webp"}
    return sorted(p for p in (RAW / folder).iterdir() if p.suffix.lower() in exts)


NORMAL = imgs("imran-normal")
PRIME = imgs("imran-prime")
MEALS = imgs("meals")
LIFE = imgs("lifestyle")
FACES = imgs("faces")


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def emoji_fnt() -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_EMOJI, 160)


def is_emoji(ch: str) -> bool:
    o = ord(ch)
    return (
        0x1F300 <= o <= 0x1FAFF
        or 0x2600 <= o <= 0x27BF
        or 0x1F600 <= o <= 0x1F64F
        or 0x1F900 <= o <= 0x1F9FF
        or o in {0x200D, 0xFE0F, 0x20E3}
        or 0x1F3FB <= o <= 0x1F3FF
    )


def cover(path: Path, size=(W, H), bias=0.28) -> Image.Image:
    img = Image.open(path).convert("RGB")
    tw, th = size
    scale = max(tw / img.width, th / img.height)
    nw, nh = int(img.width * scale), int(img.height * scale)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = max(0, min(nh - th, int((nh - th) * bias)))
    return img.crop((left, top, left + tw, top + th))


def darken(img: Image.Image, f=0.72) -> Image.Image:
    return ImageEnhance.Brightness(img).enhance(f)


def measure(draw, text, fnt):
    b = draw.textbbox((0, 0), text, font=fnt)
    return b[2] - b[0], b[3] - b[1]


def split_runs(text: str):
    runs = []
    buf, mode = "", None
    for ch in text:
        em = is_emoji(ch)
        if ch in ("\u200d", "\ufe0f") and mode is True:
            buf += ch
            continue
        if mode is None:
            mode, buf = em, ch
        elif em == mode:
            buf += ch
        else:
            runs.append((buf, mode))
            buf, mode = ch, em
    if buf and mode is not None:
        runs.append((buf, mode))
    return runs


def line_width(draw, text, fnt, emoji_side: int) -> int:
    total = 0
    for run, em in split_runs(text):
        if em:
            n = max(1, len([c for c in run if ord(c) >= 0x2600 and c not in ("\u200d", "\ufe0f")]))
            total += (emoji_side + 4) * n
        else:
            total += measure(draw, run, fnt)[0]
    return total


def wrap_words(draw, text, fnt, max_w, emoji_side):
    words = text.split()
    lines, cur = [], ""
    for w in words:
        test = w if not cur else f"{cur} {w}"
        if line_width(draw, test, fnt, emoji_side) <= max_w:
            cur = test
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines or [""]


def draw_tiktok_line(base: Image.Image, xy, text, fnt, stroke=6, fill=(255, 255, 255)):
    """White text + black outline, with color emoji support."""
    rgba = base.convert("RGBA")
    draw = ImageDraw.Draw(rgba)
    x, y = xy
    th = measure(draw, "Ag", fnt)[1]
    emoji_side = max(th + 10, 44)
    ef = emoji_fnt()

    for run, em in split_runs(text):
        if not run:
            continue
        if em:
            i = 0
            while i < len(run):
                cluster = run[i]
                i += 1
                while i < len(run) and (run[i] in ("\u200d", "\ufe0f") or (0x1F3FB <= ord(run[i]) <= 0x1F3FF)):
                    cluster += run[i]
                    i += 1
                    if cluster.endswith("\u200d") and i < len(run):
                        cluster += run[i]
                        i += 1
                tmp = Image.new("RGBA", (180, 180), (0, 0, 0, 0))
                ImageDraw.Draw(tmp).text((0, 0), cluster, font=ef, embedded_color=True)
                bb = tmp.getbbox()
                if not bb:
                    continue
                glyph = tmp.crop(bb).resize((emoji_side, emoji_side), Image.Resampling.LANCZOS)
                py = y + (th - emoji_side) // 2
                rgba.alpha_composite(glyph, (int(x), max(0, int(py))))
                x += emoji_side + 4
        else:
            # outline
            for dx, dy in [(-stroke, 0), (stroke, 0), (0, -stroke), (0, stroke),
                           (-stroke, -stroke), (stroke, -stroke), (-stroke, stroke), (stroke, stroke)]:
                draw.text((x + dx, y + dy), run, font=fnt, fill=(0, 0, 0))
            draw.text((x, y), run, font=fnt, fill=fill)
            x += measure(draw, run, fnt)[0]

    out = Image.alpha_composite(base.convert("RGBA"), rgba).convert("RGB")
    base.paste(out)


def draw_centered_block(img, lines, *, y_center=None, y_top=None, size=72, stroke=7, max_w=960, gap=14, fill=(255, 255, 255)):
    fnt = font(FONT_BLACK if size >= 64 else FONT_BOLD, size)
    draw = ImageDraw.Draw(img)
    emoji_side = max(size + 4, 40)
    wrapped = []
    for line in lines:
        wrapped.extend(wrap_words(draw, line, fnt, max_w, emoji_side))
    heights = []
    widths = []
    for line in wrapped:
        w = line_width(draw, line, fnt, emoji_side)
        h = measure(draw, "Ag", fnt)[1] + 8
        widths.append(w)
        heights.append(h)
    total_h = sum(heights) + gap * (len(wrapped) - 1 if wrapped else 0)
    if y_top is not None:
        y = y_top
    else:
        y = (y_center or H // 2) - total_h // 2
    for i, line in enumerate(wrapped):
        x = (W - widths[i]) // 2
        draw_tiktok_line(img, (x, y), line, fnt, stroke=stroke, fill=fill)
        y += heights[i] + gap
    return y


def draw_left_block(img, lines, *, x=70, y=200, size=48, stroke=5, max_w=940, gap=18):
    fnt = font(FONT_BOLD, size)
    draw = ImageDraw.Draw(img)
    emoji_side = max(size + 4, 36)
    cy = y
    for line in lines:
        for wline in wrap_words(draw, line, fnt, max_w, emoji_side):
            draw_tiktok_line(img, (x, cy), wline, fnt, stroke=stroke)
            cy += measure(draw, "Ag", fnt)[1] + gap
    return cy


def save(img, folder: Path, i: int) -> str:
    name = f"slide_{i:02d}.jpg"
    img.convert("RGB").save(folder / name, quality=93, optimize=True)
    return name


def write_meta(folder: Path, data: dict):
    (folder / "meta.json").write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    tags = " ".join(f"#{t.lstrip('#')}" for t in data["hashtags"])
    (folder / "CAPTION.txt").write_text(f"{data['caption']}\n\n{tags}\n", encoding="utf-8")
    (folder / "HOOK.txt").write_text(data["hook"] + "\n", encoding="utf-8")


# ---------- layouts ----------

def layout_full(path: Path, dark=0.78) -> Image.Image:
    return darken(cover(path), dark)


def layout_split_v(top: Path, bottom: Path) -> Image.Image:
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    t = cover(top, (W, H // 2), bias=0.25)
    b = cover(bottom, (W, H // 2), bias=0.3)
    canvas.paste(t, (0, 0))
    canvas.paste(b, (0, H // 2))
    # thin divider
    ImageDraw.Draw(canvas).rectangle([0, H // 2 - 3, W, H // 2 + 3], fill=(255, 255, 255))
    return canvas


def layout_grid2x2(paths: list[Path]) -> Image.Image:
    assert len(paths) >= 4
    canvas = Image.new("RGB", (W, H), (0, 0, 0))
    cw, ch = W // 2, H // 2
    positions = [(0, 0), (cw, 0), (0, ch), (cw, ch)]
    for p, (x, y) in zip(paths[:4], positions):
        tile = cover(p, (cw, ch), bias=0.3)
        canvas.paste(tile, (x, y))
    # white cross
    d = ImageDraw.Draw(canvas)
    d.rectangle([cw - 3, 0, cw + 3, H], fill=(255, 255, 255))
    d.rectangle([0, ch - 3, W, ch + 3], fill=(255, 255, 255))
    return canvas


# ---------- themes (1 carousel = 1 theme) ----------

def theme_debloat_face(out: Path) -> dict:
    """Theme: dégonfler le visage en 7 jours — full value protocol."""
    slides = []

    # 1 hook full
    img = layout_full(NORMAL[0], 0.65)
    draw_centered_block(img, ["comment dégonfler", "ton visage", "en 7 jours"], size=78, stroke=8)
    slides.append({"file": save(img, out, 1), "text": "hook"})

    # 2 before/after split
    img = layout_split_v(NORMAL[1], PRIME[1])
    draw_centered_block(img, ["AVANT"], y_top=H // 4 - 40, size=70, stroke=8)
    draw_centered_block(img, ["APRÈS"], y_top=3 * H // 4 - 40, size=70, stroke=8)
    slides.append({"file": save(img, out, 2), "text": "avant apres"})

    # 3 why
    img = layout_full(NORMAL[4], 0.55)
    draw_centered_block(
        img,
        [
            "ce n'est PAS du gras",
            "",
            "c'est de la rétention",
            "sel + sommeil + alcool",
            "+ digestion lente",
        ],
        size=56,
        stroke=6,
        gap=10,
    )
    slides.append({"file": save(img, out, 3), "text": "cause"})

    # 4 protocol tip dense
    img = layout_full(PRIME[0], 0.5)
    draw_left_block(
        img,
        [
            "PROTOCOLE 7 JOURS",
            "",
            "1. 500ml d'eau au réveil",
            "   (avant café / téléphone)",
            "",
            "2. Sel bas le soir",
            "   coupe chips, charcut, sauces",
            "",
            "3. Marche 30–45 min / jour",
            "   idéalement après le repas",
            "",
            "4. Coucher avant 23h30",
            "   7h30 de sommeil minimum",
        ],
        y=180,
        size=44,
        gap=10,
    )
    slides.append({"file": save(img, out, 4), "text": "protocole"})

    # 5 meal tip with food visual
    img = layout_full(MEALS[2] if MEALS else PRIME[2], 0.55)
    draw_centered_block(
        img,
        [
            "assiette anti-gonfle",
            "",
            "protéines à chaque repas",
            "légumes + eau",
            "stop snacks salés après 21h",
            "alcool = visage retenu J+1",
        ],
        size=52,
        stroke=6,
        gap=12,
    )
    slides.append({"file": save(img, out, 5), "text": "assiette"})

    # 6 sleep tip
    img = layout_full(LIFE[2] if LIFE else NORMAL[5], 0.5)
    draw_centered_block(
        img,
        [
            "sommeil = 50% du résultat",
            "",
            "moins de 6h = visage gonflé",
            "même si tu manges clean",
            "",
            "fixe une heure de coucher",
            "et tiens-la 7 jours",
        ],
        size=52,
        stroke=6,
        gap=12,
    )
    slides.append({"file": save(img, out, 6), "text": "sommeil"})

    # 7 mistakes
    img = layout_full(NORMAL[7], 0.5)
    draw_left_block(
        img,
        [
            "ERREURS QUI TE BLOQUENT",
            "",
            "❌ tout changer d'un coup",
            "❌ cardio intensif sans dormir",
            "❌ sauter des repas puis binge",
            "❌ juger après 2 jours",
            "",
            "✅ 4 habitudes. 7 jours. Point.",
        ],
        y=280,
        size=46,
        gap=14,
    )
    slides.append({"file": save(img, out, 7), "text": "erreurs"})

    # 8 cta
    img = layout_full(PRIME[6], 0.55)
    draw_centered_block(
        img,
        [
            "enregistre ce post",
            "fais ça 7 jours",
            "puis juge",
            "",
            "commente PLAN",
            "pour le détail",
        ],
        size=64,
        stroke=7,
        gap=12,
    )
    slides.append({"file": save(img, out, 8), "text": "cta"})

    caption = (
        "Comment dégonfler ton visage en 7 jours 🥥\n\n"
        "Ce n'est PAS forcément du gras.\n"
        "Souvent c'est de la rétention : sel + sommeil + alcool + digestion lente.\n\n"
        "PROTOCOLE SIMPLE (applique tel quel) :\n\n"
        "1. 500ml d'eau au réveil — avant café et téléphone\n"
        "2. Sel bas le soir — coupe chips, charcuterie, sauces, resto salé\n"
        "3. Marche 30–45 min / jour — idéalement après un repas\n"
        "4. Coucher avant 23h30 — vise 7h30 de sommeil\n\n"
        "ASSIETTE :\n"
        "• Protéines à chaque repas\n"
        "• Légumes + eau\n"
        "• Stop snacks salés après 21h\n"
        "• Alcool = visage retenu le lendemain (quasi garanti)\n\n"
        "ERREURS :\n"
        "• Tout changer d'un coup\n"
        "• Juger après 2 jours\n"
        "• Cardio hardcore sans dormir\n\n"
        "Fais ça 7 jours. Ensuite tu juges sur photo (même angle, même lumière).\n\n"
        f"{PROCESS_SOFT}\n\n"
        "Commente PLAN si tu veux la version détaillée jour par jour."
    )
    return {
        "format": "guide",
        "theme": "debloat_face_7j",
        "lang": "fr",
        "hook": "comment dégonfler ton visage en 7 jours",
        "caption": caption,
        "hashtags": ["debloat", "visage", "glowup", "retention", "processai"],
        "cta": "Commente PLAN",
        "slides": slides,
        "status": "ready",
    }


def theme_top_habitudes(out: Path) -> dict:
    """Theme: top 5 habitudes anti-gonfle — grid + ranked tips."""
    slides = []

    img = layout_full(PRIME[5], 0.6)
    draw_centered_block(img, ["5 habitudes", "qui dégonflent", "le visage"], size=78, stroke=8)
    slides.append({"file": save(img, out, 1), "text": "hook"})

    # grid collage vibe
    grid_paths = [PRIME[1], PRIME[3], NORMAL[0], PRIME[6]]
    if len(FACES) >= 2:
        grid_paths[2] = FACES[0]
    img = layout_grid2x2(grid_paths)
    # darken center for text readability via overlay
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(overlay).rectangle([120, H // 2 - 160, W - 120, H // 2 + 160], fill=(0, 0, 0, 90))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    draw_centered_block(img, ["swipe pour", "le classement"], size=70, stroke=8)
    slides.append({"file": save(img, out, 2), "text": "grid"})

    ranked = [
        ("5", "coupe l'alcool le soir", "Même 1–2 verres = rétention faciale le lendemain. Teste 7 soirs sans et compare."),
        ("4", "dors avant minuit", "Le sommeil répare l'inflammation. Sous 6h, le visage gonfle même en déficit."),
        ("3", "marche après manger", "20–40 min. Digestion + drainage. Le hack le plus sous-estimé."),
        ("2", "réduis le sel 7 jours", "Le levier n°1. Attention sauces, fromage, charcut, plats préparés."),
        ("1", "eau dès le réveil", "500ml avant le café. Ton corps lâche l'eau retenue quand tu t'hydrates."),
    ]
    photos = [NORMAL[2], NORMAL[5], LIFE[8] if len(LIFE) > 8 else PRIME[2], MEALS[5] if len(MEALS) > 5 else NORMAL[8], PRIME[0]]
    for i, ((num, title, detail), photo) in enumerate(zip(ranked, photos), start=3):
        img = layout_full(photo, 0.5)
        prefix = "🥇" if num == "1" else f"#{num}"
        draw_centered_block(img, [f"{prefix}  {title}"], y_top=420, size=58, stroke=7)
        draw_centered_block(img, detail.split(". "), y_top=700, size=42, stroke=5, gap=16, max_w=920)
        slides.append({"file": save(img, out, i), "text": f"#{num}"})

    img = layout_full(PRIME[4], 0.55)
    draw_centered_block(
        img,
        ["fais les 5", "pendant 7 jours", "", "commente FAIT", "quand c'est lancé"],
        size=64,
        stroke=7,
        gap=12,
    )
    slides.append({"file": save(img, out, 8), "text": "cta"})

    caption = (
        "5 habitudes qui dégonflent le visage 🔥\n\n"
        "Classe du plus utile :\n\n"
        "5. Coupe l'alcool le soir\n"
        "→ Même 1–2 verres = rétention faciale le lendemain. Teste 7 soirs sans.\n\n"
        "4. Dors avant minuit\n"
        "→ Sous 6h de sommeil, le visage gonfle même si tu manges clean.\n\n"
        "3. Marche après manger\n"
        "→ 20–40 min. Digestion + drainage. Le hack le plus sous-estimé.\n\n"
        "2. Réduis le sel 7 jours\n"
        "→ Levier n°1. Sauces, fromage, charcut, plats préparés = pièges.\n\n"
        "1. Eau dès le réveil\n"
        "→ 500ml avant le café. Ton corps lâche l'eau retenue quand tu t'hydrates vraiment.\n\n"
        "Applique les 5 pendant 7 jours. Photo avant/après même angle.\n\n"
        f"{PROCESS_SOFT}\n\n"
        "Commente FAIT si tu lances demain matin."
    )
    return {
        "format": "top",
        "theme": "top5_anti_gonfle",
        "lang": "fr",
        "hook": "5 habitudes qui dégonflent le visage",
        "caption": caption,
        "hashtags": ["top5", "debloat", "habitudes", "visage", "processai"],
        "cta": "Commente FAIT",
        "slides": slides,
        "status": "ready",
    }


def theme_avant_vs_maintenant_meals(out: Path) -> dict:
    """Theme: ce que je mangeais AVANT vs MAINTENANT — split food comparisons."""
    slides = []

    img = layout_full(PRIME[3], 0.62)
    draw_centered_block(img, ["ce que je mangeais", "AVANT vs MAINTENANT"], size=68, stroke=8)
    slides.append({"file": save(img, out, 1), "text": "hook"})

    # comparisons: use meal images as "now", darker/messier lifestyle as before when possible
    pairs = [
        ("AVANT", "MAINTENANT", LIFE[15] if len(LIFE) > 15 else NORMAL[0], MEALS[0],
         "snacks salés le soir", "protéines + légumes"),
        ("AVANT", "MAINTENANT", MEALS[10] if len(MEALS) > 10 else MEALS[1], MEALS[3],
         "plat ultra salé", "assiette simple maison"),
        ("AVANT", "MAINTENANT", MEALS[12] if len(MEALS) > 12 else MEALS[4], MEALS[6],
         "petit-déj sucre only", "œufs / skyr / fruit"),
    ]
    idx = 2
    for a_label, b_label, a_img, b_img, a_txt, b_txt in pairs:
        img = layout_split_v(a_img, b_img)
        draw_centered_block(img, [a_label], y_top=80, size=56, stroke=7)
        draw_centered_block(img, [a_txt], y_top=H // 4 - 20, size=44, stroke=5)
        draw_centered_block(img, [b_label], y_top=H // 2 + 80, size=56, stroke=7)
        draw_centered_block(img, [b_txt], y_top=3 * H // 4 - 20, size=44, stroke=5)
        slides.append({"file": save(img, out, idx), "text": f"vs{idx}"})
        idx += 1

    img = layout_full(MEALS[8] if len(MEALS) > 8 else MEALS[0], 0.55)
    draw_left_block(
        img,
        [
            "RÈGLES SIMPLES",
            "",
            "• Protéines à CHAQUE repas",
            "  (œufs, poulet, poisson, skyr)",
            "",
            "• Sel bas après 18h",
            "  (le soir = visage le matin)",
            "",
            "• Eau : 2.5–3.5L / jour",
            "  selon ton poids / sport",
            "",
            "• Dernier snack salé : avant 21h",
            "",
            "Pas parfait. Juste répété.",
        ],
        y=200,
        size=42,
        gap=10,
    )
    slides.append({"file": save(img, out, idx), "text": "regles"})
    idx += 1

    img = layout_full(PRIME[6], 0.55)
    draw_centered_block(
        img,
        ["enregistre", "applique 7 jours", "", "commente PLAN"],
        size=68,
        stroke=8,
        gap=14,
    )
    slides.append({"file": save(img, out, idx), "text": "cta"})

    caption = (
        "Ce que je mangeais AVANT vs MAINTENANT 🥗\n\n"
        "Pas une diète extrême. Juste des swaps qui dégonflent le visage.\n\n"
        "AVANT → MAINTENANT :\n"
        "• Snacks salés le soir → protéines + légumes\n"
        "• Plat ultra salé / resto → assiette simple maison\n"
        "• Petit-déj sucre only → œufs / skyr / fruit\n\n"
        "RÈGLES QUI MARCHENT VRAIMENT :\n\n"
        "1. Protéines à chaque repas\n"
        "   Œufs, poulet, poisson, skyr, viande maigre.\n\n"
        "2. Sel bas après 18h\n"
        "   Le sel du soir = visage gonflé le matin. Quasi mécanique.\n\n"
        "3. Eau 2.5–3.5L / jour\n"
        "   Si tu bois peu, ton corps RETIENT l'eau.\n\n"
        "4. Stop snacks salés après 21h\n"
        "   Chips, fromage, charcut, sauces = piège n°1.\n\n"
        "Fais ça 7 jours. Photo avant/après même angle, même lumière.\n\n"
        f"{PROCESS_SOFT}\n\n"
        "Commente PLAN pour le détail repas par repas."
    )
    return {
        "format": "vs",
        "theme": "avant_vs_maintenant_meals",
        "lang": "fr",
        "hook": "ce que je mangeais AVANT vs MAINTENANT",
        "caption": caption,
        "hashtags": ["nutrition", "debloat", "avantapres", "gymtok", "processai"],
        "cta": "Commente PLAN",
        "slides": slides,
        "status": "ready",
    }


def main():
    if len(NORMAL) < 8 or len(PRIME) < 6:
        raise SystemExit(f"Need Imran assets: normal={len(NORMAL)} prime={len(PRIME)}")
    if len(MEALS) < 8:
        raise SystemExit(f"Need meals: {len(MEALS)}")

    QUEUE.mkdir(parents=True, exist_ok=True)
    for p in QUEUE.iterdir():
        if p.is_dir() and p.name.startswith("20"):
            for f in p.glob("*"):
                f.unlink()
            p.rmdir()
    idx = QUEUE / "INDEX.md"
    if idx.exists():
        idx.unlink()

    jobs = [
        ("2026-07-09_01_theme-debloat-7j", theme_debloat_face),
        ("2026-07-09_02_theme-top5-habitudes", theme_top_habitudes),
        ("2026-07-09_03_theme-avant-vs-meals", theme_avant_vs_maintenant_meals),
    ]

    lines = [
        "# Queue TikTok — v3 (style natif TikTok)",
        "",
        "Règles: 1 carrousel = 1 thème | texte blanc+contour | layouts variés | full valeur",
        "",
    ]
    for name, builder in jobs:
        folder = QUEUE / name
        folder.mkdir(parents=True, exist_ok=True)
        meta = builder(folder)
        write_meta(folder, meta)
        lines.append(f"- `{name}/` — **{meta['theme']}** — {meta['hook']} ({len(meta['slides'])} slides)")
        print(f"OK {name} ({len(meta['slides'])} slides) theme={meta['theme']}")

    idx.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("DONE")


if __name__ == "__main__":
    main()
