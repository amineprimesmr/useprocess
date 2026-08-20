const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "",
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "useprocess-d4385.firebaseapp.com",
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "useprocess-d4385",
  appId: import.meta.env.VITE_FIREBASE_APP_ID || "",
};

export const FUNCTIONS_BASE =
  import.meta.env.VITE_FUNCTIONS_BASE_URL ||
  "https://us-central1-useprocess-d4385.cloudfunctions.net";

export function isFirebaseConfigured() {
  return Boolean(firebaseConfig.apiKey && firebaseConfig.appId);
}

let appPromise;
let authModulePromise;

export function warmFirebaseAuth() {
  if (!isFirebaseConfigured()) return;
  void getFirebaseAuth();
  void getFirebaseAuthModule();
}

export function getFirebaseAuthModule() {
  authModulePromise ||= import("firebase/auth");
  return authModulePromise;
}

export async function getAuthToken(user, forceRefresh = false) {
  return user.getIdToken(forceRefresh);
}

export async function getFirebaseAuth() {
  if (!isFirebaseConfigured()) {
    throw new Error("firebase_not_configured");
  }
  if (!appPromise) {
    appPromise = (async () => {
      const { initializeApp, getApps } = await import("firebase/app");
      const { getAuth } = await import("firebase/auth");
      const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
      return getAuth(app);
    })();
  }
  return appPromise;
}

export async function affiliateApi(functionName, { token, body = {} } = {}) {
  const response = await fetch(`${FUNCTIONS_BASE}/${functionName}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = new Error(data.error || `HTTP ${response.status}`);
    err.status = response.status;
    err.data = data;
    throw err;
  }
  return data;
}
