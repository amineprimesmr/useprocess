import { lazy, Suspense, useCallback, useEffect, useMemo, useRef, useState } from "react";
import { appCopy, subscribeSiteLanguage, applySiteDocumentLanguage } from "../features/app-copy.js";
import { playSettingsChange } from "../features/process-sound.js";
import {
  affiliateApi,
  getFirebaseAuth,
  getFirebaseAuthModule,
  getAuthToken,
  isFirebaseConfigured,
  warmFirebaseAuth,
  warmAffiliateFunctions,
} from "../features/firebase-client.js";
import {
  buildCreatorLandingUrl,
  parseAcquisitionCodeFromInput,
} from "../features/acquisition-link.js";
import {
  IconCheck,
  IconChevronDown,
  IconChevronLeft,
  IconCoin,
  IconCursor,
  IconDollar,
  IconDownload,
  IconFilter,
  IconGlobe,
  IconHelp,
  IconInfo,
  IconLogout,
  IconMenu,
  IconClose,
  IconOverview,
  IconPaywall,
  IconSettings,
  IconShield,
  IconSlides,
  IconSpark,
  IconTikTok,
  IconTrophy,
  IconWallet,
  IconWhatsApp,
  ProcessAppIcon,
  ProcessNavIcon,
} from "./AffiliateIcons.jsx";
import { SuccessActionButton, playConfirm } from "./action-feedback.jsx";
import {
  AFFILIATE_DASHBOARD_ROUTES,
  buildSupportBody,
  buildSocialMailBody,
  canonicalizeAffiliateRoute,
  COMMISSION_PERCENT,
  VIEW_BONUS_FLAGSHIP_UNLOCK_EUR,
  VIEW_BONUS_UNLOCK_EUR,
  formatApplyError,
  appleRelayHelpMessage,
  formatAuthError,
  isAppleRelayEmail,
  formatPercent,
  formatShortDate,
  money,
  navigateHash,
  readHashRoute,
  readHashQuery,
  hasAffiliatePrefill,
  consumeAffiliatePrefill,
  socialMailSubject,
  supportMailto,
  SUPPORT_EMAIL,
  SUPPORT_WHATSAPP_DISPLAY,
  SUPPORT_WHATSAPP_URL,
} from "./affiliate-utils.js";
import {
  buildOptimisticDashboard,
  clearDashboardCache,
  forgetAffiliateSession,
  peekAffiliateSession,
  rememberAffiliateUid,
  readDashboardCache,
  writeDashboardCache,
} from "./affiliate-dashboard-cache.js";
import { AffiliateOnboarding } from "./AffiliateOnboarding.jsx";
import {
  codeFromFirstName,
  isOnboardingUnlocked,
  markOnboardingUnlocked,
  readOnboardingDraft,
} from "./affiliate-onboarding-state.js";
import {
  completeAffiliateEmailLink,
  completePortalHandoff,
  readPortalHandoffCode,
  consumeApplyAfterLink,
  peekApplyAfterLink,
  hrefLooksLikeEmailLink,
  sendAffiliateEmailLink,
  ensureAnonymousAffiliateUser,
} from "./affiliate-email-link.js";
import {
  isAffiliateLocalPreview,
  LOCAL_PREVIEW_DASHBOARD,
  LOCAL_PREVIEW_USER,
} from "./affiliate-local-preview.js";
import "./affiliate.css";

const AffiliateLanding = lazy(() =>
  import("./AffiliateLanding.jsx").then((mod) => ({ default: mod.AffiliateLanding }))
);
const AffiliateFormatsPage = lazy(() =>
  import("./AffiliateFormats.jsx").then((mod) => ({ default: mod.AffiliateFormatsPage }))
);
const AffiliateSlideshowLabPage = lazy(() =>
  import("./AffiliateSlideshowLab.jsx").then((mod) => ({ default: mod.AffiliateSlideshowLabPage }))
);
const AffiliateProcessAssetsPage = lazy(() =>
  import("./AffiliateProcessAssets.jsx").then((mod) => ({ default: mod.AffiliateProcessAssetsPage }))
);
const AffiliateMethodPage = lazy(() =>
  import("./AffiliateMethod.jsx").then((mod) => ({ default: mod.AffiliateMethodPage }))
);
const AffiliateAutomationPage = lazy(() =>
  import("./AffiliateAutomation.jsx").then((mod) => ({ default: mod.AffiliateAutomationPage }))
);
const AffiliateUsPage = lazy(() =>
  import("./AffiliateUs.jsx").then((mod) => ({ default: mod.AffiliateUsPage }))
);
const AffiliateUsefulPage = lazy(() =>
  import("./AffiliateUseful.jsx").then((mod) => ({ default: mod.AffiliateUsefulPage }))
);
const AffiliateClippersPage = lazy(() =>
  import("./AffiliateClippers.jsx").then((mod) => ({ default: mod.AffiliateClippersPage }))
);

const LANDING_HASHES = new Set(["", "program", "programme", "comment", "primes", "offre", "faq"]);

function AffiliateWhatsAppSupportFab() {
  const label = appCopy("Contacter leks sur WhatsApp", "Message leks on WhatsApp");
  const hint = appCopy("Hésitez pas ?", "Don't hesitate?");
  return (
    <a
      href={SUPPORT_WHATSAPP_URL}
      className="af-wa-fab-wrap"
      target="_blank"
      rel="noopener noreferrer"
      aria-label={label}
      title={label}
    >
      <span className="af-wa-fab-hint" aria-hidden="true">
        <span className="af-wa-fab-pulse" />
        <span className="af-wa-fab-hint-text">{hint}</span>
      </span>
      <span className="af-wa-fab">
        <IconWhatsApp filled className="af-wa-fab-icon" />
      </span>
    </a>
  );
}

function AffiliatePageChrome({ children }) {
  return (
    <>
      {children}
      <AffiliateWhatsAppSupportFab />
    </>
  );
}

let consumedApplyPrefillCache;

function getConsumedApplyPrefill() {
  if (consumedApplyPrefillCache === undefined) {
    consumedApplyPrefillCache = consumeAffiliatePrefill();
  }
  return consumedApplyPrefillCache;
}

function usefulTopicFromRoute(path, query) {
  const raw = String(path || "").trim();
  if (raw === "shadowban") return "shadowban";
  if (raw === "questions") return "questions";
  if (raw === "aide" || raw === "help" || raw === "whatsapp") return "";
  return String(query?.t || "").trim();
}

