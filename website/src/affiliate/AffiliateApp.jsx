import { useEffect, useMemo, useState } from "react";
import { appCopy, subscribeSiteLanguage } from "../features/app-copy.js";
import {
  affiliateApi,
  getFirebaseAuth,
  isFirebaseConfigured,
} from "../features/firebase-client.js";
import {
  buildCreatorLandingUrl,
  normalizeAcquisitionCode,
} from "../features/acquisition-link.js";
import "./affiliate.css";

const SUPPORT_EMAIL = "support@useprocess.xyz";

function money(cents, currency = "EUR") {
  try {
    return new Intl.NumberFormat(undefined, {
      style: "currency",
      currency,
      maximumFractionDigits: 2,
    }).format((cents || 0) / 100);
  } catch {
    return `${((cents || 0) / 100).toFixed(2)} ${currency}`;
  }
}

function supportMailto(subject, body) {
  const params = new URLSearchParams();
  if (subject) params.set("subject", subject);
  if (body) params.set("body", body);
  const query = params.toString();
  return `mailto:${SUPPORT_EMAIL}${query ? `?${query}` : ""}`;
}

export function AffiliateApp() {
  const [, setLangTick] = useState(0);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [user, setUser] = useState(null);
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [paypalEmail, setPaypalEmail] = useState("");
  const [applyDisplayName, setApplyDisplayName] = useState("");
  const [applyCode, setApplyCode] = useState("");
  const [applyPaypal, setApplyPaypal] = useState("");

  useEffect(() => subscribeSiteLanguage(() => setLangTick((n) => n + 1)), []);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!isFirebaseConfigured()) {
        setLoading(false);
        return;
      }
      try {
        const auth = await getFirebaseAuth();
        const { onAuthStateChanged } = await import("firebase/auth");
        onAuthStateChanged(auth, async (nextUser) => {
          if (cancelled) return;
          setUser(nextUser);
          if (nextUser) {
            await loadDashboard(nextUser);
          } else {
            setDashboard(null);
            setLoading(false);
          }
        });
      } catch (err) {
        if (!cancelled) {
          setError(err.message || "firebase_error");
          setLoading(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  async function loadDashboard(nextUser) {
    setLoading(true);
    setError("");
    try {
      const token = await nextUser.getIdToken();
      const data = await affiliateApi("affiliateDashboard", { token });
      setDashboard(data);
      setPaypalEmail(data.paypalEmail || "");
    } catch (err) {
      if (err.status === 404) {
        setDashboard(null);
      } else {
        setError(err.message || "dashboard_error");
      }
    } finally {
      setLoading(false);
    }
  }

  async function signIn(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    setSuccess("");
    try {
      const auth = await getFirebaseAuth();
      const { signInWithEmailAndPassword } = await import("firebase/auth");
      await signInWithEmailAndPassword(auth, email.trim(), password);
    } catch (err) {
      setError(err.message || "sign_in_failed");
    } finally {
      setBusy(false);
    }
  }

  async function signOut() {
    const auth = await getFirebaseAuth();
    const { signOut: firebaseSignOut } = await import("firebase/auth");
    await firebaseSignOut(auth);
    setDashboard(null);
    setApplyDisplayName("");
    setApplyCode("");
    setApplyPaypal("");
  }

  async function savePaypal() {
    if (!user) return;
    setBusy(true);
    setError("");
    setSuccess("");
    try {
      const token = await user.getIdToken();
      await affiliateApi("affiliateSyncProfile", {
        token,
        body: { paypalEmail, payoutMethod: "paypal" },
      });
      setSuccess(appCopy("PayPal enregistré.", "PayPal saved."));
      await loadDashboard(user);
    } catch (err) {
      setError(err.message || "save_failed");
    } finally {
      setBusy(false);
    }
  }

  async function submitApplication(event) {
    event.preventDefault();
    if (!user) return;

    const displayName = applyDisplayName.trim();
    if (!displayName) return;

    setBusy(true);
    setError("");
    setSuccess("");

    const normalizedCode = normalizeAcquisitionCode(applyCode);
    const normalizedPaypal = applyPaypal.trim();

    try {
      const token = await user.getIdToken();
      await affiliateApi("affiliateApply", {
        token,
        body: {
          displayName,
          ...(normalizedCode ? { code: normalizedCode } : {}),
          ...(user.email ? { email: user.email } : {}),
          ...(normalizedPaypal ? { paypalEmail: normalizedPaypal } : {}),
        },
      });
      setSuccess(
        appCopy(
          "Candidature envoyée — validation manuelle en cours.",
          "Application submitted — manual approval in progress."
        )
      );
      await loadDashboard(user);
    } catch (err) {
      setError(err.message || "apply_failed");
    } finally {
      setBusy(false);
    }
  }

  const primaryCode = useMemo(
    () => dashboard?.codes?.[0]?.code || "",
    [dashboard]
  );

  const isPending = dashboard?.status === "pending";
  const isActive = dashboard?.status === "active";

  const supportSubject = appCopy(
    "Candidature programme clipping Process",
    "Process clipping program application"
  );

  const supportBody = appCopy(
    `Bonjour,\n\nJe viens de candidater au programme clipping Process (${applyDisplayName || dashboard?.displayName || ""}).\nProfil TikTok : \n\nMerci !`,
    `Hi,\n\nI just applied to the Process clipping program (${applyDisplayName || dashboard?.displayName || ""}).\nTikTok profile: \n\nThanks!`
  );

  if (!isFirebaseConfigured()) {
    return (
      <div className="affiliate-shell">
        <h1>{appCopy("Portail créateur", "Creator portal")}</h1>
        <p>
          {appCopy(
            "Configure VITE_FIREBASE_API_KEY et VITE_FIREBASE_APP_ID pour activer le portail web.",
            "Set VITE_FIREBASE_API_KEY and VITE_FIREBASE_APP_ID to enable the web portal."
          )}
        </p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="affiliate-shell affiliate-center">
        <p>{appCopy("Chargement…", "Loading…")}</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="affiliate-shell">
        <h1>{appCopy("Portail créateur Process", "Process creator portal")}</h1>
        <p className="affiliate-muted">
          {appCopy(
            "Connecte-toi pour voir tes commissions ou candidater au programme clipping (40 %).",
            "Sign in to view your commissions or apply to the clipping program (40%)."
          )}
        </p>
        <form className="affiliate-card" onSubmit={signIn}>
          <label>
            Email
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </label>
          <label>
            {appCopy("Mot de passe", "Password")}
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </label>
          {error ? <p className="affiliate-error">{error}</p> : null}
          <button type="submit" disabled={busy}>
            {appCopy("Se connecter", "Sign in")}
          </button>
        </form>
        <p className="affiliate-muted affiliate-note">
          {appCopy(
            "Tu utilises l’app Process ? Candidature directe dans Paramètres → Programme créateur.",
            "Using the Process app? Apply directly in Settings → Creator program."
          )}
        </p>
      </div>
    );
  }

  return (
    <div className="affiliate-shell">
      <header className="affiliate-header">
        <div>
          <h1>{dashboard?.displayName || appCopy("Programme créateur", "Creator program")}</h1>
          <p className="affiliate-muted">{user.email}</p>
        </div>
        <button type="button" className="affiliate-secondary" onClick={signOut}>
          {appCopy("Déconnexion", "Sign out")}
        </button>
      </header>

      {!dashboard ? (
        <form className="affiliate-card" onSubmit={submitApplication}>
          <h2>{appCopy("Rejoindre le programme clipping", "Join the clipping program")}</h2>
          <p className="affiliate-muted">
            {appCopy(
              "40 % de commission sur chaque abonnement parrainé. Validation manuelle par l’équipe Process.",
              "40% commission on every referred subscription. Manual approval by the Process team."
            )}
          </p>
          <label>
            {appCopy("Nom affiché", "Display name")}
            <input
              type="text"
              value={applyDisplayName}
              onChange={(e) => setApplyDisplayName(e.target.value)}
              placeholder={appCopy("Ex. Manny", "e.g. Manny")}
              required
            />
          </label>
          <label>
            {appCopy("Code souhaité (optionnel)", "Preferred code (optional)")}
            <input
              type="text"
              value={applyCode}
              onChange={(e) => setApplyCode(e.target.value.toUpperCase())}
              placeholder={appCopy("Ex. MANNY", "e.g. MANNY")}
            />
          </label>
          <label>
            {appCopy("Email PayPal (optionnel)", "PayPal email (optional)")}
            <input
              type="email"
              value={applyPaypal}
              onChange={(e) => setApplyPaypal(e.target.value)}
              placeholder="paypal@email.com"
            />
          </label>
          <button type="submit" disabled={busy || !applyDisplayName.trim()}>
            {appCopy("Envoyer ma candidature", "Submit application")}
          </button>
          <a
            className="affiliate-link-button"
            href={supportMailto(supportSubject, supportBody)}
          >
            {appCopy("Contacter l’équipe", "Contact the team")}
          </a>
        </form>
      ) : isPending ? (
        <div className="affiliate-card affiliate-pending">
          <h2>{appCopy("Candidature en attente", "Application pending")}</h2>
          <p className="affiliate-muted">
            {appCopy(
              "Ton compte clipper est en cours de validation. Envoie ton profil TikTok à l’équipe pour activer ton code à 40 %.",
              "Your clipper account is pending approval. Send your TikTok profile to the team to activate your 40% code."
            )}
          </p>
          {primaryCode ? (
            <p>
              {appCopy("Code demandé", "Requested code")}: <strong>{primaryCode}</strong>
            </p>
          ) : null}
          <a
            className="affiliate-link-button"
            href={supportMailto(supportSubject, supportBody)}
          >
            {appCopy("Envoyer un message", "Send a message")}
          </a>
          <label>
            {appCopy("Email PayPal", "PayPal email")}
            <input
              type="email"
              value={paypalEmail}
              onChange={(e) => setPaypalEmail(e.target.value)}
              placeholder="paypal@email.com"
            />
          </label>
          <button type="button" onClick={savePaypal} disabled={busy}>
            {appCopy("Enregistrer PayPal", "Save PayPal")}
          </button>
        </div>
      ) : isActive ? (
        <>
          <div className="affiliate-stats">
            <div className="affiliate-stat">
              <span>{appCopy("En attente", "Pending")}</span>
              <strong>{money(dashboard.stats?.pendingCents)}</strong>
            </div>
            <div className="affiliate-stat">
              <span>{appCopy("À payer", "Payable")}</span>
              <strong>{money(dashboard.stats?.payableCents)}</strong>
            </div>
            <div className="affiliate-stat">
              <span>{appCopy("Payé", "Paid")}</span>
              <strong>{money(dashboard.stats?.paidCents)}</strong>
            </div>
            <div className="affiliate-stat">
              <span>{appCopy("Parrainés", "Referred")}</span>
              <strong>{dashboard.stats?.referredCount || 0}</strong>
            </div>
          </div>

          {primaryCode ? (
            <div className="affiliate-card">
              <h2>{appCopy("Ton lien clipper", "Your clipper link")}</h2>
              <p className="affiliate-code">{primaryCode}</p>
              <a href={buildCreatorLandingUrl(primaryCode)} className="affiliate-link">
                {buildCreatorLandingUrl(primaryCode)}
              </a>
            </div>
          ) : null}

          <div className="affiliate-card">
            <h2>{appCopy("PayPal", "PayPal")}</h2>
            <input
              type="email"
              value={paypalEmail}
              onChange={(e) => setPaypalEmail(e.target.value)}
              placeholder={appCopy("Email PayPal", "PayPal email")}
            />
            <button type="button" onClick={savePaypal} disabled={busy}>
              {appCopy("Enregistrer", "Save")}
            </button>
          </div>

          <div className="affiliate-card">
            <h2>{appCopy("Commissions récentes", "Recent commissions")}</h2>
            {(dashboard.recentCommissions || []).length === 0 ? (
              <p className="affiliate-muted">
                {appCopy("Aucune commission pour l’instant.", "No commissions yet.")}
              </p>
            ) : (
              <ul className="affiliate-list">
                {dashboard.recentCommissions.map((row) => (
                  <li key={row.id}>
                    <span>{row.eventType}</span>
                    <span>{row.status}</span>
                    <strong>{money(row.commissionCents, row.currency)}</strong>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </>
      ) : (
        <div className="affiliate-card">
          <p>
            {appCopy(
              "Compte clipper suspendu. Contacte l’équipe Process.",
              "Clipper account suspended. Contact the Process team."
            )}
          </p>
          <a
            className="affiliate-link-button"
            href={supportMailto(supportSubject, supportBody)}
          >
            {appCopy("Contacter l’équipe", "Contact the team")}
          </a>
        </div>
      )}

      {error ? <p className="affiliate-error">{error}</p> : null}
      {success ? <p className="affiliate-success">{success}</p> : null}
    </div>
  );
}
