import { appCopy } from "../features/app-copy.js";
import { getIosAppStoreUrl } from "../features/app-store-urls.js";

export const APP_STORE_URL = getIosAppStoreUrl();
export const PROCESS_APP_ICON = "/assets/icone.png?v=20260808";
export const LANDING_MEDIA = "/assets/process-landing";
export const LANDING_FEATURE_ICONS = {
  training: `${LANDING_MEDIA}/icon-training.png`,
  progress: `${LANDING_MEDIA}/icon-progress.png`,
  face3d: `${LANDING_MEDIA}/icon-3d.png`,
  coach: `${LANDING_MEDIA}/icon-coach.png`,
  share: `${LANDING_MEDIA}/icon-share.png`,
  battle: `${LANDING_MEDIA}/icon-battle.png`,
  hub: `${LANDING_MEDIA}/icon-hub.png`,
  routines: `${LANDING_MEDIA}/icon-routines.png`,
};
export const HERO_PHONE_IMAGE = `${LANDING_MEDIA}/phone-hero-app.png?v=20260812b`;
export const BENEFITS_PHONE_IMAGE = `${LANDING_MEDIA}/phone-features-scan.png?v=20260816real`;
export const ONBOARDING_COMMUNITY = "/assets/onboarding-community";

/** Mêmes visages que `TransformationPreviewStepView` (social proof homme). */
export function onboardingCommunityAvatars() {
  return [
    `${ONBOARDING_COMMUNITY}/gars1.png`,
    `${ONBOARDING_COMMUNITY}/leo.png`,
    `${ONBOARDING_COMMUNITY}/estebanprime.png`,
    `${ONBOARDING_COMMUNITY}/lucasprime.png`,
    `${ONBOARDING_COMMUNITY}/imranprime.png`,
    `${ONBOARDING_COMMUNITY}/homme.png`,
  ];
}

export function languageSwitchCopy() {
  return {
    fr: "FR",
    en: "EN",
    aria: appCopy("Choisir la langue", "Choose language"),
  };
}

export function themeSwitchCopy() {
  return {
    dark: appCopy("Activer le mode sombre", "Switch to dark mode"),
    light: appCopy("Activer le mode clair", "Switch to light mode"),
  };
}

export function chromeAriaCopy() {
  return {
    menu: appCopy("Menu", "Menu"),
    mainNav: appCopy("Navigation principale", "Main navigation"),
    footerNav: appCopy("Pied de page", "Footer"),
    appStoreBadge: appCopy("Télécharger sur App Store", "Download on App Store"),
    processIcon: appCopy("Process", "Process"),
  };
}

export function navLinks() {
  return [
    { id: "benefits", label: appCopy("Avantages", "Benefits") },
    { id: "features", label: appCopy("Fonctionnalités", "Features") },
    { id: "testimonial", label: appCopy("Témoignages", "Testimonials") },
    { id: "faq", label: appCopy("FAQ", "FAQ's") },
  ];
}

export function heroCopy() {
  return {
    trustBadge: appCopy("Approuvé par +8500 utilisateurs", "Trusted by +8,500 users"),
    title: appCopy(
      "Téléchargez Process et dégonflez votre visage",
      "Download Process and debloat your face"
    ),
    subtitle: appCopy(
      "Scan 3D, protocole debloat sur mesure et coach IA — mesure ton visage, suis tes progrès et vois la différence.",
      "3D scan, custom debloat protocol, and AI coach — measure your face, track progress, and see the difference."
    ),
    subtitleMobile: appCopy(
      "Scan 3D et protocole debloat personnalisé — des mesures réelles, des progrès visibles.",
      "3D scan and a personalized debloat protocol — real measurements, visible progress."
    ),
    cta: appCopy("Télécharger l'app", "Download App"),
    appAvailable: appCopy("Disponible sur", "App Available on"),
    trustLine: appCopy(
      "Approuvé par +8500 utilisateurs dans le monde",
      "Trusted by +8,500 users across the world"
    ),
    trustAvatars: onboardingCommunityAvatars().slice(0, 3),
  };
}

export function statsCopy() {
  return {
    title: appCopy(
      "Des mesures réelles sur ta rétention faciale.",
      "Real measurements for facial water retention."
    ),
    items: [
      {
        target: 50,
        format: "compact-k",
        label: appCopy("Visages scannés et suivis", "Faces scanned and tracked"),
      },
      {
        target: 1050,
        format: "grouped",
        label: appCopy("Points de données par scan", "Data points captured per scan"),
      },
      {
        target: 850,
        format: "compact-k",
        label: appCopy("Utilisateurs actifs sur leur protocole", "Users following their protocol"),
      },
    ],
  };
}

