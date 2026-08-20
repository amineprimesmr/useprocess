import {
  detectInAppBrowser,
  getStoreButtonHref,
  shouldUseSafariStoreFlow,
} from "./in-app-browser-escape.js";
import { subscribeSiteLanguage, appCopy } from "./app-copy.js";
import {
  applyGetAppDocumentLanguage,
  applyGetAppChromeCopy,
  getAppPageCopy,
} from "./site-chrome.js";
import {
  buildAppStoreUrlWithReferral,
  buildReferralDeepLink,
  buildReferralLandingUrl,
  copyReferralInvite,
  parseReferralCodeFromLocation,
  rememberReferralCode,
  resolveAcquisitionUtm,
} from "./referral-link.js";
import { resolveAcquisitionCode } from "./acquisition-link.js";

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

function setVisible(el, visible) {
  if (!el) return;
  el.classList.toggle("hidden", !visible);
  el.hidden = !visible;
  if (visible) el.removeAttribute("hidden");
}

function openStorePage(referralCode = "", utm = {}) {
  const base = buildAppStoreUrlWithReferral(referralCode, utm);

  if (shouldUseSafariStoreFlow()) {
    return;
  }

  window.location.href = base;
}

async function openStoreWithReferral(referralCode, utm = {}) {
  if (referralCode) {
    await copyReferralInvite(referralCode);
    rememberReferralCode(referralCode);

    if (detectDevicePlatform() === "ios" && !shouldUseSafariStoreFlow()) {
      const deepLink = buildReferralDeepLink(referralCode, utm);
      window.location.href = deepLink;
      window.setTimeout(() => openStorePage(referralCode, utm), 700);
      return;
    }
  } else if (Object.keys(utm).length && detectDevicePlatform() === "ios" && !shouldUseSafariStoreFlow()) {
    const deepLink = buildReferralDeepLink("", utm);
    if (deepLink && deepLink !== "process://acquire") {
      window.location.href = deepLink;
      window.setTimeout(() => openStorePage("", utm), 700);
      return;
    }
  }

  openStorePage(referralCode, utm);
}

function inviteTitle(copy, { isCreator, displayName }) {
  const name = String(displayName || "").trim();
  if (name) {
    return isCreator ? copy.creatorInvitesTitleNamed(name) : copy.friendInvitesTitleNamed(name);
  }
  return isCreator ? copy.creatorInvitesTitle : copy.friendInvitesTitle;
}

function applyReferralLayout(referralCode, resolved = null) {
  const copy = getAppPageCopy();
  const shell = document.querySelector(".get-app-shell");
  const isCreator = resolved?.type === "affiliate";
  const displayName = resolved?.displayName || "";
  const mobile = isMobileDevice();

  if (shell) {
    shell.classList.add("get-app-shell--referral");
    shell.classList.toggle("get-app-shell--mobile", mobile);
  }

  setVisible(document.getElementById("get-app-guest-pass"), true);
  setVisible(document.getElementById("get-app-logo-plain"), false);
  setVisible(document.getElementById("get-app-store-plain"), false);

  const guestLabel = document.getElementById("get-app-guest-label");
  const guestValue = document.getElementById("get-app-guest-value");
  if (guestLabel) guestLabel.textContent = isCreator ? copy.guestLabelCreator : copy.guestLabelReferral;
  if (guestValue) guestValue.textContent = copy.guestValue;

  const title = document.getElementById("get-app-title");
  const subtitle = document.getElementById("get-app-subtitle");
  if (title) title.textContent = inviteTitle(copy, { isCreator, displayName });
  if (subtitle) subtitle.textContent = isCreator ? copy.creatorSubtitle : copy.invitedSubtitle;

  const codePrefix = isCreator ? copy.stepCreatorCodePrefix : copy.stepCodePrefix;
  const benefit = isCreator ? copy.stepBenefitCreator : copy.stepBenefitReferral;

  for (const id of ["get-app-step-code-prefix", "get-app-step-code-prefix-fb"]) {
    const el = document.getElementById(id);
    if (el) el.textContent = codePrefix;
  }
  for (const id of ["get-app-referral-code", "get-app-referral-code-fb"]) {
    const el = document.getElementById(id);
    if (el) el.textContent = referralCode;
  }
  for (const id of ["get-app-step-benefit", "get-app-step-benefit-fb"]) {
    const el = document.getElementById(id);
    if (el) el.textContent = benefit;
  }

  const stepsHeading = document.getElementById("get-app-steps-primary-title");
  const fallbackHeading = document.getElementById("get-app-steps-fallback-title");
  const qrLabel = document.getElementById("get-app-step-qr-label");
  const downloadLabel = document.getElementById("get-app-step-download-label");
  const tapHint = document.getElementById("get-app-tap-hint-text");

  if (stepsHeading) stepsHeading.textContent = copy.stepsHeading;
  if (fallbackHeading) fallbackHeading.textContent = copy.stepsFallbackHeading;
  if (qrLabel) qrLabel.textContent = copy.stepQr;
  if (downloadLabel) downloadLabel.textContent = copy.stepDownload;
  if (tapHint) tapHint.textContent = copy.tapBanner;

  setVisible(document.getElementById("get-app-steps-primary"), !mobile);
  setVisible(document.getElementById("get-app-steps-fallback"), mobile);
  setVisible(document.getElementById("get-app-tap-hint"), mobile && detectDevicePlatform() === "ios");
}

