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

const METHOD_QUERY_ALIASES = {
  hub: "devenir",
  accueil: "devenir",
  home: "devenir",
  "1": "devenir",
  primes: "devenir",
  "9": "devenir",
  shadowban: "original",
  techniques: "convertir",
  convertir: "convertir",
};

export const METHOD_MODULES = [
  {
    id: "devenir",
    index: 0,
    nav: { fr: "Intro", en: "Intro" },
    blocks: [
      {
        type: "section",
        title: { fr: "Process c’est quoi ?", en: "What is Process?" },
        fr: "Process est une app iOS (Android arrive bientôt) qui scanne le visage, mesure la rétention d’eau, et construit un protocole pour dégonfler. C’est du looksmaxxing : n’importe qui intéressé par le looksmax est un client potentiel.",
        en: "Process is an iOS app (Android coming soon) that scans the face, measures water retention, and builds a protocol to depuff. This is looksmaxxing: anyone into looksmax is a potential customer.",
      },
      {
        type: "section",
        title: { fr: "Bénéfice pour l’utilisateur", en: "Benefit for the user" },
        fr: "Process permet aux users de tracker…",
        en: "Process lets users track…",
      },
      {
        type: "bullets",
        items: [
          step("Le visage via scan", "The face via scan"),
          step("L’alimentation", "Food"),
          step("L’hydratation", "Hydration"),
          step("L’effort du jour (via Apple Santé)", "Daily effort (via Apple Health)"),
          step("L’évolution du bloating", "Bloating progress"),
        ],
      },
      {
        type: "section",
        fr: "Ça permet d’éliminer la rétention d’eau et la lymphe bloquée, et de passer d’un visage puffy / bouffi à un visage plus défini : joues creuses, jawline, pommettes.",
        en: "That lets them clear water retention and blocked lymph, and go from a puffy / swollen face to a more defined one: hollow cheeks, jawline, cheekbones.",
      },
      {
        type: "ladder",
        title: { fr: "Rémunération", en: "Pay" },
      },
      {
        type: "access",
        title: { fr: "Ton lien", en: "Your link" },
        fr: "{link}",
        en: "{link}",
      },
    ],
  },
  {
    id: "slideshow",
    index: 2,
    title: { fr: "Clipper", en: "Clipper" },
    nav: { fr: "Clipper", en: "Clipper" },
    blocks: [
      {
        type: "bullets",
        title: { fr: "Un bon clipper sait :", en: "A good clipper knows:" },
        items: [
          step("Ne pas être shadowban.", "How to stay off shadowban."),
          step("Poster 4× / jour par compte.", "Post 4× / day per account."),
          step("Être régulier sur le long terme.", "How to stay consistent long-term."),
          step("Faire des slideshows viraux (pas des carousels de merde).", "How to make viral slideshows (not trash carousels)."),
        ],
      },
      {
        type: "bullets",
        title: { fr: "Un bon clipper obtient :", en: "A good clipper gets:" },
        items: [
          step("Entre 500 et 2 000 € par mois.", "€500–€2,000 a month."),
          step("Une compétence qui lui servira toute sa vie.", "A skill that lasts a lifetime."),
          step("La méthode complète pour distribuer ce qu’il veut.", "The full method to distribute whatever they want."),
          step("Des bonus de fou avec Process.", "Insane bonuses with Process."),
          step("La liberté de vivre de l’affiliation.", "The freedom to live off affiliation."),
        ],
      },
      {
        type: "links",
        title: { fr: "Exemples de bons clippers :", en: "Examples of good clippers:" },
        items: [
          {
            id: "manny",
            href: MANNY_TIKTOK_URL,
            fr: MANNY_TIKTOK_HANDLE,
            en: MANNY_TIKTOK_HANDLE,
          },
        ],
      },
    ],
  },
  {
    id: "compte",
    index: 3,
    title: { fr: "Créer + warm", en: "Create + warm" },
    nav: { fr: "Créer + warm", en: "Create + warm" },
    blocks: [
      {
        type: "steps",
        title: { fr: "Créer son compte (3 minutes)", en: "Create your account (3 minutes)" },
        items: [
          step("Créer un compte TikTok, Instagram et YouTube.", "Create a TikTok, Instagram, and YouTube account."),
          step("Mettre un nom avec un mot clé looksmax : glowup_man, debloat_prime, New_looksmax…", "Pick a name with a looksmax keyword: glowup_man, debloat_prime, New_looksmax…"),
          step("Mettre une photo de profil bord coloré (rouge, bleu, vert).", "Use a profile photo with a colored border (red, blue, green)."),
          step(
            "Changer la bio : J’ai découvert Process Debloat dans l’App Store et j’ai glow up.",
            "Change the bio: I discovered Process Debloat on the App Store and I glow’d up."
          ),
        ],
      },
      {
        type: "steps",
        title: { fr: "Chauffer son compte (2 jours)", en: "Warm up the account (2 days)" },
        items: [
          step(
            "Taper « debloat face », « glow up », « looksmax » dans la barre de recherche.",
            "Search “debloat face”, “glow up”, “looksmax” in the search bar."
          ),
          step("Regarder, liker et commenter pendant 15 min.", "Watch, like, and comment for 15 min."),
          step("Mettre des vidéos dans les brouillons.", "Put videos in drafts."),
          step("Scroller dans les Pour toi plusieurs fois par jour pendant 2 jours.", "Scroll For You several times a day for 2 days."),
          step("Poster 1 fois par jour MAX pendant 7 jours.", "Post 1 time a day MAX for 7 days."),
          step("Poster 2 fois par jour la deuxième semaine.", "Post 2 times a day the second week."),
          step("Poster un maximum.", "Post as much as possible."),
        ],
      },
    ],
  },
  {
    id: "original",
    index: 4,
    title: { fr: "Shadowban", en: "Shadowban" },
    nav: { fr: "Shadowban", en: "Shadowban" },
    blocks: [
      {
        type: "section",
        fr: "Si tu as ce message quand tu cliques sur « Plus de données », ta vidéo est shadowban.",
        en: "If you see this message when you tap “More data”, your video is shadowbanned.",
      },
      {
        type: "shot",
        variant: "banner",
        hideCaption: true,
        src: `${ASSET}/shadowban-fyp.png`,
        fr: "Cette vidéo n’est pas éligible à la recommandation dans le fil Pour toi.",
        en: "This video isn’t eligible for recommendation in the For You feed.",
      },
      {
        type: "section",
        fr: "Mais parfois tu n’as pas de message. Si tu fais moins de 50 vues, tu es shadowban.",
        en: "Sometimes there’s no message. If you get under 50 views, you’re shadowbanned.",
      },
      {
        type: "steps",
        title: { fr: "Les raisons d’un shadowban ?", en: "Why does a shadowban happen?" },
        items: [
          step("Tu n’as pas (assez) chauffé ton compte.", "You didn’t warm up the account (enough)."),
          step("Tu postes des slideshows full IA.", "You post full-AI slideshows."),
          step("Tu as posté beaucoup de slideshows en peu de temps.", "You posted a lot of slideshows in a short time."),
        ],
      },
      {
        type: "steps",
        title: { fr: "Comment ne pas être shadowban", en: "How not to get shadowbanned" },
        items: [
          step("Si tu es shadowban, ARRÊTE DE POSTER pendant 2 jours.", "If you’re shadowbanned, STOP POSTING for 2 days."),
          step("Scroll et like 15 min / jour.", "Scroll and like 15 min / day."),
          step("Va sur TikTok Shop.", "Go to TikTok Shop."),
          step("Ajoute des articles au panier.", "Add items to the cart."),
          step("Mets toutes tes infos jusqu’au paiement.", "Fill in all your info up to checkout."),
          step("Relance l’app TikTok.", "Relaunch the TikTok app."),
          step("Continue de scroller.", "Keep scrolling."),
          step("Remplis toutes les vérifications d’identité (numéro, email…).", "Complete every identity check (phone, email…)."),
          step("Poste 1 slideshow au bout de 3 jours.", "Post 1 slideshow after 3 days."),
        ],
      },
    ],
  },
  {
    id: "viral",
    index: 5,
    title: { fr: "Slideshow viraux", en: "Viral slideshows" },
    nav: { fr: "Viral", en: "Viral" },
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
        fr: "Dès qu’un post passe 40k, tu le dupliques : même hook, nouvel angle, nouvelles photos. Toutes les vidéos du compte comptent pour les primes — le volume de hits accélère le palier.",
        en: "When a post clears 40k, duplicate it: same hook, new angle, new photos. Every video on the account counts toward bonuses — more hits, faster tiers.",
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
    nav: { fr: "Poster", en: "Post" },
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
    title: { fr: "Techniques", en: "Techniques" },
    nav: { fr: "Techniques", en: "Techniques" },
    blocks: [
      {
        type: "bullets",
        items: [
          step(
            "Ne jamais télécharger ses posts pour les reposter. TikTok reconnaît le fichier → shadowban.",
            "Never download your posts to repost them. TikTok recognizes the file → shadowban."
          ),
          step(
            "Varier entre 4 formats différents minimum.",
            "Rotate across 4 different formats minimum."
          ),
          step(
            "Les sons sont très importants : démarre toujours un TikTok à partir d’un son qui a déjà percé sur un autre TikTok.",
            "Sounds matter a lot: always start a TikTok from a sound that already blew up on another TikTok."
          ),
          step(
            "Le contenu marqué « généré par IA » est moins mis en avant. Passe en anti-IA : crée un script avec Claude.",
            "Content labeled “AI generated” gets less push. Go anti-AI: write a script with Claude."
          ),
          step(
            "5 min après le post, commente avec un autre compte « C’est quoi l’app ? » — et réponds avec un screen App Store.",
            "5 min after posting, comment from another account “what’s the app?” — and reply with an App Store screenshot."
          ),
          step(
            "Mets un sondage en commentaire : « Tu vas télécharger Process ? » — OUI et OUI.",
            "Put a poll in the comments: “Are you going to download Process?” — YES and YES."
          ),
          step(
            "8 comptes MAXIMUM par téléphone. Au-dessus de 5 comptes, poste en 5G. 5 comptes sur le même Wi-Fi se font shadowban facilement.",
            "8 accounts MAXIMUM per phone. Above 5 accounts, post on 5G. 5 accounts on the same Wi-Fi get shadowbanned easily."
          ),
        ],
      },
    ],
  },
];

export function moduleByQuery(raw) {
  const incoming = String(raw || "").trim().toLowerCase();
  const value = METHOD_QUERY_ALIASES[incoming] || incoming;
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