function processFeatureCard(titleFr, titleEn, bodyFr, bodyEn, icon = PROCESS_APP_ICON) {
  return {
    icon,
    title: appCopy(titleFr, titleEn),
    body: appCopy(bodyFr, bodyEn),
  };
}

export function benefitsCopy() {
  return {
    badge: appCopy("L'app Process", "The Process app"),
    title: appCopy("Coach IA & protocole debloat", "AI coach & debloat protocol"),
    subtitle: appCopy(
      "Scan visage, hydratation, repas debloat et sommeil — un plan anti-rétention concret, pas une app skincare vague.",
      "Face scan, hydration, debloat meals and sleep — a concrete anti-bloat plan, not a vague skincare app."
    ),
    cards: [
      processFeatureCard(
        "Scan debloat quotidien",
        "Daily debloat scan",
        "Rétention, cernes, mâchoire, peau et cortisol estimé — tu vois ce qui gonfle ton visage.",
        "Retention, under-eyes, jawline, skin and estimated cortisol — see what makes your face puffy.",
        LANDING_FEATURE_ICONS.face3d
      ),
      processFeatureCard(
        "Protocole personnalisé",
        "Personalized protocol",
        "Nutrition, hydratation et sommeil adaptés à ton profil pour réduire la rétention d'eau.",
        "Nutrition, hydration and sleep tailored to your profile to reduce water retention.",
        LANDING_FEATURE_ICONS.routines
      ),
      processFeatureCard(
        "Repas debloat",
        "Debloat meals",
        "Idées de repas et analyse photo pour limiter ce qui te fait gonfler.",
        "Meal ideas and photo analysis to limit what makes you bloat.",
        LANDING_FEATURE_ICONS.progress
      ),
      processFeatureCard(
        "Coach IA",
        "AI coach",
        "Conseils actionnables sur ton visage, ton protocole et ta progression debloat.",
        "Actionable advice on your face, protocol and debloat progress.",
        LANDING_FEATURE_ICONS.coach
      ),
    ],
  };
}

export function systemCopy() {
  const systemMedia = `${LANDING_MEDIA}/system`;
  return {
    badge: appCopy("Résultats debloat", "Debloat results"),
    title: appCopy("Avant / après — moins de gonflement facial", "Before / after — less facial puffiness"),
    subtitle: appCopy(
      "Des photos réelles d'utilisateurs Process — scan, protocole et suivi anti-rétention.",
      "Real photos from Process users — scan, protocol and anti-retention tracking."
    ),
    beforeLabel: appCopy("Avant", "Before"),
    afterLabel: appCopy("Après", "After"),
    seeMore: appCopy("Voir encore", "See more"),
    pairs: [
      {
        before: `${systemMedia}/before-tongue.png`,
        after: `${systemMedia}/after-hoodie.png`,
      },
      {
        before: `${systemMedia}/before-profile.png`,
        after: `${systemMedia}/after-led.png`,
      },
    ],
  };
}

export function potentialCopy() {
  return {
    title: appCopy("Tout pour dégonfler ton visage au quotidien", "Everything to debloat your face daily"),
    subtitle: appCopy(
      "Scan, checklist, hydratation, repas et coach IA — le loop debloat complet dans une seule app.",
      "Scan, checklist, hydration, meals and AI coach — the full debloat loop in one app."
    ),
    checklist: [
      appCopy("Scan visage & score de rétention", "Face scan & retention score"),
      appCopy("Protocole debloat personnalisé", "Personalized debloat protocol"),
      appCopy("Hydratation & repas debloat", "Hydration & debloat meals"),
      appCopy("Sommeil & récupération", "Sleep & recovery tracking"),
      appCopy("Coach IA anti-rétention", "Anti-retention AI coach"),
    ],
  };
}

