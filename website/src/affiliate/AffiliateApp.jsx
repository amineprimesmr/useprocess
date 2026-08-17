import { useEffect, useMemo, useState } from "react";
import { appCopy, subscribeSiteLanguage } from "../features/app-copy.js";
import {
  affiliateApi,
  getFirebaseAuth,
  isFirebaseConfigured,
} from "../features/firebase-client.js";
import { buildCreatorLandingUrl } from "../features/acquisition-link.js";
import "./affiliate.css";

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

export function AffiliateApp() {
  const [, setLangTick] = useState(0);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [user, setUser] = useState(null);
  const [dashboard, setDashboard] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [paypalEmail, setPaypalEmail] = useState("");

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
  }

  async function savePaypal() {
    if (!user) return;
    setBusy(true);
    setError("");
    try {
      const token = await user.getIdToken();
      await affiliateApi("affiliateSyncProfile", {
        token,
        body: { paypalEmail, payoutMethod: "paypal" },
      });
      await loadDashboard(user);
    } catch (err) {
      setError(err.message || "save_failed");
    } finally {
      setBusy(false);
    }
  }

  const primaryCode = useMemo(
    () => dashboard?.codes?.[0]?.code || "",
    [dashboard]
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
            "Connecte-toi pour voir tes commissions et ton lien clipper.",
            "Sign in to view your commissions and clipper link."
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
        <div className="affiliate-card">
          <p>
            {appCopy(
              "Compte sans programme créateur actif. Contacte l’équipe Process pour activer ton code.",
              "No active creator program on this account. Contact the Process team to activate your code."
            )}
          </p>
        </div>
      ) : (
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
              <h2>{appCopy("Ton lien", "Your link")}</h2>
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
      )}

      {error ? <p className="affiliate-error">{error}</p> : null}
    </div>
  );
}