function applyPlainLayout() {
  const shell = document.querySelector(".get-app-shell");
  if (shell) shell.classList.remove("get-app-shell--referral", "get-app-shell--mobile");

  setVisible(document.getElementById("get-app-guest-pass"), false);
  setVisible(document.getElementById("get-app-logo-plain"), true);
  setVisible(document.getElementById("get-app-store-plain"), true);
  setVisible(document.getElementById("get-app-steps-primary"), false);
  setVisible(document.getElementById("get-app-steps-fallback"), false);
  setVisible(document.getElementById("get-app-tap-hint"), false);
}

function applyGetAppPageCopy() {
  const copy = getAppPageCopy();
  const title = document.getElementById("get-app-title");
  const subtitle = document.getElementById("get-app-subtitle");
  const iosBtn = document.getElementById("get-app-store-ios");
  const iosBtnFallback = document.getElementById("get-app-store-ios-fallback");
  const inAppFlow = shouldUseSafariStoreFlow();

  if (title) title.textContent = copy.title;
  if (subtitle) {
    subtitle.textContent = inAppFlow
      ? appCopy(
          "TikTok bloque l'App Store. Ouvre Safari, puis retape Télécharger.",
          "TikTok blocks the App Store. Open Safari, then tap Download again."
        )
      : copy.subtitle;
  }

  for (const btn of [iosBtn, iosBtnFallback]) {
    if (!btn) continue;
    const iosEyebrow = btn.querySelector(".store-download-btn__eyebrow");
    const iosName = btn.querySelector(".store-download-btn__name");
    if (iosEyebrow) {
      iosEyebrow.textContent = inAppFlow ? appCopy("Étape 1", "Step 1") : copy.iosEyebrow;
    }
    if (iosName) iosName.textContent = inAppFlow ? appCopy("Safari", "Safari") : "App Store";
    btn.setAttribute(
      "aria-label",
      inAppFlow
        ? appCopy("Ouvrir dans Safari pour télécharger Process", "Open in Safari to download Process")
        : copy.iosAria
    );
  }

  applyGetAppDocumentLanguage();
}

function injectSmartAppBanner(referralCode, utm = {}) {
  const existing = document.querySelector('meta[name="apple-itunes-app"]');
  if (existing) existing.remove();

  const deepLink = buildReferralDeepLink(referralCode, utm);
  const meta = document.createElement("meta");
  meta.name = "apple-itunes-app";
  meta.content = `app-id=6753808143${deepLink ? `, app-argument=${deepLink}` : ""}`;
  document.head.appendChild(meta);

  const theme = document.querySelector('meta[name="theme-color"]');
  if (theme) theme.setAttribute("content", "#000000");
}

function shouldStayOnPage() {
  const params = new URLSearchParams(window.location.search);
  return ["1", "true", "yes"].includes(String(params.get("stay") || "").toLowerCase());
}

async function renderQR(referralCode = "", utm = {}) {
  await loadQrScript();
  const QRCodeStyling = window.QRCodeStyling;
  const target = document.getElementById("get-app-qr");
  const container = document.getElementById("get-app-qr-container");
  if (!QRCodeStyling || !target || !container) return;

  const qrCode = new QRCodeStyling({
    width: 220,
    height: 220,
    type: "svg",
    data: referralCode
      ? buildReferralLandingUrl(referralCode, utm)
      : buildAppStoreUrlWithReferral("", utm),
    qrOptions: { typeNumber: 0, errorCorrectionLevel: "H" },
    image: "/assets/icone.png?v=20260808",
    dotsOptions: { color: "#111827", type: "rounded" },
    cornersSquareOptions: { color: "#111827", type: "extra-rounded" },
    cornersDotOptions: { color: "#111827", type: "dot" },
    backgroundOptions: { color: "#ffffff" },
    imageOptions: { crossOrigin: "anonymous", margin: 4, imageSize: 0.38 },
    margin: 0,
  });

  target.innerHTML = "";
  qrCode.append(target);
  setVisible(container, true);
}

function wireStoreButton(btn, referralCode, utm) {
  if (!btn) return;
  btn.addEventListener("click", () => {
    const storeUrl = buildAppStoreUrlWithReferral(referralCode, utm);
    if (shouldUseSafariStoreFlow()) {
      window.location.href = getStoreButtonHref(storeUrl);
      return;
    }
    openStoreWithReferral(referralCode, utm);
  });
}

function wireStoreButtons(referralCode = "", utm = {}) {
  wireStoreButton(document.getElementById("get-app-store-ios"), referralCode, utm);
  wireStoreButton(document.getElementById("get-app-store-ios-fallback"), referralCode, utm);
}

export async function mountGetAppPage() {
  const referralCode = parseReferralCodeFromLocation();
  const utm = resolveAcquisitionUtm();
  const resolved = referralCode ? await resolveAcquisitionCode(referralCode) : null;
  const resync = () => {
    applyGetAppDocumentLanguage();
    applyGetAppChromeCopy();
    if (referralCode) applyReferralLayout(referralCode, resolved);
    else applyPlainLayout();
    applyGetAppPageCopy();
  };
  subscribeSiteLanguage(resync);

  if (referralCode) {
    rememberReferralCode(referralCode);
    injectSmartAppBanner(referralCode, utm);
    applyReferralLayout(referralCode, resolved);
    applyGetAppDocumentLanguage();
  } else {
    applyPlainLayout();
    applyGetAppPageCopy();
  }

  if (
    !referralCode &&
    isMobileDevice() &&
    !shouldStayOnPage() &&
    detectDevicePlatform() === "ios" &&
    !detectInAppBrowser()
  ) {
    openStorePage("", utm);
    return;
  }

  wireStoreButtons(referralCode, utm);

  if (referralCode && !isMobileDevice()) {
    try {
      await renderQR(referralCode, utm);
    } catch (err) {
      console.warn("[get-app] QR indisponible :", err?.message || err);
    }
  }
}
