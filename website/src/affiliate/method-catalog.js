import {
  AFFILIATE_X_DM_URL,
  COMMISSION_PERCENT,
  HOLD_DAYS,
  VIEW_BONUS_MAX_PER_VIDEO_USD,
} from "./affiliate-utils.js";

export const MANNY_TIKTOK_URL = "https://www.tiktok.com/@mannyprcs";
export const MANNY_TIKTOK_HANDLE = "@mannyprcs";

const ASSET = "/assets/affiliate/method";

export const PACE_BY_HOURS = {
  lt1: { posts: "1", week2: "1", fr: "1 post / jour", en: "1 post / day" },
  "1-2": { posts: "1–2", week2: "2", fr: "1 à 2 posts / jour", en: "1–2 posts / day" },
  "3-4": { posts: "2–3", week2: "3", fr: "2 à 3 posts / jour", en: "2–3 posts / day" },
  "5+": { posts: "3", week2: "3+", fr: "3 posts / jour, plusieurs comptes", en: "3 posts / day, multiple accounts" },
};

export function paceFromHours(hoursPerDay) {
  return PACE_BY_HOURS[hoursPerDay] || PACE_BY_HOURS["1-2"];
}

export const FORMAT_SPECS = [
  {
    id: "01",
    name: { fr: "01 — Guide 72h", en: "01 — 72h guide" },
    canvas: "1080×1920",
    when: {
      fr: "Tous les jours. C’est le format de conversion n°1.",
      en: "Every day. This is the #1 conversion format.",
    },
    hook: {
      fr: "visage gonflé ? fais ça 72h",
      en: "puffy face? do this for 72h",
    },
    caption: {
      fr: "visage gonflé ? fais ça 72h\n\n#debloat #retentiondeau #process #glowup",
      en: "puffy face? do this for 72h\n\n#debloat #waterretention #process #glowup",
    },
    fatal: {
      fr: "Ne colle pas la carte App Store par-dessus. Le scan vit dans la grille 2×2.",
      en: "Don't paste the App Store card on top. The scan lives in the 2×2 grid.",
    },
    slides: [
      { src: `${ASSET}/format-01/hook.jpg`, fr: "Hook", en: "Hook" },
      { src: `${ASSET}/format-01/before.jpg`, fr: "Before (bloat)", en: "Before (bloat)" },
      { src: `${ASSET}/format-01/scan.jpg`, fr: "Scan 2×2 + app", en: "Scan 2×2 + app" },
    ],
    structure: [
      { fr: "1. Hook — une promesse, 1 seconde", en: "1. Hook — one promise, one second" },
      { fr: "2. Before — visage gonflé", en: "2. Before — puffy face" },
      { fr: "3. After — même personne, plus net", en: "3. After — same person, sharper" },
      { fr: "4. Scan 2×2 — visages + screen app dans la grille", en: "4. Scan 2×2 — faces + app screen in the grid" },
      { fr: "5–8. Protocole : glace → cardio → alim → sauna", en: "5–8. Protocol: ice → cardio → food → sauna" },
    ],
  },
  {
    id: "02",
    name: { fr: "02 — Glow-up célébrité", en: "02 — Celebrity glow-up" },
    canvas: "1080×1920",
    when: {
      fr: "Quand un visage connu est en tendance (Damson, Marlon, MBJ, Pitt, Kai).",
      en: "When a known face is trending (Damson, Marlon, MBJ, Pitt, Kai).",
    },
    hook: {
      fr: "Comment glow up rapidement (méthode Damson Idris)",
      en: "How to glow up fast (Damson Idris method)",
    },
    caption: {
      fr: "Comment glow up rapidement — méthode Damson Idris\n\n#GlowUp #damsonidris #process #debloat",
      en: "How to glow up fast — Damson Idris method\n\n#GlowUp #damsonidris #process #debloat",
    },
    fatal: {
      fr: "Pas de carte App Store overlay. Le screen Process est une slide de la grille.",
      en: "No App Store card overlay. The Process screen is a grid slide.",
    },
    slides: [
      { src: `${ASSET}/format-02/hook.jpg`, fr: "Hook", en: "Hook" },
      { src: `${ASSET}/format-02/tip.jpg`, fr: "Tip visage", en: "Face tip" },
      { src: `${ASSET}/format-02/app.jpg`, fr: "Slide Process", en: "Process slide" },
    ],
    structure: [
      { fr: "1. Hook — Comment glow up (méthode X)", en: "1. Hook — How to glow up (X method)" },
      { fr: "2–4. Tips visage (sourire, lèvres, style)", en: "2–4. Face tips (smile, lips, style)" },
      { fr: "5. Slide Process — scan / protocole", en: "5. Process slide — scan / protocol" },
    ],
  },
  {
    id: "03",
    name: { fr: "03 — Foods", en: "03 — Foods" },
    canvas: "1080×1920",
    when: {
      fr: "Alim, drain, soir. Alterne avec le 01 pour ne pas lasser le FYP.",
      en: "Food, drain, night. Alternate with 01 so the FYP doesn't get bored.",
    },
    hook: {
      fr: "7 aliments qui dégonflent ton visage pendant la nuit",
      en: "7 foods that depuff your face overnight",
    },
    caption: {
      fr: "Tous les aliments full debloat sont sur l'app\n« Process Debloat » sur App Store\n\n#glowup #process #debloat",
      en: "Every full debloat food is in the app\n“Process Debloat” on the App Store\n\n#glowup #process #debloat",
    },
    fatal: {
      fr: "Garder la carte App Store (seul format où elle reste). 1 aliment = 1 slide.",
      en: "Keep the App Store card (the only format that keeps it). One food = one slide.",
    },
    slides: [
      { src: `${ASSET}/format-03/hook.jpg`, fr: "Hook", en: "Hook" },
      { src: `${ASSET}/format-03/food.jpg`, fr: "Aliment", en: "Food" },
      { src: `${ASSET}/format-03/app.jpg`, fr: "App + carte", en: "App + card" },
    ],
    structure: [
      { fr: "1. Hook texte sur photo food", en: "1. Text hook on a food photo" },
      { fr: "2–N. Un aliment par slide + 1 bénéfice", en: "2–N. One food per slide + one benefit" },
      { fr: "Milieu / fin : phone + carte App Store", en: "Middle / end: phone + App Store card" },
    ],
  },
  {
    id: "04",
    name: { fr: "04 — Hygin 2×2", en: "04 — Hygin 2×2" },
    canvas: "1080×1440 (3:4)",
    when: {
      fr: "Looksmaxxing / cause → effet. Fort sur les saves.",
      en: "Looksmaxxing / cause → effect. Strong on saves.",
    },
    hook: {
      fr: "Comment être MIEUX dès aujourd'hui",
      en: "How to look BETTER starting today",
    },
    caption: {
      fr: "Comment être mieux dès aujourd'hui\n\n#debloat #retentiondeau #process #glowup #looksmaxxing",
      en: "How to look better starting today\n\n#debloat #waterretention #process #glowup #looksmaxxing",
    },
    fatal: {
      fr: "Canvas 3:4. Pas d’overlay App Store. Hook en noir & blanc.",
      en: "3:4 canvas. No App Store overlay. Hook in black & white.",
    },
    slides: [
      { src: `${ASSET}/format-04/hook.jpg`, fr: "Hook N&B", en: "B&W hook" },
      { src: `${ASSET}/format-04/grid.jpg`, fr: "Grille 2×2", en: "2×2 grid" },
    ],
    structure: [
      { fr: "1. Hook N&B, 2–3 lignes max", en: "1. B&W hook, 2–3 lines max" },
      { fr: "2+. Bannière rouge + grille 2×2 (mauvais → gonflé / bon → net)", en: "2+. Red banner + 2×2 grid (bad → puffy / good → sharp)" },
    ],
  },
  {
    id: "05",
    name: { fr: "05 — Colonnes", en: "05 — Columns" },
    canvas: "1080×1440 (3:4)",
    when: {
      fr: "Comparaison méthode vs méthode. Le gagnant debloat = screen Process.",
      en: "Method vs method. Debloat winner = Process screen.",
    },
    hook: {
      fr: "Debloat > eau de coco",
      en: "Debloat > coconut water",
    },
    caption: {
      fr: "Debloat > eau de coco\n\n#debloat #retentiondeau #process #glowup #looksmaxxing",
      en: "Debloat > coconut water\n\n#debloat #waterretention #process #glowup #looksmaxxing",
    },
    fatal: {
      fr: "Pas d’overlay App Store. Gagnant debloat = screen Process, pas une photo food.",
      en: "No App Store overlay. Debloat winner = Process screen, not a food photo.",
    },
    slides: [
      { src: `${ASSET}/format-05/hook.jpg`, fr: "Colonnes", en: "Columns" },
      { src: `${ASSET}/format-05/debloat.jpg`, fr: "Process gagne", en: "Process wins" },
    ],
    structure: [
      { fr: "1 titre (CHEVEUX, MÂCHOIRE, DEBLOAT, PEAU)", en: "1 title (HAIR, JAW, DEBLOAT, SKIN)" },
      { fr: "2 colonnes : méthode faible vs méthode qui gagne", en: "2 columns: weak method vs winning method" },
      { fr: "Slide DEBLOAT : eau de coco vs Process app", en: "DEBLOAT slide: coconut water vs Process app" },
    ],
  },
];

