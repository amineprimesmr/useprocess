import { appCopy } from "../features/app-copy.js";
import { getIosAppStoreUrl } from "../features/app-store-urls.js";

export const APP_STORE_URL = getIosAppStoreUrl();
export const PROCESS_APP_ICON = "/assets/icone.png?v=20260808";
export const LANDING_MEDIA = "/assets/process-landing";
export const HERO_PHONE_IMAGE = `${LANDING_MEDIA}/phone-hero-app.png?v=20260812b`;
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

export function chromeAriaCopy() {
  return {
    menu: appCopy("Menu", "Menu"),
    mainNav: appCopy("Navigation principale", "Main navigation"),
    footerNav: appCopy("Pied de page", "Footer"),
    appStoreBadge: appCopy("Télécharger sur l'App Store", "Download on the App Store"),
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
      "Trackez et dégonflez votre visage avec l'application Process",
      "Analyse, track and de-bloat your face with Process"
    ),
    subtitle: appCopy(
      "Scan visage, protocole debloat et coach IA — dégonfle ton visage avec nutrition, hydratation et Apple Santé.",
      "Face scan, debloat protocol and AI coach — de-bloat your face with nutrition, hydration, and Apple Health."
    ),
    subtitleMobile: appCopy(
      "Dégonfle ton visage avec nutrition, hydratation et Apple Santé.",
      "De-bloat your face with nutrition, hydration, and Apple Health."
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
      "Des données réelles. Un suivi réel. Des progrès réels.",
      "Real data. Real tracking. Real improvement."
    ),
    items: [
      {
        value: "50k+",
        label: appCopy("Visages scannés et suivis", "Faces scanned and tracked"),
      },
      {
        value: "1,050+",
        label: appCopy("Points de données par scan", "Data points captured per scan"),
      },
      {
        value: "850k+",
        label: appCopy("Points de données analysés", "Data points analyzed"),
      },
    ],
    badge: appCopy("Nos avantages", "Our Benefits"),
  };
}

function processFeatureCard(titleFr, titleEn, bodyFr, bodyEn) {
  return {
    icon: PROCESS_APP_ICON,
    title: appCopy(titleFr, titleEn),
    body: appCopy(bodyFr, bodyEn),
  };
}

export function benefitsCopy() {
  return {
    title: appCopy("Technologie Process avancée", "Advanced Process Technology"),
    subtitle: appCopy(
      "Entraîne, suis et améliore ton visage avec un feedback en temps réel et des routines guidées.",
      "Train, track, and improve your facial presence with real-time feedback and guided routines."
    ),
    cards: [
      processFeatureCard(
        "Entraînement personnalisé",
        "Personalized Training",
        "Des routines sur mesure basées sur ton visage pour améliorer les zones clés.",
        "Custom routines based on your face to improve key areas over time."
      ),
      processFeatureCard(
        "Suivi des progrès",
        "Progress Tracking",
        "Suis l'évolution de la symétrie, de la structure et de ton visage dans le temps.",
        "Track changes in symmetry, structure, and overall facial presence."
      ),
      processFeatureCard(
        "Analyse faciale 3D",
        "3D Face Analysis",
        "Scans précis avec TrueDepth pour mesurer ta structure faciale en temps réel.",
        "Accurate scans using TrueDepth to measure your facial structure in real time."
      ),
      processFeatureCard(
        "Coach IA visage",
        "AI Face Coach",
        "Feedback en direct et conseils actionnables adaptés à ton visage.",
        "Get real-time feedback and actionable advice tailored to your face."
      ),
    ],
  };
}

export function systemCopy() {
  return {
    title: appCopy("Un système conçu pour de vrais progrès", "A System Built for Real Improvement"),
    cards: [
      processFeatureCard(
        "FaceCard partageable",
        "Shareable FaceCard",
        "Affiche tes stats, progrès et métriques faciales dans un format propre et partageable.",
        "Show your stats, progress, and facial metrics in a clean, shareable format."
      ),
      processFeatureCard(
        "Face Battles",
        "Face Battles",
        "Compare tes résultats, affronte d'autres utilisateurs et vois ton classement.",
        "Compare results, compete with others, and see where you rank globally."
      ),
      processFeatureCard(
        "Hub d'information",
        "Information Hub",
        "Apprends à améliorer peau, structure et posture faciale.",
        "Learn how to improve key areas like skin, structure, and facial posture."
      ),
      processFeatureCard(
        "Routines quotidiennes",
        "Daily Routines",
        "Suis des exercices guidés pour améliorer ton visage sur la durée.",
        "Follow guided exercises designed to improve your facial presence over time."
      ),
    ],
  };
}

export function potentialCopy() {
  return {
    title: appCopy("Tout ce qu'il te faut pour atteindre ton potentiel", "Everything You Need To Reach Your Potential"),
    subtitle: appCopy(
      "Construit avec un suivi avancé, des données réelles et des routines structurées.",
      "Built with advanced tracking, real data, and structured routines."
    ),
    checklist: [
      appCopy("Cartographie faciale 3D", "3D Face Mapping"),
      appCopy("Routines d'entraînement quotidiennes", "Daily Training Routines"),
      appCopy("Partage FaceCard", "FaceCard Sharing"),
      appCopy("Classements compétitifs", "Competitive Rankings"),
      appCopy("Hub d'apprentissage", "In-Depth Learning Hub"),
    ],
  };
}

