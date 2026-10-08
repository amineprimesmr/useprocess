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

// Les visages et citations de membres ne sont publiés qu’après preuve et autorisation.
export function onboardingCommunityAvatars() {
  return [];
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
    { id: "faq", label: appCopy("FAQ", "FAQ's") },
  ];
}

export function heroCopy() {
  return {
    trustBadge: appCopy("Disponible sur iPhone", "Available on iPhone"),
    title: appCopy(
      "Votre suivi visage et habitudes avec Process",
      "Track your face and habits with Process"
    ),
    subtitle: appCopy(
      "Scan visage, suivi des habitudes et coach IA — des estimations de bien-être pour accompagner ta routine, sans résultat garanti.",
      "Face scans, habit tracking and an AI coach — wellness estimates to support your routine, with no guaranteed results."
    ),
    subtitleMobile: appCopy(
      "Scan visage et routine personnelle — des estimations, pas un diagnostic médical.",
      "Face scans and a personal routine — estimates, not a medical diagnosis."
    ),
    cta: appCopy("Télécharger l'app", "Download App"),
    appAvailable: appCopy("Disponible sur", "App Available on"),
    trustLine: appCopy(
      "Scan, plan et coach IA",
      "Scan, plan and AI coach"
    ),
    trustAvatars: onboardingCommunityAvatars().slice(0, 3),
  };
}

export function statsCopy() {
  return {
    title: appCopy(
      "Un suivi quotidien, adapté à ton profil.",
      "Daily tracking tailored to your profile."
    ),
    items: [
      { target: 7, format: "grouped", label: appCopy("Langues disponibles", "Available languages") },
      { target: 2, format: "grouped", label: appCopy("Formules d'abonnement", "Subscription plans") },
      { target: 1, format: "grouped", label: appCopy("Coach IA personnalisé", "Personalized AI coach") },
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
    title: appCopy("Coach IA et suivi des habitudes", "AI coach and habit tracking"),
    subtitle: appCopy(
      "Scans, journal, repas et sommeil : retrouve tes habitudes dans une routine personnelle.",
      "Scans, a journal, meals and sleep: bring your habits together in a personal routine."
    ),
    cards: [
      processFeatureCard(
        "Capture visage quotidienne",
        "Daily face capture",
        "Observe les changements visibles de ton visage et suis tes habitudes au quotidien.",
        "Track visible changes in your face alongside your daily habits.",
        LANDING_FEATURE_ICONS.face3d
      ),
      processFeatureCard(
        "Protocole personnalisé",
        "Personalized protocol",
        "Une routine d’habitudes à adapter à ton quotidien, sans promesse de changement physique.",
        "A habit routine to adapt to your daily life, without promising physical changes.",
        LANDING_FEATURE_ICONS.routines
      ),
      processFeatureCard(
        "Repas debloat",
        "Debloat meals",
        "Idées de repas et estimations nutritionnelles à partir des informations fournies.",
        "Meal ideas and nutritional estimates based on the information you provide.",
        LANDING_FEATURE_ICONS.progress
      ),
      processFeatureCard(
        "Coach IA",
        "AI coach",
        "Des échanges sur tes habitudes et ta routine, avec les limites d’un coach IA.",
        "Conversations about your habits and routine, with the limits of an AI coach.",
        LANDING_FEATURE_ICONS.coach
      ),
    ],
  };
}

export function potentialCopy() {
  return {
    title: appCopy("Ton suivi quotidien dans une seule app", "Your daily tracking in one app"),
    subtitle: appCopy(
      "Scans, checklist, hydratation, repas et coach IA pour accompagner ta routine.",
      "Scans, a checklist, hydration, meals and an AI coach to support your routine."
    ),
    checklist: [
      appCopy("Scan visage & estimations visuelles", "Face scans & visual estimates"),
      appCopy("Routine personnelle", "Personal routine"),
      appCopy("Hydratation & repas debloat", "Hydration & debloat meals"),
      appCopy("Sommeil & récupération", "Sleep & recovery tracking"),
      appCopy("Coach IA bien-être", "Wellness AI coach"),
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
          "Une app iOS pour suivre les observations du visage, les habitudes quotidiennes et une routine personnelle avec un coach IA.",
          "An iOS app for tracking facial observations, daily habits and a personal routine with an AI coach."
        ),
      },
      {
        q: appCopy("Comment fonctionne le scan ?", "How does the scan work?"),
        a: appCopy(
          "Le scan fournit des estimations visuelles sensibles à la lumière, à la pose et à la caméra. Il ne mesure ni les hormones ni la quantité de rétention d’eau.",
          "Scans provide visual estimates affected by lighting, pose and camera conditions. They do not measure hormones or the amount of water retention."
        ),
      },
      {
        q: appCopy("Est-ce une app skincare ?", "Is this a skincare app?"),
        a: appCopy(
          "Process propose un suivi des habitudes et des observations visuelles. Il ne diagnostique pas la cause d’un gonflement et ne remplace pas un professionnel de santé.",
          "Process tracks habits and visual observations. It does not diagnose swelling or replace a healthcare professional."
        ),
      },
      {
        q: appCopy("Comment améliorer mes résultats ?", "How do I improve my results?"),
        a: appCopy(
          "Compare des captures similaires et note tes habitudes. Le coach peut t’aider à organiser ta routine.",
          "Follow your daily protocol: scan, hydration, debloat meals and sleep. The AI coach helps you adjust."
        ),
      },
      {
        q: appCopy("Mes données sont-elles privées ?", "Is my data private?"),
        a: appCopy(
          "Les captures de scan sont conservées sur ton iPhone et les résultats peuvent être synchronisés. Si tu actives l’analyse IA des photos avec ton consentement, une photo peut être transmise au prestataire IA. Les contenus du coach sont traités séparément, comme décrit dans la politique de confidentialité.",
          "Scan captures are stored on your iPhone and results may sync. If you consent to AI photo analysis, a photo may be sent to the AI provider. Coach content is processed separately as described in the privacy policy."
        ),
      },
      {
        q: appCopy("À quelle fréquence utiliser Process ?", "How often should I use Process?"),
        a: appCopy(
          "Tu peux noter tes habitudes et comparer tes captures à ton rythme, dans des conditions similaires.",
          "One scan per day and a few minutes on your debloat checklist are enough to track progress."
        ),
      },
    ],
  };
}


export function footerCopy() {
  return {
    tagline: appCopy(
      "Suis tes observations et tes habitudes avec Process.",
      "Debloat your face with scan, debloat protocol and AI coach."
    ),
    email: "contact@processdebloat.com",
    privacy: appCopy("Politique de confidentialité", "Privacy Policy"),
    terms: appCopy("Conditions d'utilisation", "Terms of Service"),
    privacyHref: "/confidentialite",
    termsHref: "/cgu",
  };
}