function step(fr, en) {
  return { fr, en };
}

export const METHOD_MODULES = [
  {
    id: "hub",
    index: 0,
    title: { fr: "Playbook TikTok", en: "TikTok playbook" },
    nav: { fr: "Accueil", en: "Home" },
    kicker: { fr: "Lis tout avant de poster", en: "Read everything before you post" },
    blocks: [
      {
        type: "lead",
        fr: "Même densité qu’une formation clipper — adaptée à Process. Slideshow d’abord, conversion vers l’app, pas du contenu vide.",
        en: "Same density as a clipper academy — built for Process. Slideshows first, convert to the app, not empty content.",
      },
      {
        type: "callout",
        fr: "Avant de poster : lis le playbook, ouvre Formats, copie une structure — pas une vidéo 1:1. Ton lien va dans la bio et le commentaire épinglé.",
        en: "Before you post: read the playbook, open Formats, copy a structure — not a 1:1 video. Your link goes in the bio and the pinned comment.",
      },
      {
        type: "pace",
      },
      { type: "cta-formats" },
      {
        type: "links",
        items: [
          {
            id: "manny",
            href: MANNY_TIKTOK_URL,
            fr: `${MANNY_TIKTOK_HANDLE} — compte à copier`,
            en: `${MANNY_TIKTOK_HANDLE} — account to copy`,
          },
          {
            id: "join",
            hrefKey: "linkUrl",
            fr: "Ton lien créateur — {code}",
            en: "Your creator link — {code}",
          },
          {
            id: "leks",
            href: AFFILIATE_X_DM_URL,
            fr: "DM leks sur X — primes et questions",
            en: "DM leks on X — bonuses and questions",
          },
        ],
      },
    ],
  },
  {
    id: "devenir",
    index: 1,
    title: { fr: "Devenir affilié Process", en: "Become a Process affiliate" },
    nav: { fr: "1. Programme", en: "1. Program" },
    kicker: { fr: "Comment tu es payé", en: "How you get paid" },
    blocks: [
      {
        type: "lead",
        fr: "Process scanne la rétention d’eau du visage et donne un protocole. Toi tu amènes des abonnés avec des slideshow TikTok. Chaque abo via ton lien ou ton code = commission.",
        en: "Process scans facial water retention and builds a protocol. You bring subscribers with TikTok slideshows. Every sub through your link or code = commission.",
      },
      {
        type: "steps",
        title: { fr: "L’argent", en: "The money" },
        items: [
          step(
            `${COMMISSION_PERCENT} % à vie sur chaque abonnement généré (hors lifetime).`,
            `${COMMISSION_PERCENT}% for life on every subscription you generate (lifetime SKU excluded).`
          ),
          step(
            `Retenue ${HOLD_DAYS} jours (fenêtre de remboursement), puis payout Stripe.`,
            `${HOLD_DAYS}-day hold (refund window), then Stripe payout.`
          ),
          step(
            `Primes vues en plus, jusqu’à $${VIEW_BONUS_MAX_PER_VIDEO_USD} / vidéo — review manuelle, pas auto.`,
            `View bonuses on top, up to $${VIEW_BONUS_MAX_PER_VIDEO_USD} / video — manual review, not automatic.`
          ),
        ],
      },
      {
        type: "steps",
        title: { fr: "Obligatoire sur chaque post", en: "Required on every post" },
        items: [
          step("Lien {link} dans la bio.", "Link {link} in the bio."),
          step("Commentaire épinglé avec le même lien + ton code {code}.", "Pinned comment with the same link + your code {code}."),
          step("Le viewer entre le code au checkout s’il n’a pas cliqué le lien.", "The viewer enters the code at checkout if they didn't click the link."),
        ],
      },
      {
        type: "dont",
        title: { fr: "Interdit", en: "Not allowed" },
        items: [
          step("Pub payante (TikTok Ads, Spark, Meta). Commissions non versées.", "Paid ads (TikTok Ads, Spark, Meta). Commissions will not be paid."),
          step("Claims médicaux (“guérit”, “diagnostic”). Process = protocole, pas un médecin.", "Medical claims (“cures”, “diagnosis”). Process is a protocol, not a doctor."),
          step("Spam de 10 posts le dimanche. Ça brûle le compte.", "Spamming 10 posts on Sunday. That burns the account."),
        ],
      },
      {
        type: "links",
        items: [
          {
            id: "join",
            hrefKey: "linkUrl",
            fr: "Ton lien créateur — {code}",
            en: "Your creator link — {code}",
          },
          {
            id: "manny",
            href: MANNY_TIKTOK_URL,
            fr: `${MANNY_TIKTOK_HANDLE} — formats à copier`,
            en: `${MANNY_TIKTOK_HANDLE} — formats to copy`,
          },
          {
            id: "leks",
            href: AFFILIATE_X_DM_URL,
            fr: "DM leks sur X",
            en: "DM leks on X",
          },
        ],
      },
    ],
  },
  {
    id: "slideshow",
    index: 2,
    title: { fr: "Slideshow vs clipping", en: "Slideshow vs clipping" },
    nav: { fr: "2. Slideshow", en: "2. Slideshow" },
    kicker: { fr: "Le track principal", en: "The main track" },
    blocks: [
      {
        type: "lead",
        fr: "Chez Process, le clipping classique (couper une vidéo longue) est optionnel. Le track qui convertit, c’est le photo carousel TikTok — une structure lockée, des visuels différents à chaque post.",
        en: "At Process, classic clipping (cutting a long video) is optional. The track that converts is the TikTok photo carousel — a locked structure, different visuals every post.",
      },
      {
        type: "steps",
        title: { fr: "Un bon affilié", en: "A good affiliate" },
        items: [
          step("N’est pas shadowban (le compte est chauffé, les visuels changent).", "Isn't shadowbanned (account is warmed up, visuals change)."),
          step("Poste {posts} — tous les jours, pas un binge le week-end.", "Posts {posts} — every day, not a weekend binge."),
          step("Copie un format Process, pas une vidéo Manny pixel à pixel.", "Copies a Process format, not a Manny video pixel-for-pixel."),
          step("Pousse vers l’app (bio + pin), pas seulement vers les vues.", "Pushes to the app (bio + pin), not just views."),
        ],
      },
      {
        type: "callout",
        fr: `Process ne paie pas au CPM. ${COMMISSION_PERCENT} % sur l’abo + primes vues. Une vidéo à 40k qui convertit 2 abos vaut plus qu’un million de vues sans lien.`,
        en: `Process does not pay CPM. ${COMMISSION_PERCENT}% on the sub + view bonuses. A 40k video that converts 2 subs beats a million views with no link.`,
      },
      {
        type: "pace",
      },
    ],
  },
  {
    id: "compte",
    index: 3,
    title: { fr: "Créer et chauffer le compte", en: "Create and warm the account" },
    nav: { fr: "3. Compte", en: "3. Account" },
    kicker: { fr: "3 minutes + 7 jours", en: "3 minutes + 7 days" },
    blocks: [
      {
        type: "steps",
        title: { fr: "Créer le compte (3 minutes)", en: "Create the account (3 minutes)" },
        items: [
          step("TikTok Creator (Réglages → Gérer le compte). Pas un compte perso recyclé.", "TikTok Creator (Settings → Manage account). Don't recycle a personal account."),
          step("Username / display name glow-up ou debloat (pas besoin de coller “app” dans le nom).", "Username / display name glow-up or debloat (you don't need “app” in the name)."),
          step("Photo de profil nette — visage ou esthétique produit, pas un logo flou.", "Clean profile photo — face or product aesthetic, not a blurry logo."),
          step(
            "Bio : « Visage gonflé ? Scan ta rétention. Protocoles tous les jours. » + lien {link}",
            "Bio: “Puffy face? Scan your water retention. Daily protocols.” + link {link}"
          ),
        ],
      },
      {
        type: "steps",
        title: { fr: "Chauffer (2 jours)", en: "Warm up (2 days)" },
        items: [
          step("Cherche debloat, rétention d’eau, glow-up, looksmaxxing.", "Search debloat, water retention, glow-up, looksmaxxing."),
          step("Like + commente 15 min. Scrolle le FYP plusieurs fois par jour.", "Like + comment 15 min. Scroll the FYP several times a day."),
          step("Prépare tes carousels en brouillons. Ne poste pas 5 fois le jour 1.", "Stage carousels as drafts. Don't post 5 times on day 1."),
        ],
      },
      {
        type: "steps",
        title: { fr: "Volume", en: "Volume" },
        items: [
          step("Semaine 1 : 1 post / jour MAX.", "Week 1: 1 post / day MAX."),
          step("Semaine 2 : 2 posts / jour.", "Week 2: 2 posts / day."),
          step("Ensuite : {posts}. Jamais 10 posts le dimanche.", "Then: {posts}. Never 10 posts on Sunday."),
        ],
      },
    ],
  },
  {
    id: "original",
    index: 4,
    title: { fr: "Slideshow originaux", en: "Original slideshows" },
    nav: { fr: "4. Original", en: "4. Original" },
    kicker: { fr: "Anti-shadowban photo", en: "Photo anti-shadowban" },
    blocks: [
      {
        type: "lead",
        fr: "TikTok Photo Mode : jusqu’à 35 photos. Formats 01–03 en 1080×1920. Formats 04–05 en 1080×1440 (3:4). Le texte est déjà sur l’image — tu n’ajoutes pas de caption overlay dans l’éditeur.",
        en: "TikTok Photo Mode: up to 35 photos. Formats 01–03 at 1080×1920. Formats 04–05 at 1080×1440 (3:4). Text is already on the image — don't add caption overlays in the editor.",
      },
      {
        type: "callout",
        fr: "Règle : même structure, visuels différents. Republier le pack Manny identique = shadowban.",
        en: "Rule: same structure, different visuals. Reuploading the identical Manny pack = shadowban.",
      },
      {
        type: "steps",
        title: { fr: "Change à chaque post", en: "Change on every post" },
        items: [
          step("Photos (autres visages, autres aliments, autre crop).", "Photos (other faces, other foods, other crop)."),
          step("Texte du hook (même promesse, autre formulation).", "Hook text (same promise, different wording)."),
          step("Ordre des slides du protocole, filtre, légère rotation.", "Protocol slide order, filter, slight rotation."),
        ],
      },
      {
        type: "dont",
        title: { fr: "Signaux de shadowban", en: "Shadowban signals" },
        items: [
          step("Moins de 50 vues et le bouton « Plus de données » est grisé.", "Under 50 views and the “More data” button is greyed out."),
          step("Compte pas assez chauffé, ou trop de posts en trop peu de temps.", "Account not warmed up enough, or too many posts in too little time."),
          step("TikTok reconnaît l’image — tu as recollé le même JPG.", "TikTok recognizes the image — you reused the same JPG."),
        ],
      },
    ],
  },
  {
    id: "viral",
    index: 5,
    title: { fr: "Slideshow viraux", en: "Viral slideshows" },
    nav: { fr: "5. Viral", en: "5. Viral" },
    kicker: { fr: "Hook, son, recycle", en: "Hook, sound, recycle" },
    blocks: [
      {
        type: "steps",
        title: { fr: "Ce qui fait scroller", en: "What makes people swipe" },
        items: [
          step("Hook slide = 1 idée. Le viewer comprend en 1 seconde ce qu’il gagne.", "Hook slide = 1 idea. The viewer gets the payoff in one second."),
          step("Une promesse par carousel. Pas un mélange glow-up + recette + POV.", "One promise per carousel. Don't mix glow-up + recipe + POV."),
          step("Son tendance OK, collé à l’émotion (pas un son random).", "Trending sound is OK if it matches the emotion (not a random track)."),
          step("Caption = 1 ligne + hashtags. Le CTA est le lien, pas un script d’ads.", "Caption = 1 line + hashtags. The CTA is the link, not an ads script."),
        ],
      },
      {
        type: "callout",
        fr: "Dès qu’un post passe 40k, tu le dupliques : même hook, nouvel angle, nouvelles photos. Les primes sont plafonnées à $300 / vidéo — le volume de hits compte.",
        en: "When a post clears 40k, duplicate it: same hook, new angle, new photos. Bonuses cap at $300 / video — hit volume matters.",
      },
      {
        type: "steps",
        title: { fr: "Hashtags Process", en: "Process hashtags" },
        items: [
          step("FR : #debloat #retentiondeau #process #glowup", "FR: #debloat #retentiondeau #process #glowup"),
          step("EN : #debloat #waterretention #process #glowup", "EN: #debloat #waterretention #process #glowup"),
          step("Looksmaxxing (04 / 05) : ajoute #looksmaxxing", "Looksmaxxing (04 / 05): add #looksmaxxing"),
        ],
      },
    ],
  },
  {
    id: "poster",
    index: 6,
    title: { fr: "Poster un carousel", en: "Post a carousel" },
    nav: { fr: "6. Poster", en: "6. Post" },
    kicker: { fr: "TikTok Photo Mode", en: "TikTok Photo Mode" },
    blocks: [
      {
        type: "steps",
        title: { fr: "Breakdown", en: "Breakdown" },
        items: [
          step("TikTok → + → Photo (pas Vidéo).", "TikTok → + → Photo (not Video)."),
          step("Importer les JPG dans l’ordre slide_01, slide_02, …", "Import the JPGs in order: slide_01, slide_02, …"),
          step("Recadrage : 9:16 pour 01–03, 3:4 pour 04–05. Ne pas zoomer le texte.", "Crop: 9:16 for 01–03, 3:4 for 04–05. Don't zoom into the text."),
          step("Ne re-tape pas le texte. Il est déjà brûlé sur l’image.", "Don't retype the text. It's already burned into the image."),
          step("Caption = la ligne du hook + hashtags.", "Caption = the hook line + hashtags."),
          step("Son tendance, volume bas si le texte porte déjà le message.", "Trending sound, low volume if the text already carries the message."),
          step("Publier.", "Publish."),
          step("Commentaire : {link} · code {code} — puis épingler.", "Comment: {link} · code {code} — then pin it."),
          step("Story : sticker lien vers le même URL.", "Story: link sticker to the same URL."),
        ],
      },
      {
        type: "callout",
        fr: "Sans pin + bio, tu fais des vues pour TikTok, pas pour Process.",
        en: "Without pin + bio, you're making views for TikTok, not for Process.",
      },
    ],
  },
  {
    id: "convertir",
    index: 8,
    title: { fr: "Convertir vers l’app", en: "Convert to the app" },
    nav: { fr: "7. Convertir", en: "7. Convert" },
    kicker: { fr: "Process gagne à l’abo", en: "Process earns on the sub" },
    blocks: [
      {
        type: "lead",
        fr: "Blow Up paie les vues. Process paie l’abonnement. Un carousel sans lien est un post mort.",
        en: "Blow Up pays for views. Process pays for the subscription. A carousel with no link is a dead post.",
      },
      {
        type: "steps",
        title: { fr: "Les 3 points de tracking", en: "The 3 tracking points" },
        items: [
          step("Bio = {link} (toujours).", "Bio = {link} (always)."),
          step("Commentaire épinglé = même lien + code {code}.", "Pinned comment = same link + code {code}."),
          step("Cookie 30 jours. Chaque clic ou usage du code reset la fenêtre.", "30-day cookie. Each click or code use resets the window."),
        ],
      },
      {
        type: "steps",
        title: { fr: "Ce que tu dis", en: "What you say" },
        items: [
          step("Caption : valeur d’abord, puis « Process Debloat » sur App Store.", "Caption: value first, then “Process Debloat” on the App Store."),
          step("Réponds aux « je trouve pas l’app » avec une capture App Store (tape Process).", "Reply to “I can’t find the app” with an App Store screenshot (search Process)."),
          step("Bio = {link}. Commentaire épinglé = même lien + code {code}.", "Bio = {link}. Pinned comment = same link + code {code}."),
        ],
      },
      {
        type: "dont",
        title: { fr: "Ce que tu ne dis pas", en: "What you don't say" },
        items: [
          step("Pas de pub payante. Pas de “guérit l’œdème”.", "No paid ads. No “cures edema”."),
          step("Pas de page de vente externe. Uniquement {link}.", "No external sales page. Only {link}."),
        ],
      },
      {
        type: "links",
        items: [
          {
            id: "join",
            hrefKey: "linkUrl",
            fr: "Ton lien — {code}",
            en: "Your link — {code}",
          },
          {
            id: "manny",
            href: MANNY_TIKTOK_URL,
            fr: `${MANNY_TIKTOK_HANDLE} — référence`,
            en: `${MANNY_TIKTOK_HANDLE} — reference`,
          },
          {
            id: "leks",
            href: AFFILIATE_X_DM_URL,
            fr: "DM leks sur X",
            en: "DM leks on X",
          },
        ],
      },
      {
        type: "shot",
        src: `${ASSET}/manny-foods-live.jpg`,
        fr: "Exemple live @mannyprcs — format 03, caption App Store, réponses en commentaire.",
        en: "Live @mannyprcs example — format 03, App Store caption, replies in comments.",
      },
      {
        type: "callout",
        fr: "Overview : clics, leads, ventes. Si les vues montent et les leads restent à 0, le pin n’est pas là.",
        en: "Overview: clicks, leads, sales. If views climb and leads stay at 0, the pin isn't there.",
      },
      { type: "cta-links" },
    ],
  },
  {
    id: "primes",
    index: 9,
    title: { fr: "Primes et exemples", en: "Bonuses and examples" },
    nav: { fr: "8. Primes", en: "8. Bonuses" },
    kicker: { fr: "En plus des 40 %", en: "On top of 40%" },
    blocks: [
      {
        type: "lead",
        fr: `Les paliers se cumulent sur une même vidéo, jusqu’à $${VIEW_BONUS_MAX_PER_VIDEO_USD}. Review manuelle : tu envoies le lien TikTok à leks.`,
        en: `Tiers stack on the same video, up to $${VIEW_BONUS_MAX_PER_VIDEO_USD}. Manual review: send the TikTok link to leks.`,
      },
      { type: "bonus" },
      {
        type: "steps",
        title: { fr: "Comment claim", en: "How to claim" },
        items: [
          step("Le post doit parler de Process (scan, protocole, app).", "The post has to be about Process (scan, protocol, app)."),
          step("Éligibilité track primes : 500k+ vues / 28 jours et 5+ vidéos Process.", "Bonus-track eligibility: 500k+ views / 28 days and 5+ Process videos."),
          step("DM leks sur X avec l’URL TikTok dès qu’un palier est hit (40k, 100k, 500k, 1M).", "DM leks on X with the TikTok URL as soon as a tier is hit (40k, 100k, 500k, 1M)."),
        ],
      },
      {
        type: "links",
        items: [
          {
            id: "leks",
            href: AFFILIATE_X_DM_URL,
            fr: "Envoyer un palier à leks",
            en: "Send a tier to leks",
          },
          {
            id: "manny",
            href: MANNY_TIKTOK_URL,
            fr: `Exemples live · ${MANNY_TIKTOK_HANDLE}`,
            en: `Live examples · ${MANNY_TIKTOK_HANDLE}`,
          },
        ],
      },
      {
        type: "examples",
        items: [
          {
            format: "01",
            hook: { fr: "visage gonflé ? fais ça 72h", en: "puffy face? do this for 72h" },
            why: {
              fr: "Before/after + scan dans la grille. Le viewer veut le protocole → lien bio.",
              en: "Before/after + scan in the grid. The viewer wants the protocol → bio link.",
            },
            src: `${ASSET}/format-01/hook.jpg`,
          },
          {
            format: "02",
            hook: { fr: "Comment glow up (méthode Damson)", en: "How to glow up (Damson method)" },
            why: {
              fr: "Visage connu + tips concrets. La dernière slide = Process.",
              en: "Known face + concrete tips. Last slide = Process.",
            },
            src: `${ASSET}/format-02/hook.jpg`,
          },
          {
            format: "03",
            hook: { fr: "Tous les aliments full debloat sont sur l'app", en: "Every full debloat food is in the app" },
            why: {
              fr: "Caption App Store + réponses en commentaire. C’est le post @mannyprcs à copier.",
              en: "App Store caption + replies in comments. This is the @mannyprcs post to copy.",
            },
            src: `${ASSET}/manny-foods-live.jpg`,
          },
          {
            format: "04",
            hook: { fr: "Comment être mieux dès aujourd’hui", en: "How to look better starting today" },
            why: {
              fr: "Cause → effet. Debloat gagne contre l’eau de coco.",
              en: "Cause → effect. Debloat wins against coconut water.",
            },
            src: `${ASSET}/format-04/hook.jpg`,
          },
          {
            format: "05",
            hook: { fr: "Debloat > eau de coco", en: "Debloat > coconut water" },
            why: {
              fr: "Comparaison. Le gagnant visuel = screen Process.",
              en: "Comparison. Visual winner = Process screen.",
            },
            src: `${ASSET}/format-05/debloat.jpg`,
          },
        ],
      },
    ],
  },
];

export function moduleByQuery(raw) {
  const value = String(raw || "").trim();
  if (!value) return METHOD_MODULES[0];
  return (
    METHOD_MODULES.find((mod) => String(mod.index) === value || mod.id === value) ||
    METHOD_MODULES[0]
  );
}

export function fillVars(text, vars) {
  return String(text || "").replace(/\{(\w+)\}/g, (_, key) => {
    const value = vars?.[key];
    return value == null || value === "" ? "" : String(value);
  });
}
