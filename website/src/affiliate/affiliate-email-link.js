import { affiliateApi, getFirebaseAuth, getFirebaseAuthModule } from "../features/firebase-client.js";
import { CLIPPING_PORTAL_PATH, CLIPPING_PORTAL_URL, isAppleRelayEmail } from "./affiliate-utils.js";

export const EMAIL_FOR_SIGN_IN_KEY = "process.affiliate.emailForSignIn";
export const APPLY_AFTER_LINK_KEY = "process.affiliate.applyAfterLink";

function affiliateEmailLinkBaseUrl() {
  if (typeof window === "undefined") return CLIPPING_PORTAL_URL;
  const host = window.location.hostname;
  if (import.meta.env.DEV && (host === "localhost" || host === "127.0.0.1")) {
    return new URL(CLIPPING_PORTAL_PATH, window.location.origin).toString();
  }
  return CLIPPING_PORTAL_URL;
}

export function hrefLooksLikeEmailLink(href = window.location.href) {
  try {
    const url = new URL(href);
    return (
      url.searchParams.has("oobCode") ||
      url.searchParams.get("emailLink") === "1" ||
      url.searchParams.get("mode") === "signIn"
    );
  } catch {
    return (
      href.includes("oobCode=") ||
      href.includes("emailLink=1") ||
      href.includes("mode=signIn")
    );
  }
}

/** Firebase email links must land on /clipping — redirect from / or other paths. */
export function redirectAffiliateEmailLinkIfNeeded(href = window.location.href) {
  if (typeof window === "undefined") return false;
  if (!hrefLooksLikeEmailLink(href)) return false;

  const url = new URL(href);
  const path = url.pathname.replace(/\/$/, "") || "/";
  if (path === "/clipping" || path === "/clipping.html") return false;

  const target = new URL(CLIPPING_PORTAL_PATH, url.origin);
  url.searchParams.forEach((value, key) => {
    target.searchParams.set(key, value);
  });
  window.location.replace(target.toString());
  return true;
}