export function testimonialsCopy() {
  const avatars = onboardingCommunityAvatars();
  return {
    title: appCopy("Ils dégonflent avec Process", "They debloat with Process"),
    subtitle: appCopy(
      "Retours d'utilisateurs sur le scan, le protocole debloat et la rétention faciale.",
      "User feedback on scan, debloat protocol and facial retention."
    ),
    items: [
      {
        quote: appCopy(
          "Mon visage était gonflé le matin — le scan m'a montré la rétention et quoi corriger côté hydratation.",
          "My face was puffy every morning — the scan showed retention and what to fix with hydration."
        ),
        name: "Enzo",
        avatar: avatars[1],
      },
      {
        quote: appCopy(
          "Enfin une app debloat avec un vrai protocole repas + eau, pas juste des conseils skincare.",
          "Finally a debloat app with a real meals + water protocol, not just skincare tips."
        ),
        name: "Amir",
        avatar: avatars[2],
      },
      {
        quote: appCopy(
          "Le suivi quotidien m'a aidé à voir ce qui me faisait gonfler — sel, sommeil, repas.",
          "Daily tracking helped me see what made me bloat — salt, sleep, meals."
        ),
        name: "Ken",
        avatar: avatars[3],
      },
      {
        quote: appCopy(
          "Le coach IA répond sur mon protocole debloat, pas des généralités beauté.",
          "The AI coach answers about my debloat protocol, not generic beauty advice."
        ),
        name: "Malik",
        avatar: avatars[4],
      },
      {
        quote: appCopy(
          "Checklist claire le matin : scan, eau, repas — je sais quoi faire.",
          "Clear morning checklist: scan, water, meals — I know what to do."
        ),
        name: "Sam",
        avatar: avatars[0],
      },
      {
        quote: appCopy(
          "Moins de gonflement au bout de deux semaines en suivant le plan Process.",
          "Less puffiness after two weeks following the Process plan."
        ),
        name: "Rayan",
        avatar: avatars[5],
      },
    ],
  };
}

export function faqCopy() {
  return {
    badge: appCopy("FAQ", "FAQ's"),
    title: appCopy("Questions fréquentes", "Frequently Asked Questions"),
    items: [
      {
        q: appCopy("Process, c'est quoi ?", "What is Process?"),
        a: appCopy(
          "Une app iOS debloat : scan visage, protocole anti-rétention (hydratation, repas, sommeil) et coach IA.",
          "An iOS debloat app: face scan, anti-retention protocol (hydration, meals, sleep) and AI coach."
        ),
      },
      {
        q: appCopy("Comment fonctionne le scan ?", "How does the scan work?"),
        a: appCopy(
          "Le scan analyse rétention, cernes, mâchoire et signaux visibles pour te donner un score debloat et des actions.",
          "The scan analyzes retention, under-eyes, jawline and visible signals to give you a debloat score and actions."
        ),
      },
      {
        q: appCopy("Est-ce une app skincare ?", "Is this a skincare app?"),
        a: appCopy(
          "Non — Process cible la rétention d'eau et le gonflement facial via nutrition, hydratation et habitudes, pas des crèmes.",
          "No — Process targets water retention and facial puffiness through nutrition, hydration and habits, not creams."
        ),
      },
      {
        q: appCopy("Comment améliorer mes résultats ?", "How do I improve my results?"),
        a: appCopy(
          "Suis ton protocole quotidien : scan, hydratation, repas debloat et sommeil. Le coach IA t'aide à ajuster.",
          "Follow your daily protocol: scan, hydration, debloat meals and sleep. The AI coach helps you adjust."
        ),
      },
      {
        q: appCopy("Mes données sont-elles privées ?", "Is my data private?"),
        a: appCopy(
          "Oui. Tes scans et données restent sur ton appareil et ton compte — voir notre politique de confidentialité.",
          "Yes. Your scans and data stay on your device and account — see our privacy policy."
        ),
      },
      {
        q: appCopy("À quelle fréquence utiliser Process ?", "How often should I use Process?"),
        a: appCopy(
          "Un scan par jour et quelques minutes pour ta checklist debloat suffisent pour suivre ta progression.",
          "One scan per day and a few minutes on your debloat checklist are enough to track progress."
        ),
      },
    ],
  };
}


export function footerCopy() {
  return {
    tagline: appCopy(
      "Dégonfle ton visage avec scan, protocole debloat et coach IA.",
      "Debloat your face with scan, debloat protocol and AI coach."
    ),
    email: "contact@useprocess.xyz",
    privacy: appCopy("Politique de confidentialité", "Privacy Policy"),
    terms: appCopy("Conditions d'utilisation", "Terms of Service"),
    privacyHref: "/confidentialite",
    termsHref: "/cgu",
  };
}