export function testimonialsCopy() {
  const avatars = onboardingCommunityAvatars();
  return {
    badge: appCopy("Témoignages", "Testimonials"),
    badgeAvatars: avatars,
    title: appCopy("Nos témoignages", "Our Testimonials"),
    subtitle: appCopy(
      "Découvre comment Process aide les utilisateurs à dégonfler et suivre leur visage.",
      "See how Process helps users de-bloat and track their face over time."
    ),
    items: [
      {
        quote: appCopy(
          "Enfin une app qui donne de vraies mesures au lieu de notes IA vagues. Mon score mâchoire m'a ouvert les yeux.",
          "Finally an app that gives real measurements instead of vague AI ratings. My jawline score was eye-opening."
        ),
        name: "Enzo",
        avatar: avatars[1],
      },
      {
        quote: appCopy(
          "Le scan 3D est incroyablement précis. Je peux vraiment suivre mes progrès mewing avec de vraies données.",
          "The 3D scan is insanely accurate. I can actually track my mewing progress now with real data."
        ),
        name: "Amir",
        avatar: avatars[2],
      },
      {
        quote: appCopy(
          "La routine personnalisée basée sur MES mesures a tout changé. Ça vaut chaque centime.",
          "The personalized routine based on MY measurements made all the difference. Worth every penny."
        ),
        name: "Ken",
        avatar: avatars[3],
      },
      {
        quote: appCopy(
          "Je ne m'attendais pas à grand-chose mais le suivi est vraiment précis. Tu vois ce qu'il faut corriger.",
          "Didn't expect much but the tracking is actually really accurate. You can see what you need to fix."
        ),
        name: "Malik",
        avatar: avatars[4],
      },
      {
        quote: appCopy(
          "FaceCard est cool, ça rend facile de voir les progrès et de les partager.",
          "FaceCard is cool, makes it easy to see progress and share it."
        ),
        name: "Sam",
        avatar: avatars[0],
      },
      {
        quote: appCopy(
          "Ce n'est pas qu'un scan unique. Les routines et le suivi quotidien permettent de vraiment progresser.",
          "It's not just a one time scan. The routines and daily tracking make it feel like something you can actually improve with."
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
        q: appCopy("Comment fonctionne Process ?", "How does Process work?"),
        a: appCopy(
          "Process scanne ton visage en 3D, analyse ta structure et te propose un protocole debloat personnalisé avec coach IA, nutrition et hydratation.",
          "Process scans your face in 3D, analyzes your structure, and delivers a personalized debloat protocol with AI coaching, nutrition, and hydration."
        ),
      },
      {
        q: appCopy("Le scan visage est-il précis ?", "Is the face scan accurate?"),
        a: appCopy(
          "Oui — nous utilisons TrueDepth pour capturer des centaines de points de données faciales en temps réel.",
          "Yes — we use TrueDepth to capture hundreds of facial data points in real time."
        ),
      },
      {
        q: appCopy("Comment améliorer mes résultats ?", "How do I improve my results?"),
        a: appCopy(
          "Suis ton protocole quotidien, tes routines guidées et les conseils du coach IA adaptés à ton profil.",
          "Follow your daily protocol, guided routines, and AI coach advice tailored to your profile."
        ),
      },
      {
        q: appCopy("Qu'est-ce que la FaceCard ?", "What is the FaceCard?"),
        a: appCopy(
          "Une carte partageable avec tes stats, scores et progrès faciaux.",
          "A shareable card with your stats, scores, and facial progress."
        ),
      },
      {
        q: appCopy("Que sont les Face Battles ?", "What are Face Battles?"),
        a: appCopy(
          "Des compétitions où tu compares tes résultats avec d'autres utilisateurs dans le monde.",
          "Competitions where you compare your results with other users globally."
        ),
      },
      {
        q: appCopy("Mes données sont-elles privées ?", "Is my data private?"),
        a: appCopy(
          "Oui. Tes scans et données restent sur ton appareil et ton compte — consulte notre politique de confidentialité.",
          "Yes. Your scans and data stay on your device and account — see our privacy policy."
        ),
      },
      {
        q: appCopy("À quelle fréquence utiliser Process ?", "How often should I use Process?"),
        a: appCopy(
          "Un scan quotidien et quelques minutes de routine suffisent pour suivre tes progrès.",
          "A daily scan and a few minutes of routine are enough to track your progress."
        ),
      },
    ],
  };
}

export function finalCtaCopy() {
  return {
    title: appCopy("Commence à t'améliorer dès aujourd'hui", "Start Improving Yourself Today"),
    subtitle: appCopy(
      "Télécharge Process et commence à suivre, t'entraîner et progresser avec un feedback en temps réel.",
      "Download Process and begin tracking, training, and improving with real-time feedback."
    ),
  };
}

export function footerCopy() {
  return {
    tagline: appCopy(
      "Entraîne, suis et améliore ton visage avec Process",
      "Train, track, and improve your face with Process"
    ),
    email: "contact@useprocess.xyz",
    privacy: appCopy("Politique de confidentialité", "Privacy Policy"),
    terms: appCopy("Conditions d'utilisation", "Terms of Service"),
    privacyHref: "/confidentialite",
    termsHref: "/cgu",
  };
}
