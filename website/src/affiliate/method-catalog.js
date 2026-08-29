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
    id: "06",
    name: { fr: "06 — Grille 2×2", en: "06 — 2×2 grid" },
    canvas: "1080×1440",
    when: {
      fr: "Quand tu veux du volume sans tourner. 4 photos + une ligne, c'est tout.",
      en: "When you want volume without filming. 4 photos + one line, that's it.",
    },
    hook: {
      fr: "Glow up tips for men",
      en: "Glow up tips for men",
    },
    caption: {
      fr: "Glow up tips for men\n\n#glowup #glowuptips #selfimprovement #menglowup #fyp",
      en: "Glow up tips for men\n\n#glowup #glowuptips #selfimprovement #menglowup #fyp",
    },
    fatal: {
      fr: "Canvas 1080×1440, pas 1080×1920. Et AUCUNE bordure entre les 4 photos.",
      en: "Canvas 1080×1440, not 1080×1920. And NO border between the 4 photos.",
    },
    slides: [
      { src: `${ASSET}/format-06/hook.jpg`, fr: "Hook — grille + titre", en: "Hook — grid + title" },
      { src: `${ASSET}/format-06/tip.jpg`, fr: "Tip sur la couture", en: "Tip on the seam" },
      { src: `${ASSET}/format-06/grid.jpg`, fr: "Tip suivant", en: "Next tip" },
    ],
    structure: [
      { fr: "1. Grille 2×2 seamless + le titre du carrousel sur la couture", en: "1. Seamless 2×2 grid + carousel title on the seam" },
      { fr: "2–N. Un tip par slide, même grille, une seule ligne", en: "2–N. One tip per slide, same grid, a single line" },
      { fr: "Texte : TikTok Sans SemiBold, blanc, contour noir fin", en: "Text: TikTok Sans SemiBold, white, thin black outline" },
      { fr: "Filtre : sombre, chaud, désaturé (mesuré sur 51 slides)", en: "Filter: dark, warm, desaturated (measured across 51 slides)" },
      { fr: "Générer : generate_format06_catalogue.py", en: "Generate: generate_format06_catalogue.py" },
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
          step("1 compte actif → autour de 500 $ / mois.", "1 active account → around $500 / month."),
          step("5 comptes actifs → autour de 2 000 $ / mois.", "5 active accounts → around $2,000 / month."),
          step("Une compétence qui lui servira toute sa vie.", "A skill that lasts a lifetime."),
          step("La méthode complète pour distribuer ce qu’il veut.", "The full method to distribute whatever they want."),
          step("Des bonus de fou avec Process.", "Insane bonuses with Process."),
          step("La liberté de vivre du clipping.", "The freedom to live off clipping."),
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
          step("Looksmaxxing : ajoute #looksmaxxing", "Looksmaxxing: add #looksmaxxing"),
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
          step("Recadrage : 9:16. Ne pas zoomer le texte.", "Crop: 9:16. Don't zoom into the text."),
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
            "Varier entre les 3 formats.",
            "Rotate across the 3 formats."
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

const START_QUERY_ALIASES = {
  devenir: "produit",
  hub: "produit",
  accueil: "produit",
  home: "produit",
  intro: "produit",
  "0": "produit",
  "1": "produit",
  product: "produit",
  primes: "paye",
  pay: "paye",
  paye: "paye",
  "2": "paye",
  "9": "paye",
  slideshow: "slideshows",
  viral: "slideshows",
  poster: "slideshows",
  carousel: "slideshows",
  carousels: "slideshows",
  clipper: "cent",
  clipping: "cent",
  vend: "cent",
  sell: "cent",
  original: "cent",
  convertir: "cent",
  "3": "cent",
  "100": "cent",
  cent: "cent",
  compte: "comptes",
  comptes: "comptes",
  tiktok: "comptes",
  accounts: "comptes",
  iphone: "comptes",
  "4": "comptes",
  "8": "comptes",
  warmup: "warmup",
  warm: "warmup",
  chauffe: "warmup",
  "5": "warmup",
  slideshows: "slideshows",
  "6": "slideshows",
  resultats: "resultats",
  résultats: "resultats",
  results: "resultats",
  attendre: "resultats",
};

export const START_SECTIONS = [
  {
    id: "produit",
    nav: { fr: "Le produit qu'on vend", en: "The product we sell" },
    title: { fr: "Le produit qu'on vend", en: "The product we sell" },
    blocks: [
      {
        type: "section",
        fr: "Process est une app iOS (Android arrive bientôt). Elle scanne le visage, mesure la rétention d'eau, et construit un protocole pour dégonfler. Ce n'est pas une app skincare générique : c'est du looksmaxxing. Quiconque veut un visage plus net — joues, jawline, pommettes — est un client.",
        en: "Process is an iOS app (Android is coming). It scans the face, measures water retention, and builds a protocol to depuff. This isn't a generic skincare app: it's looksmaxxing. Anyone who wants a sharper face — cheeks, jawline, cheekbones — is a customer.",
      },
      {
        type: "bullets",
        title: { fr: "Ce que l'app tracke", en: "What the app tracks" },
        items: [
          step("Le visage, via le scan", "The face, via the scan"),
          step("L'alimentation", "Food"),
          step("L'hydratation", "Hydration"),
          step("L'effort du jour (Apple Santé)", "Daily effort (Apple Health)"),
          step("L'évolution du bloating", "Bloating progress"),
        ],
      },
      {
        type: "section",
        title: { fr: "Le résultat", en: "The result" },
        fr: "Ça vide la rétention d'eau et la lymphe bloquée. On passe d'un visage puffy / bouffi à un visage plus défini. Le protocole est quotidien : glace, cardio, alim, sauna — cadencé par l'app, pas par un thread Twitter.",
        en: "It clears water retention and blocked lymph. You go from a puffy / swollen face to a more defined one. The protocol is daily: ice, cardio, food, sauna — paced by the app, not a Twitter thread.",
      },
      {
        type: "callout",
        fr: "Tu ne vends pas « une app ». Tu vends un glow-up visage. Tes slideshows doivent parler de ça : debloat, looksmax, avant/après — pas de Process en pub.",
        en: "You're not selling “an app”. You're selling a face glow-up. Your slideshows should talk about that: debloat, looksmax, before/after — not Process as an ad.",
      },
    ],
  },
  {
    id: "paye",
    nav: { fr: "Combien vous êtes payé", en: "How much you get paid" },
    title: { fr: "Combien vous êtes payé", en: "How much you get paid" },
    blocks: [
      {
        type: "section",
        fr: "Tu es payé 40 % du net sur chaque vente, à vie, tant que l'abonnement reste actif. Pas de plafond. Les virements passent par Stripe, vers ton compte. Les commissions sont retenues 30 jours, puis disponibles au payout.",
        en: "You get paid 40% of the net on every sale, for life, as long as the subscription stays active. No cap. Payouts go through Stripe, to your account. Commissions are held 30 days, then available to withdraw.",
      },
      {
        type: "callout",
        fr: "Chaque abo que tu génères te rapporte chaque semaine, automatiquement, tant qu'il ne se désabonne pas. Tu scales avec le volume — pas avec une seule vidéo.",
        en: "Every sub you generate pays you every week, automatically, until they cancel. You scale with volume — not with one video.",
      },
      {
        type: "ladder",
        title: { fr: "En plus des 40 %", en: "On top of the 40%" },
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
    id: "cent",
    nav: { fr: "Comment on vend", en: "How we sell" },
    title: { fr: "Comment on vend", en: "How we sell" },
    blocks: [
      {
        type: "section",
        title: { fr: "Clipping", en: "Clipping" },
        fr: "La réponse, c'est le clipping. Ça consiste à automatiser des slideshows TikTok : tu copies une structure qui convertit — pas une vidéo 1:1 — tu postes en volume, ton lien clipper va dans la bio et le commentaire épinglé. Pas besoin de te filmer. Les slideshows se montent, se dupliquent, se postent.",
        en: "The answer is clipping. That means automating TikTok slideshows: you copy a structure that converts — not a 1:1 video — you post in volume, your clipper link goes in the bio and the pinned comment. You don't need to film yourself. Slideshows get built, duplicated, posted.",
      },
      {
        type: "callout",
        fr: "SlideshowLab pour monter. Format pour copier les exemples qui marchent. C'est ça, vendre Process.",
        en: "SlideshowLab to build. Format to copy the examples that work. That's how you sell Process.",
      },
      {
        type: "cta-lab",
      },
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
          step("1 compte actif → autour de 500 $ / mois.", "1 active account → around $500 / month."),
          step("5 comptes actifs → autour de 2 000 $ / mois.", "5 active accounts → around $2,000 / month."),
          step("Une compétence qui lui servira toute sa vie.", "A skill that lasts a lifetime."),
          step("La méthode complète pour distribuer ce qu'il veut.", "The full method to distribute whatever they want."),
          step("Des bonus de fou avec Process.", "Insane bonuses with Process."),
          step("La liberté de vivre du clipping.", "The freedom to live off clipping."),
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
      {
        type: "steps",
        title: { fr: "Le rythme", en: "The pace" },
        items: [
          step("Compte looksmax (glowup_man, debloat_prime…). Photo de profil avec un bord coloré. Bio : tu as découvert Process Debloat sur l'App Store et tu as glow up.", "Looksmax account (glowup_man, debloat_prime…). Profile photo with a colored border. Bio: you found Process Debloat on the App Store and you glow'd up."),
          step("Chauffe 2 jours : cherche debloat / glow up / looksmax, like, commente, scrolle. 1 post / jour max la première semaine.", "Warm up 2 days: search debloat / glow up / looksmax, like, comment, scroll. 1 post / day max the first week."),
          step("Ensuite : 4 posts / jour par compte. Varie entre les 3 formats (Guide 72h, Glow-up, Foods).", "Then: 4 posts / day per account. Rotate the 3 formats (72h guide, Glow-up, Foods)."),
        ],
      },
      {
        type: "steps",
        title: { fr: "Ce qui convertit", en: "What converts" },
        items: [
          step("Sans pin + bio, tu fais des vues pour TikTok, pas pour Process.", "Without pin + bio, you're making views for TikTok, not Process."),
          step("Commentaire épinglé : {link} · code {code}.", "Pinned comment: {link} · code {code}."),
          step("5 min après le post, un autre compte commente « C'est quoi l'app ? » — tu réponds avec un screen App Store.", "5 min after posting, another account comments “what's the app?” — you reply with an App Store screenshot."),
          step("Sondage en commentaire : « Tu vas télécharger Process ? » — OUI et OUI.", "Poll in the comments: “Are you going to download Process?” — YES and YES."),
          step("Dès qu'un post passe 40k, tu le dupliques : même hook, nouvel angle, nouvelles photos.", "When a post clears 40k, duplicate it: same hook, new angle, new photos."),
        ],
      },
      {
        type: "dont",
        title: { fr: "À ne pas faire", en: "Don't" },
        items: [
          step("Télécharger tes posts pour les reposter. TikTok reconnaît le fichier → shadowban.", "Download your posts to repost them. TikTok recognizes the file → shadowban."),
          step("Slideshows full IA, ou contenu marqué « généré par IA ».", "Full-AI slideshows, or content labeled “AI generated”."),
          step("Poster 20 slideshows le premier jour sans avoir chauffé.", "Post 20 slideshows on day one without a warmup."),
          step("Pub payante. Les commissions ne seront pas versées.", "Paid ads. Commissions won't be paid."),
        ],
      },
      {
        type: "cta-formats",
      },
    ],
  },
  {
    id: "comptes",
    nav: { fr: "Créer ses comptes TikTok", en: "Create your TikTok accounts" },
    title: { fr: "Créer ses comptes TikTok", en: "Create your TikTok accounts" },
    blocks: [
      {
        type: "section",
        fr: "Tu crées tes comptes toi-même. Pas tous le même jour : un compte trop proche de l'autre sur le même iPhone, TikTok les lie et les shadowban. Espace-les. 1 nouveau compte par semaine, avec quelques jours d'intervalle.",
        en: "You create your own accounts. Not all on the same day: accounts opened too close together on the same iPhone get linked and shadowbanned. Space them out. 1 new account per week, a few days apart.",
      },
      {
        type: "steps",
        title: { fr: "Le rythme", en: "The pace" },
        items: [
          step("1 nouveau compte TikTok par semaine. Pas 3 le lundi.", "1 new TikTok account per week. Not 3 on Monday."),
          step("Quelques jours d'intervalle entre chaque création — même si tu as le temps d'en faire plus.", "A few days between each creation — even if you have time to make more."),
          step("Chauffe le nouveau compte avant d'en ouvrir un autre (scroll, like, 1 post / jour la première semaine).", "Warm up the new account before opening another (scroll, like, 1 post / day the first week)."),
        ],
      },
      {
        type: "callout",
        fr: "Maximum 8 comptes TikTok par iPhone. Au-delà, TikTok shadowban — souvent plusieurs comptes d'un coup, pas juste le 9e.",
        en: "8 TikTok accounts max per iPhone. Past that, TikTok shadowbans — often several accounts at once, not just the 9th.",
      },
      {
        type: "section",
        title: { fr: "Les comptes déjà créés comptent", en: "Accounts you already made count" },
        fr: "Si tu as déjà créé des comptes TikTok sur cet iPhone — perso, tests, vieux @, comptes que tu n'utilises plus — ils rentrent dans les 8. Un compte créé sur cet iPhone = 1 slot. Tu n'as pas 8 slots Process en plus : tu as 8 moins ceux qui existent déjà.",
        en: "If you already created TikTok accounts on this iPhone — personal, tests, old @s, accounts you don't use anymore — they count toward the 8. An account created on this iPhone = 1 slot. You don't get 8 extra Process slots: you get 8 minus the ones already there.",
      },
      {
        type: "dont",
        title: { fr: "À ne pas faire", en: "Don't" },
        items: [
          step("Créer 8 comptes d'un coup « pour être prêt ». Ils tombent ensemble.", "Create 8 accounts at once “to be ready”. They fall together."),
          step("Oublier un vieux compte perso dans le décompte. TikTok, lui, ne l'oublie pas.", "Forget an old personal account in the count. TikTok doesn't."),
          step("Passer 8 en se disant que « ça ira ». Ça shadowban les comptes.", "Go past 8 and tell yourself it'll be fine. It shadowbans the accounts."),
        ],
      },
      {
        type: "steps",
        title: { fr: "Quand tu crées le compte", en: "When you create the account" },
        items: [
          step("Nom avec un mot-clé looksmax : glowup_man, debloat_prime, New_looksmax…", "Name with a looksmax keyword: glowup_man, debloat_prime, New_looksmax…"),
          step("Photo de profil avec un bord coloré (rouge, bleu, vert).", "Profile photo with a colored border (red, blue, green)."),
          step("Bio : tu as découvert Process Debloat sur l'App Store et tu as glow up.", "Bio: you found Process Debloat on the App Store and you glow'd up."),
        ],
      },
    ],
  },
  {
    id: "warmup",
    nav: { fr: "Comment warm up", en: "How to warm up" },
    title: { fr: "Comment warm up", en: "How to warm up" },
    blocks: [
      {
        type: "section",
        fr: "Un compte neuf que tu bombes de slideshows le premier jour se fait shadowban. Le warm up, c'est faire croire à TikTok que c'est un vrai compte looksmax : tu scrolles, tu likes, tu commentes — puis tu postes doucement.",
        en: "A fresh account you flood with slideshows on day one gets shadowbanned. Warm up is making TikTok believe it's a real looksmax account: you scroll, like, comment — then you post slowly.",
      },
      {
        type: "steps",
        title: { fr: "Jour 1 et 2 — chauffer sans poster", en: "Day 1 and 2 — warm up without posting" },
        items: [
          step("Taper « debloat face », « glow up », « looksmax » dans la recherche.", "Search “debloat face”, “glow up”, “looksmax”."),
          step("Regarder, liker et commenter 15 min.", "Watch, like, and comment for 15 min."),
          step("Scroller le Pour toi plusieurs fois dans la journée.", "Scroll For You several times during the day."),
          step("Mettre des slideshows dans les brouillons — tu ne les publies pas encore.", "Put slideshows in drafts — don't publish them yet."),
        ],
      },
      {
        type: "steps",
        title: { fr: "Ensuite — monter le volume", en: "Then — ramp the volume" },
        items: [
          step("Semaine 1 : 1 post / jour MAX.", "Week 1: 1 post / day MAX."),
          step("Semaine 2 : 2 posts / jour.", "Week 2: 2 posts / day."),
          step("Ensuite : 4 posts / jour par compte.", "Then: 4 posts / day per account."),
        ],
      },
      {
        type: "callout",
        fr: "Poster via API, ce n'est pas le problème. Le compte que tu ne vis jamais, lui, se fait griller. Chaque jour : rentre dans le compte, like, commente, sondage, scrolle.",
        en: "Posting via API isn't the problem. An account you never live in gets burned. Every day: go into the account, like, comment, poll, scroll.",
      },
      {
        type: "dont",
        title: { fr: "À ne pas faire", en: "Don't" },
        items: [
          step("Poster 20 slideshows le premier jour.", "Post 20 slideshows on day one."),
          step("Sauter le warm up parce que « le format est bon ».", "Skip warm up because “the format is good”."),
          step("Créer un compte et le laisser mort 3 semaines, puis tout poster d'un coup.", "Create an account, leave it dead for 3 weeks, then dump everything at once."),
        ],
      },
    ],
  },
  {
    id: "slideshows",
    nav: { fr: "Le format slideshow", en: "The slideshow format" },
    title: { fr: "Le format slideshow", en: "The slideshow format" },
    blocks: [
      {
        type: "section",
        fr: "On ne se filme pas. On poste des slideshows TikTok (Photo Mode) : une suite de slides 9:16, un hook en 1 seconde, une promesse par post. Tu copies une structure qui convertit — pas une vidéo 1:1. SlideshowLab pour monter. Format pour voir les exemples qui marchent.",
        en: "We don't film ourselves. We post TikTok slideshows (Photo Mode): a sequence of 9:16 slides, a 1-second hook, one promise per post. You copy a structure that converts — not a 1:1 video. SlideshowLab to build. Format to see the examples that work.",
      },
      {
        type: "steps",
        title: { fr: "Ce qui fait scroller", en: "What makes people swipe" },
        items: [
          step("Hook slide = 1 idée. Le viewer comprend en 1 seconde ce qu'il gagne.", "Hook slide = 1 idea. The viewer gets the payoff in one second."),
          step("Une promesse par carousel. Pas un mélange glow-up + recette + POV.", "One promise per carousel. Don't mix glow-up + recipe + POV."),
          step("Son tendance OK, collé à l'émotion — pas un son random.", "Trending sound is OK if it matches the emotion — not a random track."),
          step("Caption = 1 ligne + hashtags. Le CTA est le lien, pas un script d'ads.", "Caption = 1 line + hashtags. The CTA is the link, not an ads script."),
        ],
      },
      {
        type: "section",
        title: { fr: "Les 3 formats officiels", en: "The 3 official formats" },
        fr: `Référence : ${MANNY_TIKTOK_HANDLE}. Tu copies la structure, pas les fichiers.`,
        en: `Reference: ${MANNY_TIKTOK_HANDLE}. Copy the structure, not the files.`,
      },
      {
        type: "formats",
      },
      {
        type: "steps",
        title: { fr: "Comment poster", en: "How to post" },
        items: [
          step("TikTok → + → Photo (pas Vidéo).", "TikTok → + → Photo (not Video)."),
          step("Importer les JPG dans l'ordre slide_01, slide_02, … Recadrage 9:16, ne pas zoomer le texte.", "Import the JPGs in order slide_01, slide_02, … Crop 9:16, don't zoom into the text."),
          step("Ne re-tape pas le texte. Il est déjà sur l'image.", "Don't retype the text. It's already on the image."),
          step("Commentaire : {link} · code {code} — puis épingler. Sans pin + bio, tu fais des vues pour TikTok, pas pour Process.", "Comment: {link} · code {code} — then pin it. Without pin + bio, you're making views for TikTok, not Process."),
        ],
      },
      {
        type: "cta-lab",
      },
      {
        type: "cta-formats",
      },
    ],
  },
  {
    id: "resultats",
    nav: { fr: "Les résultats à attendre", en: "Results to expect" },
    title: { fr: "Les résultats à attendre", en: "Results to expect" },
    blocks: [
      {
        type: "section",
        fr: "Si ton compte est déjà chauffé, tes premières ventes peuvent arriver dès ce soir. Sinon, compte ~3 jours pour le warm up — puis tu postes. Ce qui suit, c'est du volume et un lien qui convertit.",
        en: "If your account is already warmed up, your first sales can land tonight. If not, give it ~3 days to warm — then you post. After that, it's volume and a link that converts.",
      },
      {
        type: "steps",
        title: { fr: "Le déroulé", en: "How it plays out" },
        items: [
          step("Compte déjà chaud : tu postes aujourd'hui, premières ventes possibles dès ce soir.", "Account already warm: you post today — first sales possible tonight."),
          step("Compte neuf : ~3 jours de warm up, puis tu montes le rythme.", "Fresh account: ~3 days of warm-up, then you ramp."),
          step("Dès qu'un post passe 40k : tu le dupliques — même hook, nouvel angle, nouvelles photos.", "When a post clears 40k: you duplicate it — same hook, new angle, new photos."),
        ],
      },
      {
        type: "bullets",
        title: { fr: "Ce que ça peut donner", en: "What it can look like" },
        items: [
          step("1 compte actif, bien tenu → autour de 500 $ / mois.", "1 active account, run well → around $500 / month."),
          step("5 comptes actifs → autour de 2 000 $ / mois.", "5 active accounts → around $2,000 / month."),
          step("Des primes en plus des 40 %, dès que les vues s'accumulent.", "Bonuses on top of the 40%, as views stack."),
          step("Une compétence qui reste : poster des slideshows qui convertissent.", "A skill that stays: posting slideshows that convert."),
        ],
      },
      {
        type: "ladder",
        title: { fr: "Les primes vues", en: "View bonuses" },
      },
      {
        type: "callout",
        fr: "Ce n'est pas une vidéo miracle — c'est un rythme. Tu construis compte par compte, et les abos qui restent te paient chaque semaine.",
        en: "This isn't one miracle video — it's a rhythm. You build account by account, and the subs that stay pay you every week.",
      },
    ],
  },
];

export function startSectionByQuery(raw) {
  const incoming = String(raw || "").trim().toLowerCase();
  const value = START_QUERY_ALIASES[incoming] || incoming;
  if (!value) return START_SECTIONS[0];
  return START_SECTIONS.find((section) => section.id === value) || START_SECTIONS[0];
}

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