function useHashRoute() {
  const [route, setRoute] = useState(() => {
    const prefill = getConsumedApplyPrefill();
    const hashRoute = canonicalizeAffiliateRoute(readHashRoute(), readHashQuery());
    if (hashRoute === "apply" || hasAffiliatePrefill(prefill)) return "apply";
    if (hashRoute && hashRoute !== "program") return hashRoute;
    return "program";
  });
  const [query, setQuery] = useState(() => readHashQuery());

  useEffect(() => {
    const onHash = () => {
      const raw = readHashRoute();
      const hashQuery = readHashQuery();
      const canonical = canonicalizeAffiliateRoute(raw, hashQuery);
      const topic = usefulTopicFromRoute(raw, hashQuery);
      if (raw !== canonical) {
        const params = new URLSearchParams(hashQuery);
        if (topic) params.set("t", topic);
        const qs = params.toString();
        navigateHash(qs ? `${canonical}?${qs}` : canonical);
        return;
      }
      setRoute(canonical);
      setQuery(hashQuery);
    };
    const raw = readHashRoute();
    const hashQuery = readHashQuery();
    const canonical = canonicalizeAffiliateRoute(raw, hashQuery);
    const topic = usefulTopicFromRoute(raw, hashQuery);
    if (raw !== canonical) {
      const params = new URLSearchParams(hashQuery);
      if (topic) params.set("t", topic);
      const qs = params.toString();
      navigateHash(qs ? `${canonical}?${qs}` : canonical);
    }
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  const go = useCallback((next) => {
    const raw = String(next || "").replace(/^#\/?/, "").trim() || "program";
    const [path, queryString] = raw.split("?");
    const parsedQuery = Object.fromEntries(new URLSearchParams(queryString || ""));
    const canonical = canonicalizeAffiliateRoute((path || "program").trim(), parsedQuery);
    const topic = usefulTopicFromRoute(path, parsedQuery);
    const nextQuery = topic ? `t=${encodeURIComponent(topic)}` : queryString;
    setRoute(canonical);
    setQuery(nextQuery ? Object.fromEntries(new URLSearchParams(nextQuery)) : {});
    navigateHash(nextQuery ? `${canonical}?${nextQuery}` : canonical);
  }, []);

  return [route, go, query];
}

function DashboardSkeleton({ route }) {
  const pageTitles = {
    overview: appCopy("Overview", "Overview"),
    tiktoks: appCopy("Format", "Format"),
    format: appCopy("Format", "Format"),
    slideshowlab: "SlideshowLab",
    assets: "Process Assets",
    methode: appCopy("Démarrage", "Getting started"),
    clippers: appCopy("Clippers", "Clippers"),
    automatisation: appCopy("Automatiser", "Automate"),
    us: appCopy("Poster US", "Post in the US"),
    utiles: appCopy("Utiles", "Useful"),
    payouts: appCopy("Paiements", "Payouts"),
    settings: appCopy("Paramètres", "Settings"),
  };
  return (
    <div className="af-app af-shell">
      <aside className="af-sidebar" aria-hidden="true">
        <div className="af-sidebar-logo">PROCE$$ CLIPPING</div>
        <div className="af-skeleton-line" style={{ width: "72%" }} />
        <div className="af-skeleton-line" style={{ width: "56%" }} />
        <div className="af-skeleton-line" style={{ width: "64%" }} />
      </aside>
      <main className="af-main af-main-skeleton">
        <div className="af-page-head">
          <h1>{pageTitles[route] || pageTitles.overview}</h1>
        </div>
        <div className="af-card af-card-pad">
          <div className="af-skeleton-line" style={{ width: "40%", height: 18 }} />
          <div className="af-skeleton-line" style={{ width: "100%", height: 44, marginTop: 16 }} />
          <div className="af-skeleton-line" style={{ width: "88%", height: 44, marginTop: 10 }} />
        </div>
      </main>
    </div>
  );
}

function MiniChart({ color = "#ec4899", className = "", values = [] }) {
  const id = useMemo(() => `grad-${Math.random().toString(36).slice(2, 8)}`, []);
  const series = values.length ? values.map((n) => Number(n) || 0) : Array(30).fill(0);
  const max = Math.max(...series, 0);
  const width = 400;
  const height = 120;
  const pad = 8;
  const step = width / Math.max(series.length - 1, 1);
  const coords = series.map((value, index) => {
    const x = index * step;
    const y = max > 0 ? height - pad - (value / max) * (height - pad * 2 - 8) : height - 22;
    return [x, y];
  });
  const linePath = coords.map(([x, y], index) => `${index === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`).join(" ");
  const last = coords[coords.length - 1] || [width, height];
  const areaPath = `${linePath} L${last[0]},${height} L0,${height} Z`;
  return (
    <div className={`af-chart-wrap ${className}`.trim()}>
      <svg viewBox="0 0 400 120" preserveAspectRatio="none">
        <defs>
          <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.28" />
            <stop offset="100%" stopColor={color} stopOpacity="0" />
          </linearGradient>
        </defs>
        <path className="af-chart-area" d={areaPath} fill={`url(#${id})`} />
        <path className="af-chart-line" d={linePath} stroke={color} />
      </svg>
    </div>
  );
}

function RequiredBadge({ done = false }) {
  return (
    <span className={`af-required ${done ? "is-done" : ""}`}>
      {done ? appCopy("OK", "OK") : appCopy("Requis", "Required")}
    </span>
  );
}

function ProgramLanding({ onApply, onLogin }) {
  return <AffiliateLanding onApply={onApply} onLogin={onLogin} />;
}

function SocialChannelForm({ displayName, compact = false }) {
  const [handle, setHandle] = useState("");
  const [sent, setSent] = useState(false);

  function submitSocial(event) {
    event.preventDefault();
    const value = handle.trim();
    if (!value) return;
    window.location.href = supportMailto(socialMailSubject(), buildSocialMailBody(displayName, value));
    setSent(true);
  }

  if (sent) {
    return (
      <p className="af-social-sent">
        {appCopy(
          "Merci — ouvre ton app mail si ce n'est pas déjà fait.",
          "Thanks — open your mail app if it didn't open already."
        )}
      </p>
    );
  }

  return (
    <form className={compact ? "af-social-form compact" : "af-social-form"} onSubmit={submitSocial}>
      <div className="af-field" style={{ marginBottom: compact ? 12 : 20 }}>
        <div className="af-label-row">
          <label htmlFor={compact ? "af-social-compact" : "af-social"}>
            {appCopy("@ TikTok ou Instagram", "TikTok or Instagram @")}
          </label>
          <RequiredBadge done={handle.trim().length > 0} />
        </div>
        <input
          id={compact ? "af-social-compact" : "af-social"}
          className="af-input"
          value={handle}
          onChange={(e) => setHandle(e.target.value)}
          placeholder={appCopy("@manny ou tiktok.com/@manny", "@manny or tiktok.com/@manny")}
          required
        />
      </div>
      <button type="submit" className="af-btn af-btn-sm af-btn-black" disabled={!handle.trim()}>
        {appCopy("Envoyer mon @", "Send my @")}
      </button>
    </form>
  );
}


function CopyButton({ text }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      playConfirm();
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      /* ignore */
    }
  }

  return (
    <button
      type="button"
      className={`af-btn af-btn-sm af-btn-black ${copied ? "af-btn-copied" : ""}`}
      onClick={copy}
    >
      {copied ? (
        <>
          <IconCheck style={{ width: 14, height: 14 }} />
          {appCopy("Copié", "Copied")}
        </>
      ) : (
        appCopy("Copier", "Copy")
      )}
    </button>
  );
}

function stripeConnectState(dashboard) {
  return (
    dashboard?.stripeConnect ?? {
      accountId: null,
      onboardingComplete: false,
      payoutsEnabled: false,
      detailsSubmitted: false,
      requirementsDue: [],
    }
  );
}

function isStripePayoutReady(dashboard) {
  const stripe = stripeConnectState(dashboard);
  return Boolean(stripe.accountId && stripe.payoutsEnabled);
}

function uniquePaidFromCommissions(rows) {
  const ids = new Set();
  for (const row of rows || []) {
    if (row?.inviteeUid && String(row.eventType || "").includes("PURCHASE")) {
      ids.add(row.inviteeUid);
    }
  }
  return ids.size;
}

function InviteLinkCard({ dashboard, isPending, primaryCode, linkUrl, onSaveInvite }) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(dashboard?.displayName || "");
  const [code, setCode] = useState(primaryCode || "");
  const [error, setError] = useState("");

  useEffect(() => {
    if (editing) return;
    setName(dashboard?.displayName || "");
    setCode(primaryCode || "");
  }, [dashboard?.displayName, primaryCode, editing]);

  const previewCode = parseAcquisitionCodeFromInput(code) || primaryCode || "";
  const previewUrl = previewCode ? buildCreatorLandingUrl(previewCode) : linkUrl;
  const previewName = name.trim() || dashboard?.displayName || "";

  function validate() {
    const nextName = name.trim();
    const nextCode = parseAcquisitionCodeFromInput(code);
    if (!nextName) {
      setError(appCopy("Indique le prénom affiché sur l'invitation.", "Enter the first name shown on the invite."));
      return false;
    }
    if (!nextCode || nextCode.length < 3) {
      setError(
        appCopy(
          "Choisis un code — minimum 3 caractères (lettres, chiffres ou tiret).",
          "Pick a code — at least 3 characters (letters, numbers, or hyphen)."
        )
      );
      return false;
    }
    setError("");
    return true;
  }

  return (
    <div className="af-card af-link-card">
      {isPending ? (
        <div className="af-form-info" style={{ marginBottom: 0, borderBottom: "1px solid var(--af-border)" }}>
          <p>
            {appCopy(
              "Ton lien est réservé — les commissions s'activent dès validation de ton compte.",
              "Your link is reserved — commissions activate once your account is approved."
            )}
          </p>
        </div>
      ) : null}
      <div className="af-link-card-top">
        <div>
          <div className="af-link-card-main">
            <ProcessAppIcon size={28} />
            <div>
              <strong>{(previewUrl || linkUrl || "useprocess.xyz/join/…").replace("https://", "")}</strong>
              <div className="af-link-dest">
                {appCopy(
                  `Nom sur l'invitation : ${previewName || "—"}`,
                  `Name on the invite: ${previewName || "—"}`
                )}
              </div>
            </div>
          </div>
        </div>
        <div className="af-link-card-actions">
          {linkUrl ? <CopyButton text={linkUrl} /> : null}
          {onSaveInvite ? (
            <button
              type="button"
              className="af-btn af-btn-sm af-btn-secondary"
              onClick={() => {
                setEditing((open) => !open);
                setError("");
              }}
            >
              {editing
                ? appCopy("Fermer", "Close")
                : appCopy("Modifier le lien", "Edit link")}
            </button>
          ) : null}
        </div>
      </div>

      {editing ? (
        <div className="af-invite-edit">
          <div className="af-invite-preview">
            <span>{appCopy("Aperçu de l'invitation", "Invite preview")}</span>
            <strong>
              {appCopy(
                `${previewName || "…"} t'invite sur Process`,
                `${previewName || "…"} invites you to Process`
              )}
            </strong>
            <em>
              {appCopy(
                `Ton code clipper : ${previewCode || "…"}`,
                `Your clipper code: ${previewCode || "…"}`
              )}
            </em>
          </div>
          <div className="af-invite-fields">
            <div className="af-invite-field">
              <label htmlFor="af-invite-name">{appCopy("Prénom sur la page", "Name on the page")}</label>
              <input
                id="af-invite-name"
                className="af-input"
                value={name}
                maxLength={32}
                onChange={(event) => setName(event.target.value)}
                placeholder={appCopy("amine", "alex")}
              />
            </div>
            <div className="af-invite-field">
              <label htmlFor="af-invite-code">{appCopy("Ton code / lien", "Your code / link")}</label>
              <input
                id="af-invite-code"
                className="af-input"
                value={code}
                maxLength={48}
                autoCapitalize="characters"
                spellCheck={false}
                onChange={(event) => setCode(event.target.value.toUpperCase())}
                placeholder="MANNY"
              />
            </div>
          </div>
          <p className="af-metric-hint" style={{ margin: 0 }}>
            {appCopy(
              "Le lien devient useprocess.xyz/join/TONCODE. L'ancien code continue de marcher.",
              "Your link becomes useprocess.xyz/join/YOURCODE. The old code still works."
            )}
          </p>
          {error ? <p className="af-invite-error">{error}</p> : null}
          <div className="af-link-card-actions">
            <SuccessActionButton
              idleLabel={appCopy("Enregistrer", "Save")}
              validate={validate}
              onAction={async () => {
                try {
                  await onSaveInvite({
                    displayName: name.trim(),
                    code: parseAcquisitionCodeFromInput(code),
                  });
                } catch (err) {
                  setError(formatApplyError(err));
                  throw err;
                }
              }}
              onSuccess={() => {
                window.setTimeout(() => setEditing(false), 900);
              }}
            />
          </div>
        </div>
      ) : null}
    </div>
  );
}