export function affiliateEmailLinkContinueUrl(nextHash = "apply", email = "") {
  const url = new URL(affiliateEmailLinkBaseUrl());
  url.searchParams.set("emailLink", "1");
  url.searchParams.set("next", nextHash.replace(/^#\/?/, "") || "apply");
  const normalized = String(email || "").trim().toLowerCase();
  if (normalized) url.searchParams.set("email", normalized);
  return url.toString();
}

export async function sendAffiliateEmailLink(
  email,
  { nextHash = "apply", applyAfter = false, requireExistingAccount = false } = {}
) {
  const normalized = String(email || "").trim().toLowerCase();
  if (!normalized) throw new Error("INVALID_EMAIL");
  if (isAppleRelayEmail(normalized)) {
    const relay = new Error("APPLE_RELAY_EMAIL");
    relay.data = { error: "APPLE_RELAY_EMAIL" };
    throw relay;
  }

  const continueUrl = affiliateEmailLinkContinueUrl(nextHash, normalized);

  try {
    await affiliateApi("affiliateSendLoginEmail", {
      body: { email: normalized, continueUrl },
    });
  } catch (err) {
    if (err?.data?.error === "APPLE_RELAY_EMAIL") throw err;
    if (requireExistingAccount && (err?.status === 404 || err?.data?.error === "EMAIL_NOT_FOUND")) {
      const missing = new Error("EMAIL_NOT_FOUND");
      missing.code = "auth/user-not-found";
      throw missing;
    }
    if (err?.data?.error === "SMTP_NOT_CONFIGURED" || err?.status === 503) {
      const auth = await getFirebaseAuth();
      const { sendSignInLinkToEmail } = await getFirebaseAuthModule();
      await sendSignInLinkToEmail(auth, normalized, {
        url: continueUrl,
        handleCodeInApp: true,
      });
    } else {
      throw err;
    }
  }

  window.localStorage.setItem(EMAIL_FOR_SIGN_IN_KEY, normalized);
  if (applyAfter) {
    window.sessionStorage.setItem(APPLY_AFTER_LINK_KEY, "1");
  }
}

export function consumeApplyAfterLink() {
  try {
    const pending = window.sessionStorage.getItem(APPLY_AFTER_LINK_KEY) === "1";
    if (pending) window.sessionStorage.removeItem(APPLY_AFTER_LINK_KEY);
    return pending;
  } catch {
    return false;
  }
}

export function peekApplyAfterLink() {
  try {
    return window.sessionStorage.getItem(APPLY_AFTER_LINK_KEY) === "1";
  } catch {
    return false;
  }
}

export async function ensureAnonymousAffiliateUser() {
  const auth = await getFirebaseAuth();
  if (auth.currentUser) return auth.currentUser;

  const { signInAnonymously } = await getFirebaseAuthModule();
  try {
    const credential = await signInAnonymously(auth);
    return credential.user;
  } catch (firstError) {
    try {
      await affiliateApi("affiliatePreparePasswordless");
    } catch {
      /* already enabled or unreachable */
    }
    try {
      const retry = await signInAnonymously(auth);
      return retry.user;
    } catch {
      throw firstError;
    }
  }
}

function readEmailForLinkCompletion(forcedEmail = "") {
  const forced = String(forcedEmail || "").trim().toLowerCase();
  if (forced) return forced;

  const params = new URLSearchParams(window.location.search);
  const fromQuery = String(params.get("email") || "").trim().toLowerCase();
  const stored = String(window.localStorage.getItem(EMAIL_FOR_SIGN_IN_KEY) || "").trim().toLowerCase();

  if (fromQuery && !stored) {
    try {
      window.localStorage.setItem(EMAIL_FOR_SIGN_IN_KEY, fromQuery);
    } catch {
      /* private mode */
    }
  }

  return fromQuery || stored;
}

function cleanEmailLinkUrl(nextHash = "overview") {
  const params = new URLSearchParams(window.location.search);
  const next = params.get("next") || nextHash;
  const clean = new URL(window.location.href);
  clean.searchParams.delete("apiKey");
  clean.searchParams.delete("oobCode");
  clean.searchParams.delete("mode");
  clean.searchParams.delete("lang");
  clean.searchParams.delete("email");
  clean.searchParams.delete("emailLink");
  clean.searchParams.delete("next");
  const nextPath = `#/${String(next || "overview").replace(/^#\/?/, "")}`;
  window.history.replaceState({}, "", `${clean.pathname}${clean.search}${nextPath}`);
  window.dispatchEvent(new HashChangeEvent("hashchange"));
  return String(next || "overview").replace(/^#\/?/, "") || "overview";
}

export async function completeAffiliateEmailLink(forcedEmail = "") {
  const href = window.location.href;
  if (!hrefLooksLikeEmailLink(href)) return null;

  const auth = await getFirebaseAuth();
  const { isSignInWithEmailLink, signInWithEmailLink, EmailAuthProvider, linkWithCredential } =
    await getFirebaseAuthModule();
  if (!isSignInWithEmailLink(auth, href)) return null;

  const email = readEmailForLinkCompletion(forcedEmail);
  if (!email) return { needsEmail: true };

  let signedInUser = null;
  if (auth.currentUser?.isAnonymous) {
    try {
      const credential = EmailAuthProvider.credentialWithLink(email, href);
      const linked = await linkWithCredential(auth.currentUser, credential);
      signedInUser = linked.user;
    } catch (error) {
      if (
        error?.code !== "auth/email-already-in-use" &&
        error?.code !== "auth/credential-already-in-use"
      ) {
        throw error;
      }
      const signed = await signInWithEmailLink(auth, email, href);
      signedInUser = signed.user;
    }
  } else {
    const signed = await signInWithEmailLink(auth, email, href);
    signedInUser = signed.user;
  }

  try {
    window.localStorage.removeItem(EMAIL_FOR_SIGN_IN_KEY);
  } catch {
    /* ignore */
  }

  const next = cleanEmailLinkUrl();
  return { user: signedInUser, next };
}

export const PORTAL_HANDOFF_PARAM = "handoff";

export function readPortalHandoffCode(href = window.location.href) {
  try {
    return String(new URL(href).searchParams.get(PORTAL_HANDOFF_PARAM) || "").trim();
  } catch {
    return "";
  }
}

/** Strip the one-time code from the address bar so it never lands in history or a share. */
function clearPortalHandoffParam(nextHash = "") {
  try {
    const clean = new URL(window.location.href);
    clean.searchParams.delete(PORTAL_HANDOFF_PARAM);
    const hash = nextHash ? `#/${String(nextHash).replace(/^#\/?/, "")}` : clean.hash;
    window.history.replaceState({}, "", `${clean.pathname}${clean.search}${hash}`);
  } catch {
    /* ignore */
  }
}

/**
 * Signs the portal in from a code minted by the Process app. No email, so nothing
 * to bounce, land in spam, or be blocked by Apple's relay.
 */
export async function completePortalHandoff(href = window.location.href) {
  const code = readPortalHandoffCode(href);
  if (!code) return null;

  const auth = await getFirebaseAuth();
  const { signInWithCustomToken } = await getFirebaseAuthModule();

  try {
    const { token } = await affiliateApi("affiliatePortalHandoffRedeem", { body: { code } });
    if (!token) throw new Error("HANDOFF_INVALID");
    const credential = await signInWithCustomToken(auth, token);
    clearPortalHandoffParam("overview");
    window.dispatchEvent(new HashChangeEvent("hashchange"));
    return { user: credential.user, next: "overview" };
  } catch (error) {
    clearPortalHandoffParam();
    throw error;
  }
}
