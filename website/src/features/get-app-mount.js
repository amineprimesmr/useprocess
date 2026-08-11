import { getIosAppStoreUrl } from "./app-store-urls.js";
import { appCopy } from "./app-copy.js";
import {
  buildAppStoreUrlWithReferral,
  buildReferralDeepLink,
  buildReferralLandingUrl,
  copyReferralInvite,
  parseReferralCodeFromLocation,
  rememberReferralCode,
} from "./referral-link.js";

const QR_SCRIPT = "/js/qr_code_styling.js";

function loadQrScript() {
  if (typeof window !== "undefined" && window.QRCodeStyling) {
    return Promise.resolve();
  }
  return new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[src="${QR_SCRIPT}"]`);
    if (existing) {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error("qr_script_failed")), { once: true });
      return;
    }
    const script = document.createElement("script");
    script.src = QR_SCRIPT;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("qr_script_failed"));
    document.head.appendChild(script);
  });
}

function isMobileDevice() {
  return /iPhone|iPad|iPod|Android/i.test(navigator.userAgent || "");
}

function detectDevicePlatform() {
  const ua = navigator.userAgent || "";
  if (/iPhone|iPad|iPod/i.test(ua)) return "ios";
  return "unknown";
}

function redirectWithUtmParams(baseUrl) {
  const urlParams = new URLSearchParams(window.location.search);
  const utmParams = new URLSearchParams();
  for (const [key, value] of urlParams) {
    if (key.startsWith("utm_")) utmParams.append(key, value);
  }
  const utmString = utmParams.toString();
  const url = utmString ? `${baseUrl}${baseUrl.includes("?") ? "&" : "?"}${utmString}` : baseUrl;
  window.location.href = url;
}

function openStorePage(referralCode = "") {
  const base = referralCode
    ? buildAppStoreUrlWithReferral(referralCode)
    : getIosAppStoreUrl();
  redirectWithUtmParams(base);
}

async function openStoreWithReferral(referralCode) {
  if (referralCode) {
    await copyReferralInvite(referralCode);
    rememberReferralCode(referralCode);

    if (detectDevicePlatform() === "ios") {
      const deepLink = buildReferralDeepLink(referralCode);
      window.location.href = deepLink;
      window.setTimeout(() => openStorePage(referralCode), 700);
      return;
    }
  }

  openStorePage(referralCode);
}

function showReferralBanner(referralCode) {
  const banner = document.getElementById("get-app-referral-banner");
  const codeEl = document.getElementById("get-app-referral-code");
  const subtitle = document.getElementById("get-app-subtitle");
  const title = document.getElementById("get-app-title");
  if (!banner || !codeEl || !referralCode) return;

  codeEl.textContent = referralCode;
  banner.classList.remove("hidden");
  banner.hidden = false;

  if (title) {
    title.textContent = appCopy(
      "Tu es invité sur Process.",
      "You're invited to Process."
    );
  }
  if (subtitle) {
    subtitle.textContent = appCopy(
      "Code actif — 7 jours offerts sur ton abonnement Apple après ton 1er paiement.",
      "Code active — 7 free days on your Apple subscription after your first payment."
    );
  }

  const referralEyebrow = banner.querySelector(".get-app-referral-eyebrow");
  if (referralEyebrow) {
    referralEyebrow.textContent = appCopy("Invitation parrainage", "Referral invite");
  }
}

function applyGetAppPageCopy() {
  const title = document.getElementById("get-app-title");
  const subtitle = document.getElementById("get-app-subtitle");
  const iosBtn = document.getElementById("get-app-store-ios");
  const iosEyebrow = iosBtn?.querySelector(".get-app-store-badge__eyebrow");

  if (title) {
    title.textContent = appCopy("Dégonfle ton visage.", "De-bloat your face.");
  }
  if (subtitle) {
    subtitle.textContent = appCopy(
      "Process — coach IA & protocole debloat. Télécharge sur iPhone.",
      "Process — AI coach & debloat protocol. Download on iPhone."
    );
  }
  if (iosEyebrow) {
    iosEyebrow.textContent = appCopy("Télécharger l'app", "Download the app");
  }
  if (iosBtn) {
    iosBtn.setAttribute(
      "aria-label",
      appCopy("Télécharger l'app sur l'App Store", "Download the app on the App Store")
    );
  }
}

function shouldStayOnPage() {
  const params = new URLSearchParams(window.location.search);
  return ["1", "true", "yes"].includes(String(params.get("stay") || "").toLowerCase());
}

async function renderQR(referralCode = "") {
  await loadQrScript();
  const QRCodeStyling = window.QRCodeStyling;
  const target = document.getElementById("get-app-qr");
  const container = document.getElementById("get-app-qr-container");
  if (!QRCodeStyling || !target || !container) return;

  const qrCode = new QRCodeStyling({
    width: 250,
    height: 250,
    type: "svg",
    data: referralCode ? buildReferralLandingUrl(referralCode) : getIosAppStoreUrl(),
    qrOptions: { typeNumber: 0, errorCorrectionLevel: "H" },
    image: "/assets/icone.png?v=20260808",
    dotsOptions: { color: "#F6F4EC", type: "dots" },
    cornersSquareOptions: { color: "#fafafa", type: "extra-rounded" },
    cornersDotOptions: { color: "#F6F4EC", type: "square" },
    backgroundOptions: { color: "#0F1920" },
    imageOptions: { crossOrigin: "anonymous", margin: 4, imageSize: 0.5 },
    margin: 0,
  });

  target.innerHTML = "";
  qrCode.append(target);
  container.classList.remove("hidden");
}

function wireStoreButtons(referralCode = "") {
  document.getElementById("get-app-store-ios")?.addEventListener("click", () => {
    openStoreWithReferral(referralCode);
  });
}

export async function mountGetAppPage() {
  const referralCode = parseReferralCodeFromLocation();
  if (referralCode) {
    rememberReferralCode(referralCode);
    showReferralBanner(referralCode);
  } else {
    applyGetAppPageCopy();
  }

  // Sans parrainage : redirection auto iOS vers l'App Store (comportement historique).
  if (
    !referralCode &&
    isMobileDevice() &&
    !shouldStayOnPage() &&
    detectDevicePlatform() === "ios"
  ) {
    openStorePage();
    return;
  }

  wireStoreButtons(referralCode);

  if (!isMobileDevice()) {
    try {
      await renderQR(referralCode);
    } catch (err) {
      console.warn("[get-app] QR indisponible :", err?.message || err);
    }
  }
}