function TikTokOverviewCard({ dashboard }) {
  const tiktok = dashboard?.tiktok || {};
  const accounts = Array.isArray(tiktok.accounts) ? tiktok.accounts : [];
  const totals = tiktok.totals || {};
  const metrics = [
    { label: appCopy("Comptes", "Accounts"), value: Number(totals.accounts || accounts.length) || 4 },
    { label: appCopy("Connectés", "Connected"), value: Number(totals.connected) || 3 },
    { label: appCopy("Abonnés", "Followers"), value: Number(totals.followers) || 128400 },
    { label: appCopy("Vues", "Views"), value: Number(totals.views) || 2140000 },
    { label: appCopy("Likes", "Likes"), value: Number(totals.likes) || 184000 },
    { label: appCopy("Vidéos", "Videos"), value: Number(totals.videoCount) || 47 },
  ];
  const previewAccounts = accounts.length
    ? accounts.slice(0, 3)
    : [
        { id: "a", handle: "glowup_prime", followers: 48200, views: 910000, likes: 64000, videoCount: 18, connected: true },
        { id: "b", handle: "debloat_man", followers: 31100, views: 740000, likes: 51200, videoCount: 15, connected: true },
        { id: "c", handle: "new_looksmax", followers: 49100, views: 490000, likes: 68800, videoCount: 14, connected: false },
      ];

  return (
    <div className="af-card af-card-pad af-tiktok-soon">
      <div className="af-card-head">
        <div className="af-tiktok-soon-brand">
          <img src="/assets/logos/tiktok.png" alt="" width={28} height={28} />
          <div>
            <div className="af-card-muted">TikTok</div>
            <h2>{appCopy("Stats TikTok", "TikTok stats")}</h2>
          </div>
        </div>
      </div>
      <div className="af-tiktok-soon-body">
        <div className="af-tiktok-soon-blur" aria-hidden="true">
          <div className="af-tiktok-soon-grid">
            {metrics.map((row) => (
              <div key={row.label} className="af-metric-col af-tiktok-soon-metric">
                <div className="af-metric-head">{row.label}</div>
                <div className="af-metric-val">{Number(row.value || 0).toLocaleString()}</div>
              </div>
            ))}
          </div>
          <div className="af-tiktok-accounts">
            {previewAccounts.map((row) => (
              <article key={row.id}>
                <span className={`af-tiktok-dot ${row.connected ? "is-on" : ""}`} />
                <strong>@{row.handle || row.name}</strong>
                <span>{Number(row.followers || 0).toLocaleString()} {appCopy("abonnés", "followers")}</span>
                <span>{Number(row.views || 0).toLocaleString()} {appCopy("vues", "views")}</span>
                <span>{Number(row.likes || 0).toLocaleString()} likes</span>
              </article>
            ))}
          </div>
        </div>
        <div className="af-tiktok-soon-overlay">
          <span className="af-tiktok-soon-emoji" aria-hidden>🚧</span>
          <strong>{appCopy("Disponible bientôt", "Coming soon")}</strong>
        </div>
      </div>
    </div>
  );
}

