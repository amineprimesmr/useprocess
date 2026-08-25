import { affiliateApi, getFirebaseAuth, getFirebaseAuthModule } from "../features/firebase-client.js";

export const EMAIL_FOR_SIGN_IN_KEY = "process.affiliate.emailForSignIn";
export const APPLY_AFTER_LINK_KEY = "process.affiliate.applyAfterLink";

export function affiliateEmailLinkContinueUrl(nextHash = "apply") {
  const url = new URL("/affiliate", window.location.origin);
  url.searchParams.set("emailLink", "1");
  url.searchParams.set("next", nextHash.replace(/^#\/?/, "") || "apply");
  return url.toString();
}

export async function sendAffiliateEmailLink(email, { nextHash = "apply", applyAfter = false } = {}) {
  const normalized = String(email || "").trim().toLowerCase();
  if (!normalized) throw new Error("INVALID_EMAIL");

  try {
    await affiliateApi("affiliatePreparePasswordless");
  } catch {
    /* client send still works if email-link is already enabled */
  }

  const auth = await getFirebaseAuth();
  const { sendSignInLinkToEmail } = await getFirebaseAuthModule();
  await sendSignInLinkToEmail(auth, normalized, {
    url: affiliateEmailLinkContinueUrl(nextHash),
    handleCodeInApp: true,
  });

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

export function hrefLooksLikeEmailLink(href = window.location.href) {
  return (
    href.includes("oobCode=") ||
    href.includes("emailLink=1") ||
    href.includes("mode=signIn")
  );
}

export async function completeAffiliateEmailLink() {
  const href = window.location.href;
  if (!hrefLooksLikeEmailLink(href)) return null;
  const auth = await getFirebaseAuth();
  const { isSignInWithEmailLink, signInWithEmailLink, EmailAuthProvider, linkWithCredential } =
    await getFirebaseAuthModule();
  if (!isSignInWithEmailLink(auth, href)) return null;

  const stored = window.localStorage.getItem(EMAIL_FOR_SIGN_IN_KEY) || "";
  const fromQuery = new URLSearchParams(window.location.search).get("email") || "";
  const email = (stored || fromQuery).trim().toLowerCase();
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

  window.localStorage.removeItem(EMAIL_FOR_SIGN_IN_KEY);

  const next = new URLSearchParams(window.location.search).get("next") || "apply";
  const clean = new URL(window.location.href);
  clean.searchParams.delete("apiKey");
  clean.searchParams.delete("oobCode");
  clean.searchParams.delete("mode");
  clean.searchParams.delete("lang");
  window.history.replaceState({}, "", `${clean.pathname}${clean.search}${clean.hash || `#/${next}`}`);

  return signedInUser;
}