function OverviewPage({ dashboard, isPending, primaryCode, linkUrl, onSaveInvite }) {
  const earnings = dashboard?.stats?.lifetimeCents ?? 0;
  const rows = dashboard?.recentCommissions ?? [];
  const series = dashboard?.series || {};
  const stats = dashboard?.stats || {};
  const visits = Number(stats.linkViews || 0);
  const storeClicks = Number(stats.storeClicks || 0);
  const installs = Number(stats.referredCount || 0);
  const paywalls = Number(stats.paywallCount || 0);
  const sales = Math.max(
    Number(stats.paidCount || 0),
    Number(stats.activeSubscribers || 0),
    uniquePaidFromCommissions(rows)
  );
  const axisStart = series.days?.[0]
    ? formatShortDate(new Date(`${series.days[0]}T12:00:00Z`).getTime())
    : formatShortDate(Date.now() - 30 * 86400000);
  const axisEnd = formatShortDate(Date.now());
  const metrics = [
    {
      label: appCopy("Visites", "Visits"),
      hint: storeClicks
        ? appCopy(`${storeClicks} vers l'App Store`, `${storeClicks} App Store taps`)
        : appCopy("ouvertures de ton lien", "opens of your link"),
      value: visits,
      values: series.linkViews,
      color: "#3b82f6",
      icon: IconCursor,
    },
    {
      label: appCopy("Installs", "Installs"),
      hint: appCopy("app ouverte avec ton code", "app opened with your code"),
      value: installs,
      values: series.attributions,
      color: "#8b5cf6",
      icon: IconDownload,
    },
    {
      label: appCopy("Paywall", "Paywall"),
      hint: appCopy("ont vu l'offre", "reached the offer"),
      value: paywalls,
      values: series.paywalls,
      color: "#f59e0b",
      icon: IconPaywall,
    },
    {
      label: appCopy("Ventes", "Sales"),
      hint: appCopy("achats attribués", "attributed purchases"),
      value: sales,
      values: series.sales,
      color: "#14b8a6",
      icon: IconDollar,
    },
  ];

  return (
    <>
      {isPending ? (
        <PendingBanner displayName={dashboard?.displayName} />
      ) : null}

      <InviteLinkCard
        dashboard={dashboard}
        isPending={isPending}
        primaryCode={primaryCode}
        linkUrl={linkUrl}
        onSaveInvite={onSaveInvite}
      />

      {primaryCode ? (
        <div className="af-card af-link-card" style={{ marginTop: 16 }}>
          <div className="af-metrics-row">
            {metrics.map(({ label, hint, value, values, color, icon: Icon }) => (
              <div key={label} className="af-metric-col">
                <div className="af-metric-head">
                  <Icon style={{ color }} />
                  {label}
                </div>
                <div className="af-metric-val">{value}</div>
                <div className="af-metric-hint">{hint}</div>
                <MiniChart color={color} className="af-mini-chart" values={values} />
                <div className="af-chart-axis">
                  <span>{axisStart}</span>
                  <span>{axisEnd}</span>
                </div>
              </div>
            ))}
          </div>
          <div className="af-funnel">
            <div className="af-funnel-step">
              <span>{appCopy("Visites → installs", "Visits → installs")}</span>
              <strong>{formatPercent(installs, visits)}</strong>
            </div>
            <div className="af-funnel-step">
              <span>{appCopy("Installs → paywall", "Installs → paywall")}</span>
              <strong>{formatPercent(paywalls, installs)}</strong>
            </div>
            <div className="af-funnel-step">
              <span>{appCopy("Paywall → ventes", "Paywall → sales")}</span>
              <strong>{formatPercent(sales, paywalls)}</strong>
            </div>
          </div>
        </div>
      ) : null}

      <div className="af-card af-card-pad" style={{ marginTop: 16 }}>
        <div className="af-card-head">
          <div>
            <div className="af-card-muted">{appCopy("Gains totaux", "Total earnings")}</div>
            <div className="af-stat-value">{money(earnings)}</div>
          </div>
        </div>
        <MiniChart color="#10b981" values={series.earningsCents} />
        <div className="af-chart-axis">
          <span>{axisStart}</span>
          <span>{axisEnd}</span>
        </div>
      </div>

      <TikTokOverviewCard dashboard={dashboard} />

      <div className="af-card" style={{ marginTop: 16 }}>
        {rows.length === 0 ? (
          <div className="af-empty" style={{ minHeight: 200 }}>
            <IconCoin style={{ width: 28, height: 28, color: "#d1d5db" }} />
            <div className="af-empty-content">
              <h2>{appCopy("Aucune commission", "No commissions yet")}</h2>
              <p>
                {appCopy(
                  "Les commissions apparaissent ici dès qu'un install via ton lien s'abonne.",
                  "Commissions show up here as soon as an install from your link subscribes."
                )}
              </p>
            </div>
          </div>
        ) : (
          <div className="af-table-wrap">
            <table className="af-table">
              <thead>
                <tr>
                  <th>{appCopy("Type", "Type")}</th>
                  <th>{appCopy("Statut", "Status")}</th>
                  <th>{appCopy("Montant", "Amount")}</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.id}>
                    <td>{row.eventType || "—"}</td>
                    <td>
                      <span className={`af-badge ${row.status?.includes("paid") ? "paid" : row.status?.includes("payable") ? "payable" : "pending"}`}>
                        {row.status}
                      </span>
                    </td>
                    <td>{money(row.commissionCents, row.currency)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

function PayoutSidebarWidget({ dashboard, onConnect, onManage, busy }) {
  const payable = dashboard?.stats?.payableCents ?? 0;
  const paid = dashboard?.stats?.paidCents ?? 0;
  const stripe = stripeConnectState(dashboard);
  const ready = isStripePayoutReady(dashboard);
  const needsAction = stripe.accountId && !stripe.payoutsEnabled;

  return (
    <div className="af-payout-sidebar">
      <button type="button" className="af-payout-sidebar-head" onClick={() => onManage?.()}>
        <IconWallet style={{ width: 16, height: 16 }} />
        <span>{appCopy("Paiements", "Payouts")}</span>
        <IconChevronLeft style={{ width: 14, height: 14, transform: "rotate(180deg)", marginLeft: "auto", opacity: 0.35 }} />
      </button>
      <div className="af-payout-sidebar-rows">
        <div>
          <span className="af-payout-sidebar-label">{appCopy("À venir", "Upcoming payouts")}</span>
          <strong>{money(payable)}</strong>
        </div>
        <div>
          <span className="af-payout-sidebar-label">{appCopy("Reçus", "Received payouts")}</span>
          <strong>{money(paid)}</strong>
        </div>
      </div>
      {ready ? (
        <button type="button" className="af-btn af-btn-sm af-btn-black af-payout-sidebar-cta" onClick={onManage} disabled={busy}>
          {appCopy("Gérer Stripe", "Manage Stripe")}
        </button>
      ) : (
        <button type="button" className="af-btn af-btn-sm af-btn-black af-payout-sidebar-cta" onClick={onConnect} disabled={busy}>
          {busy
            ? appCopy("Ouverture de Stripe…", "Opening Stripe…")
            : needsAction
              ? appCopy("Finaliser Stripe", "Finish Stripe setup")
              : appCopy("Connecter un compte", "Connect payout method")}
        </button>
      )}
      <p className="af-payout-sidebar-note">
        {appCopy("Virements via Stripe Connect", "Payouts via Stripe Connect")}
      </p>
    </div>
  );
}

function PendingBanner({ displayName }) {
  return (
    <div className="af-pending-banner">
      <IconInfo />
      <div style={{ flex: 1 }}>
        <h3>{appCopy("Candidature en cours de validation", "Application under review")}</h3>
        <p>
          {appCopy(
            `Ton compte clipper (${displayName || "Process"}) est en attente. Envoie ton @ TikTok ou Instagram pour activer ton code à ${COMMISSION_PERCENT} %.`,
            `Your clipper account (${displayName || "Process"}) is pending. Send your TikTok or Instagram @ to activate your ${COMMISSION_PERCENT}% code.`
          )}
        </p>
        <SocialChannelForm displayName={displayName} compact />
      </div>
    </div>
  );
}

function CustomersPage({ dashboard }) {
  const count = dashboard?.stats?.referredCount ?? 0;

  if (count === 0) {
    return (
      <div className="af-card af-empty">
        <div className="af-empty-ghost">
          {[1, 2].map((i) => (
            <div key={i} className="af-ghost-row">
              <div className="af-ghost-avatar" />
              <div className="af-ghost-bars">
                <div className="af-ghost-bar" />
                <div className="af-ghost-bar short" />
              </div>
            </div>
          ))}
        </div>
        <div className="af-empty-content">
          <h2>{appCopy("Aucun install", "No installs yet")}</h2>
          <p>
            {appCopy(
              "Les installs attribués apparaîtront ici dès qu'un utilisateur ouvre l'app avec ton code.",
              "Attributed installs will show here as soon as someone opens the app with your code."
            )}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="af-card af-card-pad">
      <p>{appCopy("Installs attribués", "Attributed installs")}: <strong>{count}</strong></p>
    </div>
  );
}

function PayoutsPage({ dashboard, onConnectStripe, onManageStripe, stripeBusy }) {
  const pending = dashboard?.stats?.pendingCents ?? 0;
  const payable = dashboard?.stats?.payableCents ?? 0;
  const paid = dashboard?.stats?.paidCents ?? 0;
  const payouts = dashboard?.payouts ?? [];
  const stripe = stripeConnectState(dashboard);
  const stripeReady = isStripePayoutReady(dashboard);

  return (
    <>
      <div className="af-page-head">
        <h1>
          {appCopy("Paiements", "Payouts")}
          <IconInfo />
        </h1>
      </div>

      <div className="af-payout-cards">
        {[
          { label: appCopy("En attente", "Pending"), amount: pending, dot: "orange" },
          { label: appCopy("Disponible", "Available"), amount: payable, dot: "blue" },
          { label: appCopy("Complété", "Completed"), amount: paid, dot: "green" },
        ].map((card) => (
          <div key={card.label} className="af-card af-payout-card">
            <div className="af-status-label">
              <span className={`af-dot ${card.dot}`} />
              {card.label}
            </div>
            <div className="af-stat-value" style={{ fontSize: 24 }}>
              {money(card.amount)}
            </div>
          </div>
        ))}
      </div>

      <p className="af-payout-rules">
        {appCopy(
          `Commission : ${COMMISSION_PERCENT} % du net sur chaque vente. Les primes vues se débloquent à ${VIEW_BONUS_UNLOCK_EUR} € de commission déjà générée (iPhone à ${VIEW_BONUS_FLAGSHIP_UNLOCK_EUR} €). Toutes les vidéos du compte comptent.`,
          `Commission: ${COMMISSION_PERCENT}% of the net on every sale. View bonuses unlock at ${VIEW_BONUS_UNLOCK_EUR} EUR of commission already earned (iPhone at ${VIEW_BONUS_FLAGSHIP_UNLOCK_EUR} EUR). Every video on the account counts.`
        )}
      </p>

      <div className="af-card af-card-pad af-stripe-panel" style={{ marginBottom: 16 }}>
        <div className="af-stripe-panel-head">
          <IconWallet style={{ width: 18, height: 18 }} />
          <div>
            <h3 style={{ margin: 0, fontSize: 14 }}>{appCopy("Méthode de paiement", "Payout method")}</h3>
            <p className="af-card-muted" style={{ margin: "4px 0 0" }}>
              {stripeReady
                ? appCopy("Stripe Connect — virements bancaires", "Stripe Connect — bank transfers")
                : appCopy("Connecte ton compte bancaire via Stripe.", "Connect your bank account via Stripe.")}
            </p>
          </div>
        </div>

        {stripeReady ? (
          <div className="af-stripe-status ok">
            <IconCheck style={{ width: 16, height: 16 }} />
            {appCopy("Compte connecté — prêt à recevoir", "Account connected — ready to receive payouts")}
          </div>
        ) : stripe.accountId ? (
          <div className="af-stripe-status warn">
            <IconInfo style={{ width: 16, height: 16 }} />
            {appCopy("Configuration Stripe incomplète", "Stripe setup incomplete")}
          </div>
        ) : null}

        <div className="af-stripe-panel-actions">
          {stripeReady ? (
            <button type="button" className="af-btn af-btn-sm af-btn-black" onClick={onManageStripe} disabled={stripeBusy}>
              {appCopy("Ouvrir le tableau Stripe", "Open Stripe dashboard")}
            </button>
          ) : (
            <button type="button" className="af-btn af-btn-sm af-btn-black" onClick={onConnectStripe} disabled={stripeBusy}>
              {stripeBusy
                ? appCopy("Ouverture de Stripe…", "Opening Stripe…")
                : appCopy("Connecter un compte", "Connect payout method")}
            </button>
          )}
        </div>
        <p className="af-stripe-powered-inline">
          {appCopy("Process s'associe à Stripe pour des paiements sécurisés.", "Process partners with Stripe for secure payments.")}
        </p>
      </div>

      <div className="af-card">
        <div className="af-toolbar" style={{ padding: "12px 16px", margin: 0 }}>
          <button type="button" className="af-chip-btn">
            <IconFilter />
            {appCopy("Filtrer", "Filter")}
            <IconChevronDown />
          </button>
        </div>
        {payouts.length === 0 ? (
          <div className="af-empty">
            <div className="af-empty-ghost">
              {[1, 2].map((i) => (
                <div key={i} className="af-ghost-row">
                  <IconWallet style={{ width: 18, height: 18, color: "#9ca3af" }} />
                  <div className="af-ghost-bars">
                    <div className="af-ghost-bar" />
                    <div className="af-ghost-bar short" />
                  </div>
                </div>
              ))}
            </div>
            <div className="af-empty-content">
              <h2>{appCopy("Aucun paiement trouvé", "No payouts found")}</h2>
              <p>
                {appCopy(
                  "Aucun paiement n'a encore été initié pour ce programme.",
                  "No payouts have been initiated for this program yet."
                )}
              </p>
            </div>
          </div>
        ) : (
          <div className="af-table-wrap">
            <table className="af-table">
              <thead>
                <tr>
                  <th>{appCopy("Date", "Date")}</th>
                  <th>{appCopy("Montant", "Amount")}</th>
                  <th>{appCopy("Statut", "Status")}</th>
                </tr>
              </thead>
              <tbody>
                {payouts.map((p) => (
                  <tr key={p.id}>
                    <td>{formatShortDate(p.createdAt)}</td>
                    <td>{money(p.amountCents, p.currency)}</td>
                    <td>{p.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}

function SettingsPage({ user, dashboard, onConnectStripe, onManageStripe, stripeBusy, onSignOut, onSaveInvite }) {
  const [tab, setTab] = useState("general");
  const [displayName, setDisplayName] = useState(dashboard?.displayName || "");
  const [code, setCode] = useState(dashboard?.primaryCode || dashboard?.codes?.[0]?.code || "");
  const [saveError, setSaveError] = useState("");
  const accountEmail = String(dashboard?.email || user?.email || "").trim();
  const initials = (displayName || accountEmail || "P").charAt(0).toUpperCase();
  const emailIsRelay = isAppleRelayEmail(accountEmail);
  const [loginEmail, setLoginEmail] = useState(emailIsRelay ? "" : accountEmail);
  const [emailError, setEmailError] = useState("");

  useEffect(() => {
    setDisplayName(dashboard?.displayName || "");
    setCode(dashboard?.primaryCode || dashboard?.codes?.[0]?.code || "");
  }, [dashboard?.displayName, dashboard?.primaryCode, dashboard?.codes]);

  useEffect(() => {
    setLoginEmail(isAppleRelayEmail(accountEmail) ? "" : accountEmail);
  }, [accountEmail]);

  async function saveLoginEmail() {
    setEmailError("");
    const next = loginEmail.trim().toLowerCase();
    if (!next || !next.includes("@")) {
      setEmailError(appCopy("Email invalide.", "Invalid email address."));
      throw new Error("INVALID_EMAIL");
    }
    if (isAppleRelayEmail(next)) {
      setEmailError(appleRelayHelpMessage());
      throw new Error("APPLE_RELAY_EMAIL");
    }
    try {
      const auth = await getFirebaseAuth();
      const token = await getAuthToken(auth.currentUser, true);
      await affiliateApi("affiliateSetLoginEmail", { token, body: { email: next } });
      await auth.currentUser?.reload?.();
    } catch (err) {
      setEmailError(formatAuthError(err));
      throw err;
    }
  }

  async function saveInvite() {
    setSaveError("");
    try {
      await onSaveInvite({
        displayName: displayName.trim(),
        code: parseAcquisitionCodeFromInput(code),
      });
    } catch (err) {
      setSaveError(formatApplyError(err));
      throw err;
    }
  }

  return (
    <div className="af-settings-layout">
      <nav className="af-settings-nav">
        <h2>
          <IconChevronLeft style={{ width: 14, height: 14 }} />
          {appCopy("Paramètres", "Settings")}
        </h2>
        <p className="af-settings-group">{appCopy("Compte", "Account")}</p>
        <button
          type="button"
          className={`af-settings-item ${tab === "general" ? "is-active" : ""}`}
          onClick={() => setTab("general")}
        >
          <IconSettings />
          {appCopy("Général", "General")}
        </button>
        <button
          type="button"
          className={`af-settings-item ${tab === "security" ? "is-active" : ""}`}
          onClick={() => setTab("security")}
        >
          <IconShield />
          {appCopy("Sécurité", "Security")}
        </button>
        <p className="af-settings-group">{appCopy("Session", "Session")}</p>
        <button
          type="button"
          className="af-settings-item af-settings-logout"
          onClick={onSignOut}
        >
          <IconLogout />
          {appCopy("Se déconnecter", "Log out")}
        </button>
      </nav>

      <div>
        {tab === "general" ? (
          <>
            <h1 style={{ margin: "0 0 20px", fontSize: 22 }}>{appCopy("Général", "General")}</h1>

            <div className="af-card af-setting-card">
              <div className="af-card-pad">
                <div className="af-setting-body-row">
                  <div style={{ flex: 1 }}>
                    <h3>{appCopy("Ton prénom", "Your first name")}</h3>
                    <p className="desc">
                      {appCopy(
                        "C'est le nom qui apparaît sur ta page d'invitation (« amine t'invite sur Process »).",
                        "This is the name on your invite page (“alex invites you to Process”)."
                      )}
                    </p>
                    <input
                      className="af-input"
                      value={displayName}
                      onChange={(e) => setDisplayName(e.target.value)}
                      maxLength={32}
                    />
                    <h3 style={{ marginTop: 18 }}>{appCopy("Ton code clipper", "Your clipper code")}</h3>
                    <p className="desc">
                      {appCopy(
                        "Ça choisit ton lien : useprocess.xyz/join/TONCODE. L'ancien code continue de marcher.",
                        "This picks your link: useprocess.xyz/join/YOURCODE. The old code still works."
                      )}
                    </p>
                    <input
                      className="af-input"
                      value={code}
                      maxLength={48}
                      autoCapitalize="characters"
                      spellCheck={false}
                      onChange={(e) => setCode(e.target.value.toUpperCase())}
                    />
                    {saveError ? <p className="af-invite-error" style={{ marginTop: 10 }}>{saveError}</p> : null}
                  </div>
                </div>
              </div>
              <div className="af-setting-footer">
                <span>{appCopy("32 caractères max. pour le prénom.", "Max 32 characters for the name.")}</span>
                <SuccessActionButton
                  idleLabel={appCopy("Enregistrer", "Save Changes")}
                  disabled={!onSaveInvite}
                  onAction={saveInvite}
                />
              </div>
            </div>

            <div className="af-card af-setting-card">
              <div className="af-card-pad">
                <div className="af-setting-body-row">
                  <div style={{ flex: 1 }}>
                    <h3>{appCopy("Ton email", "Your Email")}</h3>
                    <p className="desc">
                      {appCopy(
                        "Email de connexion et notifications Process.",
                        "This will be the email you use to log in to Process and receive notifications."
                      )}
                    </p>
                    {emailIsRelay ? (
                      <p className="af-invite-error" style={{ marginTop: 0, marginBottom: 10 }}>
                        {appCopy(
                          "Ton compte utilise l'email masqué d'Apple — il ne peut pas recevoir nos liens de connexion. Mets un vrai email ici pour pouvoir te connecter depuis un ordinateur.",
                          "Your account uses Apple's hidden email — it can't receive our sign-in links. Set a real email here so you can sign in from a computer."
                        )}
                      </p>
                    ) : null}
                    <input
                      className="af-input"
                      type="email"
                      value={loginEmail}
                      spellCheck={false}
                      autoCapitalize="none"
                      placeholder={emailIsRelay ? "ton@email.com" : accountEmail}
                      onChange={(e) => setLoginEmail(e.target.value)}
                    />
                    {emailError ? (
                      <p className="af-invite-error" style={{ marginTop: 10 }}>{emailError}</p>
                    ) : null}
                    {!user?.email && accountEmail && !emailIsRelay ? (
                      <p className="desc" style={{ marginTop: 10 }}>
                        {appCopy(
                          "Pour te reconnecter sur un autre appareil, utilise Connexion → Recevoir le lien avec cet email.",
                          "To sign in on another device, use Sign in → Send the link with this email."
                        )}
                      </p>
                    ) : null}
                  </div>
                </div>
              </div>
              <div className="af-setting-footer">
                <a href={`mailto:${SUPPORT_EMAIL}`} style={{ color: "var(--af-accent)", textDecoration: "none" }}>
                  {appCopy("Préférences email", "Manage email preferences")} →
                </a>
                <SuccessActionButton
                  idleLabel={appCopy("Enregistrer", "Save Changes")}
                  disabled={!loginEmail.trim() || loginEmail.trim().toLowerCase() === accountEmail.toLowerCase()}
                  onAction={saveLoginEmail}
                />
              </div>
            </div>

            <div className="af-card af-setting-card">
              <div className="af-card-pad">
                <div className="af-setting-body-row">
                  <div style={{ flex: 1 }}>
                    <h3>{appCopy("Paiements Stripe", "Stripe payouts")}</h3>
                    <p className="desc">
                      {appCopy(
                        "Connecte ton compte bancaire via Stripe Connect pour recevoir tes commissions.",
                        "Connect your bank account via Stripe Connect to receive your commissions."
                      )}
                    </p>
                    {isStripePayoutReady(dashboard) ? (
                      <div className="af-stripe-status ok" style={{ marginTop: 12 }}>
                        <IconCheck style={{ width: 16, height: 16 }} />
                        {appCopy("Compte connecté", "Account connected")}
                      </div>
                    ) : (
                      <div className="af-stripe-status warn" style={{ marginTop: 12 }}>
                        <IconInfo style={{ width: 16, height: 16 }} />
                        {appCopy("Compte non connecté", "Payout method not connected")}
                      </div>
                    )}
                  </div>
                  <div className="af-avatar-preview">{initials}</div>
                </div>
              </div>
              <div className="af-setting-footer">
                <span>{appCopy("Virements sécurisés par Stripe.", "Secure payouts powered by Stripe.")}</span>
                {isStripePayoutReady(dashboard) ? (
                  <button type="button" className="af-btn af-btn-sm af-btn-black" onClick={onManageStripe} disabled={stripeBusy}>
                    {appCopy("Gérer Stripe", "Manage Stripe")}
                  </button>
                ) : (
                  <button type="button" className="af-btn af-btn-sm af-btn-black" onClick={onConnectStripe} disabled={stripeBusy}>
                    {stripeBusy
                      ? appCopy("Ouverture de Stripe…", "Opening Stripe…")
                      : appCopy("Connecter", "Connect")}
                  </button>
                )}
              </div>
            </div>

            <div className="af-card af-setting-card">
              <div className="af-card-pad">
                <h3>{appCopy("Ton identifiant", "Your User ID")}</h3>
                <p className="desc">
                  {appCopy(
                    "Identifiant unique de ton compte clipper.",
                    "This is your unique account identifier on Process."
                  )}
                </p>
                <input className="af-input" value={dashboard?.affiliateId || user?.uid || ""} readOnly />
              </div>
              <div className="af-setting-footer">
                <span>{appCopy("Utilisé pour le support.", "This may be used to identify your account in support.")}</span>
                <CopyButton text={dashboard?.affiliateId || user?.uid || ""} />
              </div>
            </div>

            <div className="af-card af-setting-card">
              <div className="af-card-pad">
                <h3>{appCopy("Se déconnecter", "Log out")}</h3>
                <p className="desc">
                  {appCopy(
                    "Ferme ta session sur ce navigateur. Tes liens et tes gains restent inchangés.",
                    "Sign out of this browser. Your links and earnings stay unchanged."
                  )}
                </p>
              </div>
              <div className="af-setting-footer">
                <span>{appCopy("Tu pourras te reconnecter à tout moment.", "You can sign back in anytime.")}</span>
                <button type="button" className="af-btn af-btn-sm af-btn-secondary" onClick={onSignOut}>
                  {appCopy("Se déconnecter", "Log out")}
                </button>
              </div>
            </div>
          </>
        ) : (
          <>
            <h1 style={{ margin: "0 0 20px", fontSize: 22 }}>{appCopy("Sécurité", "Security")}</h1>
            <div className="af-card af-card-pad">
              <h3>{appCopy("Session", "Session")}</h3>
              <p className="desc">
                {appCopy(
                  "Déconnecte-toi de ce navigateur.",
                  "Sign out of this browser."
                )}
              </p>
              <button type="button" className="af-btn af-btn-secondary" onClick={onSignOut}>
                {appCopy("Se déconnecter", "Log out")}
              </button>
            </div>
          </>
        )}

        <div className="af-card af-setting-card" style={{ marginTop: 16 }}>
          <div className="af-card-pad">
            <h3>{appCopy("Supprimer le compte", "Delete Account")}</h3>
            <p className="desc">
              {appCopy(
                "Contacte le support Process pour supprimer définitivement ton compte clipper.",
                "Contact Process support to permanently delete your clipper account."
              )}
            </p>
          </div>
          <div className="af-setting-footer danger">
            <span />
            <a className="af-btn-danger" href={`mailto:${SUPPORT_EMAIL}`} style={{ textDecoration: "none" }}>
              {appCopy("Contacter le support", "Contact support")}
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}

function DashboardShell({
  route,
  go,
  query,
  user,
  dashboard,
  isPending,
  primaryCode,
  linkUrl,
  onConnectStripe,
  onManageStripe,
  stripeBusy,
  onSignOut,
  onSaveInvite,
}) {
  const pageTitles = {
    overview: appCopy("Overview", "Overview"),
    tiktoks: appCopy("Format", "Format"),
    format: appCopy("Format", "Format"),
    slideshowlab: "SlideshowLab",
    assets: "Process Assets",
    methode: appCopy("Démarrage", "Getting started"),
    clippers: appCopy("Clippers", "Clippers"),
    automatisation: appCopy("Automatiser", "Automate"),
    us: appCopy("Poster US", "Post in the US"),
    utiles: appCopy("Utiles", "Useful"),
    payouts: appCopy("Paiements", "Payouts"),
    settings: appCopy("Paramètres", "Settings"),
  };

  const navItems = [
    { id: "overview", label: appCopy("Overview", "Overview"), icon: IconOverview },
    { id: "methode", label: appCopy("Démarrage", "Getting started"), icon: IconCursor },
    { id: "slideshowlab", label: "SlideshowLab", icon: IconSlides },
    { id: "assets", label: "Process Assets", icon: ProcessNavIcon },
    { id: "format", label: appCopy("Format", "Format"), icon: IconTikTok },
    { id: "clippers", label: appCopy("Clippers", "Clippers"), icon: IconTrophy },
    { id: "automatisation", label: appCopy("Automatiser", "Automate"), icon: IconSpark },
  ];
  const toolItems = [
    { id: "us", label: appCopy("Poster US", "Post in the US"), icon: IconGlobe, href: "us" },
    { id: "shadowban", label: appCopy("Shadowban", "Shadowban"), icon: IconShield, href: "utiles?t=shadowban" },
    { id: "questions", label: appCopy("Questions", "Questions"), icon: IconHelp, href: "utiles?t=questions" },
  ];
  const usefulTopic = route === "utiles" ? String(query?.t || "") : "";
  const [navOpen, setNavOpen] = useState(false);
  const mobileTitle =
    route === "utiles" && usefulTopic
      ? toolItems.find((item) => item.id === usefulTopic)?.label || pageTitles.utiles
      : pageTitles[route] || pageTitles.overview;

  const goNav = useCallback(
    (id) => {
      setNavOpen(false);
      go(id);
    },
    [go]
  );

  useEffect(() => {
    setNavOpen(false);
  }, [route, query]);

  useEffect(() => {
    if (!navOpen) return undefined;
    const onKey = (event) => {
      if (event.key === "Escape") setNavOpen(false);
    };
    document.addEventListener("keydown", onKey);
    document.body.classList.add("af-nav-lock");
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.classList.remove("af-nav-lock");
    };
  }, [navOpen]);

  function renderPage() {
    switch (route) {
      case "format":
      case "tiktoks":
      case "formats":
        return <AffiliateFormatsPage user={user} />;
      case "slideshowlab":
        return <AffiliateSlideshowLabPage />;
      case "assets":
        return <AffiliateProcessAssetsPage />;
      case "methode":
        return (
          <AffiliateMethodPage
            linkUrl={linkUrl}
            primaryCode={primaryCode}
            onGoLinks={() => go("overview")}
            onGoFormats={() => go("format")}
          />
        );
      case "clippers":
        return <AffiliateClippersPage user={user} dashboard={dashboard} />;
      case "automatisation":
        return <AffiliateAutomationPage user={user} dashboard={dashboard} query={query} go={go} />;
      case "us":
        return <AffiliateUsPage />;
      case "utiles":
        return (
          <AffiliateUsefulPage
            topic={usefulTopic}
            displayName={dashboard?.displayName}
            email={dashboard?.email || user?.email}
            onOpenTopic={(id) => go(`utiles?t=${id}`)}
            onBack={() => go("utiles")}
            onOpenUs={() => go("us")}
          />
        );
      case "customers":
        return <CustomersPage dashboard={dashboard} />;
      case "payouts":
        return (
          <PayoutsPage
            dashboard={dashboard}
            onConnectStripe={onConnectStripe}
            onManageStripe={onManageStripe}
            stripeBusy={stripeBusy}
          />
        );
      case "settings":
        return (
          <SettingsPage
            user={user}
            dashboard={dashboard}
            onConnectStripe={onConnectStripe}
            onManageStripe={onManageStripe}
            stripeBusy={stripeBusy}
            onSignOut={onSignOut}
            onSaveInvite={onSaveInvite}
          />
        );
      default:
        return (
          <OverviewPage
            dashboard={dashboard}
            isPending={isPending}
            primaryCode={primaryCode}
            linkUrl={linkUrl}
            onSaveInvite={onSaveInvite}
          />
        );
    }
  }

  const pageContent = (
    <Suspense fallback={<div className="af-page-pending" aria-hidden="true" />}>{renderPage()}</Suspense>
  );

  return (
    <>
      {navOpen ? (
        <button
          type="button"
          className="af-nav-backdrop"
          aria-label={appCopy("Fermer le menu", "Close menu")}
          onClick={() => setNavOpen(false)}
        />
      ) : null}
      <div className={`af-app af-shell${navOpen ? " is-nav-open" : ""}`}>
        <header className="af-mobile-bar">
          <button
            type="button"
            className="af-mobile-bar__btn"
            onClick={() => setNavOpen(true)}
            aria-label={appCopy("Ouvrir le menu", "Open menu")}
          >
            <IconMenu />
          </button>
          <strong className="af-mobile-bar__title">{mobileTitle}</strong>
          <button
            type="button"
            className="af-mobile-bar__user"
            onClick={() => goNav("settings")}
            aria-label={appCopy("Paramètres", "Settings")}
          >
            <ProcessAppIcon size={22} />
          </button>
        </header>

        <aside className="af-sidebar" id="af-sidebar">
          <div className="af-sidebar-logo-row">
            <div className="af-sidebar-logo">PROCE$$ CLIPPING</div>
            <button
              type="button"
              className="af-sidebar-close"
              onClick={() => setNavOpen(false)}
              aria-label={appCopy("Fermer le menu", "Close menu")}
            >
              <IconClose />
            </button>
          </div>

          <nav className="af-nav" aria-label={appCopy("Navigation", "Navigation")}>
            {navItems.map(({ id, label, icon: Icon }) => (
              <button
                key={id}
                type="button"
                className={`af-nav-item ${route === id ? "is-active" : ""}`}
                onClick={() => goNav(id)}
              >
                <Icon />
                {label}
              </button>
            ))}
            <div className="af-nav-section">
              <button
                type="button"
                className={`af-nav-label ${route === "utiles" && !usefulTopic ? "is-active" : ""}`}
                onClick={() => goNav("utiles")}
              >
                {appCopy("Utiles", "Useful")}
              </button>
              {toolItems.map(({ id, label, icon: Icon, href }) => (
                <button
                  key={id}
                  type="button"
                  className={`af-nav-item is-sub ${
                    (id === "us" && route === "us") || (id !== "us" && route === "utiles" && usefulTopic === id)
                      ? "is-active"
                      : ""
                  }`}
                  onClick={() => goNav(href)}
                >
                  <Icon />
                  {label}
                </button>
              ))}
            </div>
          </nav>

          <PayoutSidebarWidget
            dashboard={dashboard}
            onConnect={onConnectStripe}
            onManage={() => {
              setNavOpen(false);
              if (isStripePayoutReady(dashboard)) {
                onManageStripe();
              } else {
                go("payouts");
              }
            }}
            busy={stripeBusy}
          />

          <button
            type="button"
            className={`af-sidebar-user ${route === "settings" ? "is-active" : ""}`}
            onClick={() => goNav("settings")}
            aria-label={appCopy("Paramètres", "Settings")}
          >
            <ProcessAppIcon size={24} />
            <div className="af-sidebar-user-text">
              <strong>{dashboard?.displayName || "Process"}</strong>
              <span>{dashboard?.email || user?.email || ""}</span>
            </div>
            <IconSettings className="af-sidebar-user-gear" />
          </button>
        </aside>

        <main className="af-main">
          {route !== "payouts" && route !== "settings" && route !== "methode" && route !== "tiktoks" && route !== "format" && route !== "formats" && route !== "slideshowlab" && route !== "assets" && route !== "clippers" && route !== "automatisation" && route !== "us" && route !== "utiles" ? (
            <div className="af-page-head">
              <h1>
                {pageTitles[route] || pageTitles.overview}
                <IconInfo />
              </h1>
            </div>
          ) : null}
          <div className="af-page-panel" key={`${route}:${query?.t || ""}`}>
            {pageContent}
          </div>
        </main>
      </div>
    </>
  );
}

export function AffiliateApp() {
  const localPreview = isAffiliateLocalPreview();
  const sessionRef = useRef(peekAffiliateSession());
  const [, setLangTick] = useState(0);
  const [route, go, query] = useHashRoute();
  const [user, setUser] = useState(() => (localPreview ? LOCAL_PREVIEW_USER : null));
  const [dashboard, setDashboard] = useState(() =>
    localPreview ? LOCAL_PREVIEW_DASHBOARD : sessionRef.current?.dashboard || null
  );
  const [dashboardLookup, setDashboardLookup] = useState(() =>
    localPreview
      ? "ready"
      : sessionRef.current?.dashboard
        ? "ready"
        : sessionRef.current?.uid
          ? "pending"
          : "missing"
  );
  const [bootstrapping, setBootstrapping] = useState(() =>
    localPreview ? false : Boolean(sessionRef.current?.uid)
  );
  const [busy, setBusy] = useState(false);
  const [stripeBusy, setStripeBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [email, setEmail] = useState(() => getConsumedApplyPrefill()?.email || "");
  const [applyAuthMode, setApplyAuthMode] = useState("signup");
  const [authNotice, setAuthNotice] = useState("");
  const [authNoticeTone, setAuthNoticeTone] = useState("info");
  const [authBusy, setAuthBusy] = useState(false);
  const [emailLinkConfirm, setEmailLinkConfirm] = useState(false);
  const bootstrappedRef = useRef(false);
  const dashboardLoadRef = useRef(null);
  const dashboardUserRef = useRef(null);
  const applyPrefill = getConsumedApplyPrefill();

  useEffect(() => {
    warmFirebaseAuth();
    applySiteDocumentLanguage();
    return subscribeSiteLanguage(() => {
      applySiteDocumentLanguage();
      setLangTick((n) => n + 1);
    });
  }, []);

  const loadDashboard = useCallback(async (nextUser, { silent = false, force = false } = {}) => {
    if (isAffiliateLocalPreview()) return LOCAL_PREVIEW_DASHBOARD;
    if (!nextUser) return null;

    if (
      !force &&
      dashboardLoadRef.current &&
      dashboardUserRef.current === nextUser.uid
    ) {
      return dashboardLoadRef.current;
    }

    dashboardUserRef.current = nextUser.uid;

    const job = (async () => {
      try {
        const token = await getAuthToken(nextUser, false);
        const data = await affiliateApi("affiliateDashboard", { token, timeoutMs: 8000 });
        setDashboard(data);
        writeDashboardCache(nextUser.uid, data);
        setDashboardLookup("ready");
        warmAffiliateFunctions();
        return data;
      } catch (err) {
        if (err.status === 404) {
          setDashboard(null);
          clearDashboardCache(nextUser.uid);
          setDashboardLookup("missing");
        } else {
          setDashboardLookup((prev) => (prev === "ready" ? "ready" : "missing"));
          if (!silent) setError(err.message || "dashboard_error");
        }
        throw err;
      } finally {
        if (dashboardLoadRef.current === job) {
          dashboardLoadRef.current = null;
        }
      }
    })();

    dashboardLoadRef.current = job;
    return job;
  }, []);

  useEffect(() => {
    let cancelled = false;
    let unsub = () => {};
    (async () => {
      if (isAffiliateLocalPreview()) {
        setUser(LOCAL_PREVIEW_USER);
        setDashboard(LOCAL_PREVIEW_DASHBOARD);
        setDashboardLookup("ready");
        bootstrappedRef.current = true;
        setBootstrapping(false);
        return;
      }
      if (!isFirebaseConfigured()) {
        setBootstrapping(false);
        return;
      }
      try {
        if (readPortalHandoffCode()) {
          try {
            const handoffResult = await completePortalHandoff();
            if (handoffResult?.next) go(handoffResult.next);
          } catch (handoffErr) {
            if (!cancelled) {
              setError(formatAuthError(handoffErr) || "handoff_failed");
              setApplyAuthMode("login");
              go("apply");
            }
          }
        }
        if (hrefLooksLikeEmailLink()) {
          try {
            const linkResult = await completeAffiliateEmailLink();
            if (linkResult?.needsEmail) {
              if (!cancelled) {
                setEmailLinkConfirm(true);
                setApplyAuthMode("login");
                const fromQuery = new URLSearchParams(window.location.search).get("email") || "";
                if (fromQuery) setEmail(fromQuery.trim());
                go("apply");
              }
            } else if (linkResult?.next) {
              go(linkResult.next);
            }
          } catch (linkErr) {
            if (!cancelled) {
              setError(formatAuthError(linkErr) || linkErr?.message || "email_link_failed");
              setApplyAuthMode("login");
              go("apply");
            }
          }
        }
        const auth = await getFirebaseAuth();
        const { onAuthStateChanged } = await getFirebaseAuthModule();
        unsub = onAuthStateChanged(auth, (nextUser) => {
          if (cancelled) return;
          setUser(nextUser);

          if (!nextUser) {
            forgetAffiliateSession(dashboardUserRef.current || sessionRef.current?.uid);
            sessionRef.current = null;
            setDashboard(null);
            setDashboardLookup("missing");
            dashboardUserRef.current = null;
            bootstrappedRef.current = true;
            setBootstrapping(false);
            return;
          }

          rememberAffiliateUid(nextUser.uid);
          sessionRef.current = { uid: nextUser.uid, dashboard: readDashboardCache(nextUser.uid) };

          const cached = sessionRef.current.dashboard;
          if (cached) {
            setDashboard(cached);
            setDashboardLookup("ready");
            bootstrappedRef.current = true;
            setBootstrapping(false);
            void loadDashboard(nextUser, { silent: true });
            return;
          }

          if (bootstrappedRef.current) {
            setBootstrapping(false);
            void loadDashboard(nextUser, { silent: true });
            return;
          }

          void (async () => {
            try {
              await loadDashboard(nextUser, { silent: true });
            } finally {
              if (!cancelled) {
                bootstrappedRef.current = true;
                setBootstrapping(false);
              }
            }
          })();
        });
      } catch (err) {
        if (!cancelled) {
          setError(err.message || "firebase_error");
          setBootstrapping(false);
        }
      }
    })();
    return () => {
      cancelled = true;
      unsub();
    };
  }, [loadDashboard]);

  useEffect(() => {
    if (bootstrapping) return;
    if (!user && !LANDING_HASHES.has(route) && !["apply", "auth"].includes(route)) {
      go("program");
    }
    if (user && dashboard) {
      if (!isOnboardingUnlocked(user.uid)) markOnboardingUnlocked(user.uid);
      if (LANDING_HASHES.has(route) || route === "apply") {
        go("overview");
      }
      return;
    }
    if (
      user &&
      !dashboard &&
      dashboardLookup === "missing" &&
      !LANDING_HASHES.has(route) &&
      route !== "apply" &&
      route !== "auth"
    ) {
      go("program");
    }
  }, [bootstrapping, user, dashboard, dashboardLookup, route, go]);

  useEffect(() => {
    if (bootstrapping) return;
    if (!hasAffiliatePrefill(applyPrefill)) return;
    if (user && dashboard) return;

    if (applyPrefill.email && !email) {
      setEmail(applyPrefill.email);
    }

    if (route !== "apply" && LANDING_HASHES.has(route)) {
      go("apply");
    }
  }, [bootstrapping, user, dashboard, route, go, applyPrefill, email]);

  useEffect(() => {
    if (!user || bootstrapping) return;
    const query = readHashQuery();
    if (query.stripe !== "return" && query.stripe !== "refresh") return;

    let cancelled = false;
    void (async () => {
      setStripeBusy(true);
      setError("");
      try {
        const token = await getAuthToken(user, false);
        await affiliateApi("affiliateStripeConnectSync", { token, timeoutMs: 8000 });
        if (!cancelled) {
          await loadDashboard(user, { silent: true, force: true });
          if (query.stripe === "return") {
            setSuccess(appCopy("Compte Stripe connecté.", "Stripe account connected."));
          }
        }
      } catch (err) {
        if (!cancelled) {
          setError(err.message || "stripe_sync_failed");
        }
      } finally {
        if (!cancelled) {
          setStripeBusy(false);
          navigateHash("payouts");
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, [user, bootstrapping, loadDashboard]);

  async function startStripeConnect() {
    if (!user || stripeBusy) return;
    setStripeBusy(true);
    setError("");
    const safety = window.setTimeout(() => setStripeBusy(false), 10000);
    try {
      const token = await getAuthToken(user, false);
      const result = await affiliateApi("affiliateStripeConnectStart", { token, timeoutMs: 8000 });
      if (result?.url) {
        window.location.assign(result.url);
        return;
      }
      throw new Error("STRIPE_NOT_CONFIGURED");
    } catch (err) {
      window.clearTimeout(safety);
      setError(
        err.message === "TIMEOUT" || err.message === "STRIPE_TIMEOUT"
          ? appCopy("Stripe met trop de temps. Réessaie.", "Stripe is taking too long. Try again.")
          : err.message || "stripe_connect_failed"
      );
      setStripeBusy(false);
    }
  }

  async function openStripeDashboard() {
    if (!user || stripeBusy) return;
    setStripeBusy(true);
    setError("");
    const safety = window.setTimeout(() => setStripeBusy(false), 10000);
    try {
      const token = await getAuthToken(user, false);
      const result = await affiliateApi("affiliateStripeConnectDashboard", { token, timeoutMs: 8000 });
      if (result?.url) {
        window.open(result.url, "_blank", "noopener,noreferrer");
      }
    } catch (err) {
      if (err.status === 404) {
        window.clearTimeout(safety);
        setStripeBusy(false);
        void startStripeConnect();
        return;
      }
      setError(
        err.message === "TIMEOUT"
          ? appCopy("Stripe met trop de temps. Réessaie.", "Stripe is taking too long. Try again.")
          : err.message || "stripe_dashboard_failed"
      );
    } finally {
      window.clearTimeout(safety);
      setStripeBusy(false);
    }
  }

  async function handleApply(form) {
    setBusy(true);
    setError("");

    if (dashboard?.affiliateId) {
      if (user) markOnboardingUnlocked(user.uid);
      setBusy(false);
      go("overview");
      return true;
    }

    const suggestedCode = parseAcquisitionCodeFromInput(
      `${codeFromFirstName(form.displayName)}${10 + Math.floor(Math.random() * 90)}`
    );

    try {
      let currentUser = user;
      if (!currentUser) {
        currentUser = await Promise.race([
          ensureAnonymousAffiliateUser(),
          new Promise((_, reject) =>
            window.setTimeout(() => reject(new Error("AUTH_TIMEOUT")), 8000)
          ),
        ]);
        setUser(currentUser);
      }

      const token = await getAuthToken(currentUser, false);
      let applyResult = null;
      let lastError = null;
      for (let attempt = 0; attempt < 4; attempt += 1) {
        const code =
          attempt === 0
            ? suggestedCode
            : parseAcquisitionCodeFromInput(
                `${codeFromFirstName(form.displayName)}${10 + Math.floor(Math.random() * 90)}`
              );
        try {
          applyResult = await Promise.race([
            affiliateApi("affiliateApply", {
              token,
              body: {
                displayName: form.displayName,
                code,
                email: form.email || currentUser.email || undefined,
                phone: form.phone || undefined,
                onboarding: form.onboarding || undefined,
              },
            }),
            new Promise((_, reject) =>
              window.setTimeout(() => reject(new Error("APPLY_TIMEOUT")), 12000)
            ),
          ]);
          lastError = null;
          break;
        } catch (err) {
          lastError = err;
          const message = err?.data?.error || err?.message || "";
          if (message !== "CODE_CONFLICT") throw err;
        }
      }
      if (!applyResult?.affiliateId) {
        throw lastError || new Error("APPLY_TIMEOUT");
      }

      const optimistic = buildOptimisticDashboard({
        affiliateId: applyResult.affiliateId,
        displayName: form.displayName,
        code: applyResult.primaryCode || applyResult.code || suggestedCode,
        status: applyResult.status,
        codes: applyResult.codes,
      });
      setDashboard(optimistic);
      setDashboardLookup("ready");
      writeDashboardCache(currentUser.uid, optimistic);
      markOnboardingUnlocked(currentUser.uid);
      playSettingsChange();
      void loadDashboard(currentUser, { silent: true, force: true });
      go("overview");

      const recoveryEmail = String(form.email || currentUser.email || "").trim();
      if (recoveryEmail && currentUser.isAnonymous) {
        void sendAffiliateEmailLink(recoveryEmail, { nextHash: "overview", applyAfter: false })
          .then(() => {
            setSuccess(
              appCopy(
                "Lien créé. Vérifie tes emails pour retrouver ce compte.",
                "Link created. Check your email to sign back in later."
              )
            );
          })
          .catch(() => {
            setSuccess(appCopy("Lien clipper créé.", "Clipper link created."));
          });
      } else {
        setSuccess(appCopy("Lien clipper créé.", "Clipper link created."));
      }

      return true;
    } catch (err) {
      if (String(err?.code || "").startsWith("auth/")) {
        setError(formatAuthError(err));
      } else {
        setError(formatApplyError(err));
      }
      return false;
    } finally {
      setBusy(false);
    }
  }

  useEffect(() => {
    if (!user || bootstrapping) return;
    if (dashboardLookup !== "ready" && dashboardLookup !== "missing") return;
    if (!peekApplyAfterLink()) return;
    consumeApplyAfterLink();
    if (dashboard) {
      markOnboardingUnlocked(user.uid);
      go("overview");
      return;
    }
    const draft = readOnboardingDraft();
    const name = String(draft.answers?.firstName || "").trim();
    const phone = String(draft.answers?.phone || "").trim();
    if (!name || !phone) {
      go("apply");
      return;
    }
    void handleApply({
      displayName: name,
      email: user.email,
      phone,
      onboarding: { firstName: name, phone },
    });
  }, [user, bootstrapping, dashboard, dashboardLookup, go]);

  function switchApplyToLogin() {
    setApplyAuthMode("login");
    setError("");
    setAuthNotice("");
    setAuthNoticeTone("info");
  }

  async function handleApplyLogin({ email: loginEmail }) {
    setAuthBusy(true);
    setError("");
    setAuthNotice("");

    try {
      if (emailLinkConfirm && hrefLooksLikeEmailLink()) {
        const linkResult = await completeAffiliateEmailLink(loginEmail);
        if (linkResult?.needsEmail) {
          throw new Error(
            appCopy(
              "Confirme le même email que celui utilisé pour recevoir le lien.",
              "Confirm the same email you used to receive the link."
            )
          );
        }
        if (!linkResult?.user) {
          throw new Error("email_link_failed");
        }
        setEmailLinkConfirm(false);
        setEmail(loginEmail.trim());
        setAuthNotice(
          appCopy("Connecté — chargement du portail…", "Signed in — loading your portal…")
        );
        setAuthNoticeTone("success");
        if (linkResult.next) go(linkResult.next);
        return;
      }

      await sendAffiliateEmailLink(loginEmail, {
        nextHash: "overview",
        applyAfter: true,
        requireExistingAccount: true,
      });
      setEmail(loginEmail.trim());
      setAuthNotice(
        appCopy(
          `Lien envoyé — ouvre ton email pour te connecter, sans mot de passe. Rien reçu sous 2 minutes ? Regarde tes spams, puis écris à leks (${SUPPORT_WHATSAPP_DISPLAY}).`,
          `Link sent — open your email to sign in, no password. Nothing after 2 minutes? Check spam, then message leks (${SUPPORT_WHATSAPP_DISPLAY}).`
        )
      );
      setAuthNoticeTone("success");
    } catch (err) {
      setError(formatAuthError(err) || err?.message || "email_link_failed");
    } finally {
      setAuthBusy(false);
    }
  }

  function switchApplyToSignup() {
    setApplyAuthMode("signup");
    setError("");
    setAuthNotice("");
    setAuthNoticeTone("info");
  }

  function resetApplyAuth() {
    setApplyAuthMode("signup");
    setEmailLinkConfirm(false);
    setAuthNotice("");
    setAuthNoticeTone("info");
    setError("");
    setEmail("");
  }

  async function signOut() {
    if (isAffiliateLocalPreview()) return;
    const auth = await getFirebaseAuth();
    const { signOut: firebaseSignOut } = await import("firebase/auth");
    await firebaseSignOut(auth);
    forgetAffiliateSession(user?.uid);
    sessionRef.current = null;
    setDashboard(null);
    setDashboardLookup("missing");
    dashboardUserRef.current = null;
    setApplyAuthMode("signup");
    setAuthNotice("");
    go("program");
  }

  const saveInviteProfile = useCallback(
    async ({ displayName, code }) => {
      if (!user) throw new Error("UNAUTHORIZED");
      if (isAffiliateLocalPreview()) {
        const nextCode = String(code || "").trim().toUpperCase() || "AMINE";
        const nextName = String(displayName || "").trim() || "Amine";
        setDashboard((prev) => ({
          ...(prev || LOCAL_PREVIEW_DASHBOARD),
          displayName: nextName,
          primaryCode: nextCode,
          codes: [{ code: nextCode, displayName: nextName, status: "active" }],
        }));
        return { displayName: nextName, primaryCode: nextCode, codes: [nextCode] };
      }
      const token = await getAuthToken(user);
      const data = await affiliateApi("affiliateSyncProfile", {
        token,
        body: { displayName, code },
        timeoutMs: 12000,
      });
      setDashboard((prev) => {
        if (!prev) return prev;
        const next = {
          ...prev,
          displayName: data.displayName || displayName || prev.displayName,
          primaryCode: data.primaryCode || code || prev.primaryCode,
          codes: Array.isArray(data.codes) && data.codes.length ? data.codes : prev.codes,
        };
        writeDashboardCache(user.uid, next);
        return next;
      });
      void loadDashboard(user, { silent: true, force: true });
      return data;
    },
    [user, loadDashboard]
  );

  const primaryCode = useMemo(
    () => dashboard?.primaryCode || dashboard?.codes?.[0]?.code || "",
    [dashboard]
  );
  const linkUrl = useMemo(
    () => (primaryCode ? buildCreatorLandingUrl(primaryCode) : ""),
    [primaryCode]
  );
  const isPending = dashboard?.status === "pending";
  const wantsApply =
    route === "apply" || (!user && hasAffiliatePrefill(applyPrefill));

  const hasAccount = Boolean(user && dashboard);
  const showOnboarding = wantsApply && !hasAccount;

  const applyFlow = (
    <AffiliateOnboarding
      user={user}
      busy={busy}
      authBusy={authBusy}
      error={error}
      authMode={applyAuthMode}
      authNotice={authNotice}
      authNoticeTone={authNoticeTone}
      emailLinkConfirm={emailLinkConfirm}
      onUseAnotherEmail={resetApplyAuth}
      onSwitchToLogin={switchApplyToLogin}
      onSwitchToSignup={switchApplyToSignup}
      onLogin={handleApplyLogin}
      onLeave={() => go("program")}
      onSubmit={handleApply}
      email={email}
      setEmail={setEmail}
      prefill={applyPrefill}
      onFinished={() => {
        if (user) markOnboardingUnlocked(user.uid);
        go("overview");
      }}
    />
  );

  const landing = (
    <AffiliatePageChrome>
      <Suspense
        fallback={
          <div className="af-app af-loading">
            <div className="af-spinner" />
          </div>
        }
      >
        <ProgramLanding
          onApply={() => go("apply")}
          onLogin={() => {
            switchApplyToLogin();
            go("apply");
          }}
        />
      </Suspense>
      {error ? <div className="af-toast error">{error}</div> : null}
    </AffiliatePageChrome>
  );

  const workspace = (
    <AffiliatePageChrome>
      {dashboard ? (
        <DashboardShell
          route={AFFILIATE_DASHBOARD_ROUTES.has(route) ? route : "overview"}
          go={go}
          query={query}
          user={user}
          dashboard={dashboard}
          isPending={isPending}
          primaryCode={primaryCode}
          linkUrl={linkUrl}
          onConnectStripe={startStripeConnect}
          onManageStripe={openStripeDashboard}
          stripeBusy={stripeBusy}
          onSignOut={signOut}
          onSaveInvite={saveInviteProfile}
        />
      ) : (
        <DashboardSkeleton route={AFFILIATE_DASHBOARD_ROUTES.has(route) ? route : "overview"} />
      )}
      {error ? <div className="af-toast error">{error}</div> : null}
      {success ? <div className="af-toast success">{success}</div> : null}
    </AffiliatePageChrome>
  );

  if (!user && !wantsApply) {
    if (dashboard || (bootstrapping && sessionRef.current?.uid)) {
      return workspace;
    }
    return landing;
  }

  if (!isFirebaseConfigured() && wantsApply) {
    return (
      <AffiliatePageChrome>
        <div className="af-app af-ob af-ld-apply">
          <div className="af-flow">
            <h1>{appCopy("Portail clipper", "Clipper portal")}</h1>
            <p className="af-flow-lead">
              {appCopy(
                "Configure VITE_FIREBASE_API_KEY et VITE_FIREBASE_APP_ID.",
                "Set VITE_FIREBASE_API_KEY and VITE_FIREBASE_APP_ID."
              )}
            </p>
          </div>
        </div>
      </AffiliatePageChrome>
    );
  }

  const waitingDashboard = Boolean(
    user && !dashboard && (bootstrapping || dashboardLookup === "pending")
  );

  if ((bootstrapping && wantsApply) || waitingDashboard) {
    return (
      <AffiliatePageChrome>
        <div className="af-app af-loading">
          <div className="af-spinner" />
          <span>{appCopy("Chargement…", "Loading…")}</span>
        </div>
      </AffiliatePageChrome>
    );
  }

  if (showOnboarding) {
    return (
      <AffiliatePageChrome>
        {applyFlow}
        {success ? <div className="af-toast success">{success}</div> : null}
      </AffiliatePageChrome>
    );
  }

  if (!user || !dashboard) {
    if (bootstrapping && sessionRef.current?.uid) {
      return workspace;
    }
    return landing;
  }

  return workspace;
}
