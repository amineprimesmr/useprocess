import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { appCopy, subscribeSiteLanguage, applySiteDocumentLanguage } from "../features/app-copy.js";
import { dismissCrispChat } from "../features/crisp-chat.js";
import { playSettingsChange } from "../features/process-sound.js";
import { getIosAppStoreUrl } from "../features/app-store-urls.js";
import { getStoreButtonHref } from "../features/in-app-browser-escape.js";
import {
  affiliateApi,
  getFirebaseAuth,
  getAuthToken,
  getFirebaseAuthModule,
  isFirebaseConfigured,
  warmFirebaseAuth,
} from "../features/firebase-client.js";
import {
  buildCreatorLandingUrl,
  normalizeAcquisitionCode,
  parseAcquisitionCodeFromInput,
} from "../features/acquisition-link.js";
import {
  IconCalendar,
  IconCheck,
  IconChevronDown,
  IconChevronLeft,
  IconCoin,
  IconCopy,
  IconCursor,
  IconDoc,
  IconDollar,
  IconExternal,
  IconFilter,
  IconInfo,
  IconLink,
  IconLock,
  IconLogout,
  IconMail,
  IconOverview,
  IconSettings,
  IconShield,
  IconUsers,
  IconWallet,
  IconX,
  ProcessAppIcon,
} from "./AffiliateIcons.jsx";
import {
  AFFILIATE_X_DM_URL,
  buildSupportBody,
  buildSocialMailBody,
  checkAffiliateCodeAvailability,
  isValidEmail,
  validateEmailFormat,
  COMMISSION_PERCENT,
  existingAccountOAuthHint,
  existingAccountPrompt,
  passwordResetErrorMessage,
  passwordResetSentMessage,
  formatApplyError,
  formatAuthError,
  formatShortDate,
  HOLD_DAYS,
  money,
  navigateHash,
  readHashRoute,
  readHashQuery,
  readAffiliatePrefillFromLocation,
  hasAffiliatePrefill,
  consumeAffiliatePrefill,
  socialMailSubject,
  supportMailto,
  validateAffiliateCodeFormat,
  SUPPORT_EMAIL,
} from "./affiliate-utils.js";
import {
  buildOptimisticDashboard,
  clearDashboardCache,
  readDashboardCache,
  writeDashboardCache,
} from "./affiliate-dashboard-cache.js";
import { AffiliateLanding, AffiliateTopNav } from "./AffiliateLanding.jsx";
import { ViewBonusBoard, ViewBonusNote } from "./ViewBonusBoard.jsx";
import "./affiliate.css";

const PRIVACY_URL = "https://useprocess.xyz/privacy";
const LANDING_HASHES = new Set(["", "program", "programme", "comment", "primes", "offre", "faq"]);

function AffiliateXSupportFab() {
  const label = appCopy("Contacter leks sur X", "Message leks on X");
  return (
    <a
      href={AFFILIATE_X_DM_URL}
      className="af-x-fab"
      target="_blank"
      rel="noopener noreferrer"
      aria-label={label}
      title={label}
    >
      <IconX className="af-x-fab-icon" />
    </a>
  );
}

function AffiliatePageChrome({ children }) {
  return (
    <>
      {children}
      <AffiliateXSupportFab />
    </>
  );
}

const TERMS_URL = "https://useprocess.xyz/terms";

let consumedApplyPrefillCache;

function getConsumedApplyPrefill() {
  if (consumedApplyPrefillCache === undefined) {
    consumedApplyPrefillCache = consumeAffiliatePrefill();
  }
  return consumedApplyPrefillCache;
}

function useHashRoute() {
  const [route, setRoute] = useState(() => {
    const prefill = getConsumedApplyPrefill();
    const hashRoute = readHashRoute();
    if (hashRoute === "apply" || hasAffiliatePrefill(prefill)) return "apply";
    if (hashRoute && hashRoute !== "program") return hashRoute;
    return "program";
  });

  useEffect(() => {
    const onHash = () => setRoute(readHashRoute());
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  const go = useCallback((next) => {
    const normalized =
      String(next || "")
        .replace(/^#\/?/, "")
        .split("?")[0]
        .trim() || "program";
    setRoute(normalized);
    navigateHash(normalized);
  }, []);

  return [route, go];
}

function DashboardSkeleton({ route, pageTitles }) {
  return (
    <div className="af-app af-shell">
      <aside className="af-sidebar" aria-hidden="true">
        <div className="af-sidebar-logo">process</div>
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

function MiniChart({ color = "#ec4899", className = "", active = false }) {
  const id = useMemo(() => `grad-${Math.random().toString(36).slice(2, 8)}`, []);
  const linePath = active
    ? "M0,95 L60,88 L120,72 L180,78 L240,55 L320,48 L400,42"
    : "M0,90 L80,90 L160,90 L240,90 L320,90 L400,90";
  const areaPath = active
    ? `${linePath} L400,120 L0,120 Z`
    : "M0,90 L400,90 L400,120 L0,120 Z";
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

function RewardsBox() {
  return (
    <div className="af-rewards-box">
      <h3>{appCopy("Récompenses", "Rewards")}</h3>
      <div className="af-reward-line">
        <IconDollar />
        <span>
          {appCopy(
            `Gagne ${COMMISSION_PERCENT} % par vente, à vie pour chaque client parrainé`,
            `Earn ${COMMISSION_PERCENT}% per sale for the customer's lifetime`
          )}
        </span>
      </div>
      <ViewBonusBoard variant="light" compact />
      <ViewBonusNote />
    </div>
  );
}

function PoweredFooter() {
  return (
    <div className="af-powered">
      <span>{appCopy("Propulsé par", "Powered by")} <strong>Process</strong></span>
      <div className="af-powered-links">
        <a href={TERMS_URL}>{appCopy("Conditions d'utilisation", "Terms of Service")}</a>
        <span>·</span>
        <a href={PRIVACY_URL}>{appCopy("Politique de confidentialité", "Privacy Policy")}</a>
      </div>
    </div>
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

function ReferralCodeField({ value, onChange, error, checking, shake, onBlurValidate, requiredDone }) {
  const normalized = parseAcquisitionCodeFromInput(value);
  const appStoreHref = getStoreButtonHref(getIosAppStoreUrl());

  return (
    <div className={`af-field af-code-field ${shake ? "is-shaking" : ""} ${error ? "is-invalid" : ""}`}>
      <div className="af-label-row">
        <label htmlFor="af-code">{appCopy("Code de parrainage", "Referral code")}</label>
        <RequiredBadge done={requiredDone} />
      </div>
      <input
        id="af-code"
        className={`af-input ${error ? "is-error" : ""}`}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        onPaste={(e) => {
          const pasted = e.clipboardData?.getData("text") || "";
          if (!pasted.trim()) return;
          e.preventDefault();
          onChange(pasted);
        }}
        onBlur={onBlurValidate}
        placeholder={appCopy("Ex. MANNY", "e.g. MANNY")}
        required
        maxLength={24}
        autoComplete="off"
        spellCheck={false}
        aria-invalid={Boolean(error)}
        aria-describedby="af-code-hint af-code-help"
      />
      {checking ? (
        <p className="af-field-hint af-code-checking">{appCopy("Vérification…", "Checking…")}</p>
      ) : error ? (
        <p className="af-field-error" role="alert">
          {error}
        </p>
      ) : normalized ? (
        <p id="af-code-hint" className="af-field-hint">
          {`useprocess.xyz/join/${normalized}`}
        </p>
      ) : null}
      <p id="af-code-help" className="af-field-help">
        {appCopy("Pas de code ?", "No code?")}{" "}
        <a href={appStoreHref} target="_blank" rel="noopener noreferrer">
          {appCopy("Télécharge Process", "Download Process")}
        </a>
        {appCopy(" → Réglages → Programme créateurs.", " → Settings → Creator Program.")}
      </p>
    </div>
  );
}

function ApplyLoginPanel({
  email,
  setEmail,
  password,
  setPassword,
  authBusy,
  busy,
  error,
  authNotice,
  authNoticeTone,
  onLogin,
  onForgotPassword,
  onSwitchToSignup,
  onUseAnotherEmail,
}) {
  const [emailError, setEmailError] = useState("");
  const [shakeEmail, setShakeEmail] = useState(false);
  const emailValue = email.trim();
  const emailOk = isValidEmail(emailValue);
  const canSubmit = emailOk && password.length >= 6 && !authBusy && !busy;

  function validateEmailField({ strict = false } = {}) {
    const result = validateEmailFormat(email);
    if (!result.ok) {
      setEmailError(result.error);
      if (strict) {
        setShakeEmail(true);
        window.setTimeout(() => setShakeEmail(false), 520);
      }
      return false;
    }
    setEmailError("");
    return true;
  }

  return (
    <div className="af-login-panel">
      <h2 className="af-login-title">{appCopy("Connexion", "Log in")}</h2>
      <p className="af-login-lead">
        {appCopy(
          "Connecte-toi avec ton compte Process pour envoyer ou reprendre ta candidature créateur.",
          "Sign in with your Process account to submit or continue your creator application."
        )}
      </p>

      <form
        className="af-login-form"
        onSubmit={(e) => {
          e.preventDefault();
          if (!validateEmailField({ strict: true })) return;
          if (!canSubmit) return;
          onLogin?.({ email: emailValue, password });
        }}
      >
        <div className={`af-field ${shakeEmail ? "is-shaking" : ""} ${emailError ? "is-invalid" : ""}`}>
          <div className="af-label-row">
            <label htmlFor="af-login-email">Email</label>
            <RequiredBadge done={emailOk} />
          </div>
          <input
            id="af-login-email"
            className={`af-input ${emailError ? "is-error" : ""}`}
            type="email"
            value={email}
            onChange={(e) => {
              setEmail(e.target.value);
              if (emailError) setEmailError("");
            }}
            onBlur={() => validateEmailField({ strict: Boolean(email.trim()) })}
            required
            autoComplete="email"
            aria-invalid={Boolean(emailError)}
          />
          {emailError ? (
            <p className="af-field-error" role="alert">
              {emailError}
            </p>
          ) : null}
        </div>

        <div className="af-field">
          <div className="af-label-row">
            <label htmlFor="af-login-password">{appCopy("Mot de passe", "Password")}</label>
            <RequiredBadge done={password.length >= 6} />
          </div>
          <input
            id="af-login-password"
            className="af-input"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={6}
            autoComplete="current-password"
          />
          <p className="af-field-help af-field-help-row">
            <button
              type="button"
              className="af-inline-link"
              disabled={authBusy || !emailOk}
              onClick={() => onForgotPassword?.(emailValue)}
            >
              {authBusy
                ? appCopy("Envoi…", "Sending…")
                : appCopy("Mot de passe oublié ?", "Forgot password?")}
            </button>
          </p>
        </div>

        {authNotice ? (
          <div
            className={`af-form-info ${authNoticeTone === "success" ? "is-success" : ""}`}
            role="status"
          >
            <p>{authNotice}</p>
            {authNoticeTone !== "success" ? (
              <button type="button" className="af-btn af-btn-sm af-btn-black" onClick={() => onUseAnotherEmail?.()}>
                {appCopy("Utiliser un autre email", "Use another email")}
              </button>
            ) : null}
          </div>
        ) : null}

        {error ? <p className="af-form-error">{error}</p> : null}

        <div className="af-form-actions">
          <button type="submit" className="af-btn af-btn-primary" disabled={!canSubmit}>
            {authBusy ? appCopy("Connexion…", "Logging in…") : appCopy("Se connecter", "Log in")}
          </button>
          <button type="button" className="af-text-link-below" disabled={authBusy || busy} onClick={() => onSwitchToSignup?.()}>
            {appCopy("Créer un compte", "Create account")}
          </button>
        </div>
      </form>
    </div>
  );
}

function ApplyFlow({
  user,
  busy,
  authBusy,
  error,
  authMode,
  authNotice,
  authNoticeTone,
  onUseAnotherEmail,
  onForgotPassword,
  onSwitchToLogin,
  onSwitchToSignup,
  onLogin,
  onGoLogin,
  onSubmit,
  email,
  setEmail,
  password,
  setPassword,
  applyStep,
  serverCodeError,
  onClearServerCodeError,
  prefill,
}) {
  const [name, setName] = useState(() => prefill?.name || user?.displayName || "");
  const [terms, setTerms] = useState(false);
  const [code, setCode] = useState(() => prefill?.code || "");
  const [codeError, setCodeError] = useState("");
  const [codeChecking, setCodeChecking] = useState(false);
  const [codeOk, setCodeOk] = useState(false);
  const [shakeCode, setShakeCode] = useState(false);
  const [emailError, setEmailError] = useState("");
  const [shakeEmail, setShakeEmail] = useState(false);
  const debounceRef = useRef(null);
  const prefillValidatedRef = useRef(false);

  const emailValue = (user?.email || email).trim();
  const emailOk = isValidEmail(emailValue);

  useEffect(() => {
    if (user?.email) setEmail(user.email);
    if (user?.displayName && !name.trim()) setName(user.displayName);
    else if (prefill?.name && !name.trim()) setName(prefill.name);
  }, [user, setEmail, name, prefill?.name]);

  useEffect(() => {
    if (prefill?.email && !user?.email) {
      setEmail(prefill.email);
    }
  }, [prefill?.email, user?.email, setEmail]);

  useEffect(() => {
    if (prefillValidatedRef.current) return;
    const initialCode = (prefill?.code || code).trim();
    if (!initialCode) return;
    prefillValidatedRef.current = true;
    validateCodeLive(initialCode);
  }, [prefill?.code, code]);

  function triggerCodeShake() {
    setShakeCode(true);
    window.setTimeout(() => setShakeCode(false), 520);
  }

  function triggerEmailShake() {
    setShakeEmail(true);
    window.setTimeout(() => setShakeEmail(false), 520);
  }

  function validateEmailField({ strict = false } = {}) {
    if (user?.email) {
      setEmailError("");
      return true;
    }

    const result = validateEmailFormat(email);
    if (!result.ok) {
      setEmailError(result.error);
      if (strict) triggerEmailShake();
      return false;
    }

    setEmailError("");
    return true;
  }

  async function validateCodeLive(raw, { strict = false } = {}) {
    const trimmed = String(raw || "").trim();
    onClearServerCodeError?.();

    if (!trimmed) {
      setCodeError("");
      setCodeOk(false);
      return false;
    }

    const format = validateAffiliateCodeFormat(trimmed);
    if (!format.ok) {
      setCodeError(format.error);
      setCodeOk(false);
      if (strict) triggerCodeShake();
      return false;
    }

    setCodeChecking(true);
    try {
      const result = await checkAffiliateCodeAvailability(trimmed, { uid: user?.uid });
      setCodeError(result.ok ? "" : result.error);
      setCodeOk(result.ok);
      if (!result.ok && strict) triggerCodeShake();
      return result.ok;
    } finally {
      setCodeChecking(false);
    }
  }

  useEffect(() => {
    if (serverCodeError) {
      setCodeError(serverCodeError);
      setCodeOk(false);
      triggerCodeShake();
    }
  }, [serverCodeError]);

  useEffect(() => {
    if (debounceRef.current) window.clearTimeout(debounceRef.current);
    if (!code.trim()) {
      setCodeError("");
      setCodeOk(false);
      setCodeChecking(false);
      return undefined;
    }

    debounceRef.current = window.setTimeout(() => {
      validateCodeLive(code);
    }, 450);

    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
    };
  }, [code, user?.uid]);

  function handleCodeChange(next) {
    onClearServerCodeError?.();
    setCode(parseAcquisitionCodeFromInput(next));
  }

  const formReady =
    terms &&
    name.trim() &&
    emailOk &&
    code.trim() &&
    codeOk &&
    !codeError &&
    !codeChecking &&
    (user || password.length >= 6);

  if (applyStep === 2) {
  return (
    <div className="af-app af-grid-bg af-ld-apply">
      <AffiliateTopNav compact onApply={() => {}} onLogin={onGoLogin || onSwitchToLogin} />
      <div className="af-flow">
        <div className="af-flow-top">
          <ProcessAppIcon size={36} />
          <span className="af-step-pill">{appCopy("Étape 2 sur 2", "Step 2 of 2")}</span>
            <h1>{appCopy("Candidature envoyée", "Application submitted")}</h1>
            <p className="af-flow-lead">
              {appCopy(
                "Envoie ton @ TikTok ou Instagram pour accélérer la validation de ton compte créateur.",
                "Send your TikTok or Instagram @ to speed up your creator account approval."
              )}
            </p>
          </div>
          <RewardsBox />
          <SocialChannelForm displayName={name} />
          <button
            type="button"
            className="af-btn af-btn-primary"
            style={{ marginTop: 16 }}
            onClick={() => navigateHash("overview")}
          >
            {appCopy("Voir mon espace", "Go to dashboard")}
          </button>
          <PoweredFooter />
        </div>
      </div>
    );
  }

  return (
    <div className="af-app af-grid-bg af-ld-apply">
      <AffiliateTopNav compact onApply={() => {}} onLogin={onGoLogin || onSwitchToLogin} />
      <div className="af-flow">
        <div className="af-flow-top">
          <ProcessAppIcon size={36} />
          <span className="af-step-pill">{appCopy("Étape 1 sur 2", "Step 1 of 2")}</span>
          <h1>{appCopy("Postuler à Process", "Apply to Process")}</h1>
          <p className="af-flow-lead">
            {appCopy(
              "Envoie ta candidature pour rejoindre le programme créateur Process et commence à gagner des commissions sur tes parrainages.",
              "Submit your application to join the Process creator program and start earning commissions for your referrals."
            )}
          </p>
        </div>

        <RewardsBox />

        {!user && authMode === "login" ? (
          <ApplyLoginPanel
            email={email}
            setEmail={setEmail}
            password={password}
            setPassword={setPassword}
            authBusy={authBusy}
            busy={busy}
            error={error}
            authNotice={authNotice}
            authNoticeTone={authNoticeTone}
            onLogin={onLogin}
            onForgotPassword={onForgotPassword}
            onSwitchToSignup={onSwitchToSignup}
            onUseAnotherEmail={onUseAnotherEmail}
          />
        ) : (
        <form
          onSubmit={async (e) => {
            e.preventDefault();
            const emailValid = validateEmailField({ strict: true });
            if (!emailValid) return;
            const valid = await validateCodeLive(code, { strict: true });
            if (!valid) return;
            onSubmit({
              displayName: name.trim(),
              code: code.trim(),
              email: emailValue,
              password,
            });
          }}
        >
          <div className="af-field">
            <div className="af-label-row">
              <label htmlFor="af-first-name">{appCopy("Prénom", "First name")}</label>
              <RequiredBadge done={name.trim().length > 0} />
            </div>
            <input
              id="af-first-name"
              className="af-input"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder={appCopy("Ex. Amine", "e.g. Amine")}
              autoComplete="given-name"
              required
            />
          </div>

          <div className={`af-field ${shakeEmail ? "is-shaking" : ""} ${emailError ? "is-invalid" : ""}`}>
            <div className="af-label-row">
              <label htmlFor="af-email">Email</label>
              <RequiredBadge done={emailOk} />
            </div>
            <input
              id="af-email"
              className={`af-input ${emailError ? "is-error" : ""}`}
              type="email"
              value={user?.email || email}
              onChange={(e) => {
                setEmail(e.target.value);
                if (emailError) setEmailError("");
              }}
              onBlur={() => validateEmailField({ strict: Boolean(email.trim()) })}
              readOnly={Boolean(user?.email)}
              required
              autoComplete="email"
              aria-invalid={Boolean(emailError)}
            />
            {emailError ? (
              <p className="af-field-error" role="alert">
                {emailError}
              </p>
            ) : null}
          </div>

          <ReferralCodeField
            value={code}
            onChange={handleCodeChange}
            error={codeError}
            checking={codeChecking}
            shake={shakeCode}
            onBlurValidate={() => validateCodeLive(code, { strict: true })}
            requiredDone={codeOk}
          />

          {!user ? (
            <div className="af-field">
              <div className="af-label-row">
                <label htmlFor="af-auth-password">{appCopy("Mot de passe", "Password")}</label>
                <RequiredBadge done={password.length >= 6} />
              </div>
              <input
                id="af-auth-password"
                className="af-input"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                minLength={6}
                autoComplete="new-password"
              />
            </div>
          ) : null}

          {user && authNotice ? (
            <div
              className={`af-form-info ${authNoticeTone === "success" ? "is-success" : ""}`}
              role="status"
            >
              <p>{authNotice}</p>
            </div>
          ) : null}

          <label className="af-checkbox-row">
            <input
              type="checkbox"
              checked={terms}
              onChange={(e) => setTerms(e.target.checked)}
              required
            />
            <span>
              {appCopy("J'accepte les", "I agree to the")}{" "}
              <a href={TERMS_URL} target="_blank" rel="noopener noreferrer">
                {appCopy("Conditions du programme Process", "Process Program Terms")}
              </a>
              <IconExternal style={{ width: 12, height: 12, display: "inline", verticalAlign: "middle" }} />
            </span>
          </label>

          {error ? <p className="af-form-error">{error}</p> : null}

          <div className="af-form-actions">
            <button type="submit" className="af-btn af-btn-primary" disabled={busy || authBusy || !formReady}>
              {busy ? appCopy("Commencer…", "Starting…") : appCopy("Commencer", "Start")}
            </button>

            {!user ? (
              <button
                type="button"
                className="af-text-link-below"
                disabled={busy || authBusy}
                onClick={() => onSwitchToLogin?.()}
              >
                {appCopy("Se connecter", "Log in")}
              </button>
            ) : null}
          </div>
        </form>
        )}

        <PoweredFooter />
      </div>
    </div>
  );
}

function CopyButton({ text }) {
  const [copied, setCopied] = useState(false);

  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
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

function RewardsLinkCard({ primaryCode, linkUrl, isPending }) {
  return (
    <div className="af-card af-card-pad af-rewards-card">
      <div className="af-card-head">
        <h2>{appCopy("Récompenses", "Rewards")}</h2>
        <span className="af-card-muted">
          {appCopy(`Période de retenue ${HOLD_DAYS} jours`, `${HOLD_DAYS}-day holding period`)}
        </span>
      </div>

      {primaryCode ? (
        <div className="af-link-row">
          <div className="af-link-row-text">
            <ProcessAppIcon size={28} />
            <span>{linkUrl.replace("https://", "")}</span>
            {isPending ? (
              <span className="af-link-pending-pill">
                {appCopy("En attente", "Pending")}
              </span>
            ) : null}
          </div>
          <CopyButton text={linkUrl} />
        </div>
      ) : (
        <div className="af-link-row">
          <div className="af-locked-field">
            <IconLock />
            {appCopy(
              "Choisis ton code lors de la candidature pour obtenir ton lien",
              "Pick your code when applying to get your link"
            )}
          </div>
        </div>
      )}

      <div className="af-commission-row">
        <IconDollar />
        {appCopy(
          `${COMMISSION_PERCENT} % par vente, à vie pour chaque client`,
          `${COMMISSION_PERCENT}% per sale for the customer's lifetime`
        )}
      </div>

      <ViewBonusBoard variant="light" compact />
      <ViewBonusNote />
    </div>
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
            ? appCopy("Connexion…", "Connecting…")
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

function StripeConnectModal({ open, onClose, onConfirm, busy }) {
  const [confirmed, setConfirmed] = useState(false);

  useEffect(() => {
    if (open) setConfirmed(false);
  }, [open]);

  if (!open) return null;

  return (
    <div className="af-modal-overlay" role="presentation" onClick={onClose}>
      <div
        className="af-modal af-stripe-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="af-stripe-modal-title"
        onClick={(e) => e.stopPropagation()}
      >
        <button type="button" className="af-modal-close" onClick={onClose} aria-label={appCopy("Fermer", "Close")}>
          ×
        </button>
        <div className="af-stripe-modal-icon">
          <IconWallet style={{ width: 22, height: 22 }} />
        </div>
        <h2 id="af-stripe-modal-title">{appCopy("Compte bancaire", "Bank account")}</h2>
        <p className="af-stripe-modal-lead">
          {appCopy(
            "Process utilise Stripe pour des virements sécurisés vers ton compte.",
            "Process uses Stripe for secure payouts to your bank account."
          )}
        </p>

        <div className="af-stripe-warning">
          <IconInfo style={{ width: 16, height: 16, flexShrink: 0 }} />
          <p>
            {appCopy(
              "Si ton compte ne respecte pas ces conditions, les virements peuvent être retardés ou refusés.",
              "If your bank account does not meet these requirements, payouts may be delayed or rejected."
            )}
          </p>
        </div>

        <ol className="af-stripe-requirements">
          <li>{appCopy("Compte en devise locale (ex. EUR en France).", "Bank account must be in local currency (e.g. EUR for France).")}</li>
          <li>{appCopy("Compte courant — pas d'épargne ni carte.", "Must be a checking account — not savings or debit card.")}</li>
          <li>{appCopy("Titulaire identique à ton profil créateur.", "Account holder name must match your creator profile.")}</li>
          <li>{appCopy("IBAN / RIB exacts à 100 %.", "Bank details must be 100% accurate.")}</li>
        </ol>

        <label className="af-stripe-confirm">
          <input type="checkbox" checked={confirmed} onChange={(e) => setConfirmed(e.target.checked)} />
          <span>
            {appCopy(
              "Je confirme que mon compte respecte toutes ces conditions.",
              "I confirm that my bank account meets all of the above requirements."
            )}
          </span>
        </label>

        <button
          type="button"
          className="af-btn af-btn-black af-stripe-continue"
          disabled={!confirmed || busy}
          onClick={onConfirm}
        >
          {busy ? appCopy("Redirection…", "Redirecting…") : appCopy("Continuer", "Continue")}
        </button>
        <p className="af-stripe-powered">
          {appCopy("Propulsé par", "Powered by")} <strong>Stripe</strong>
        </p>
      </div>
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
            `Ton compte créateur (${displayName || "Process"}) est en attente. Envoie ton @ TikTok ou Instagram pour activer ton code à ${COMMISSION_PERCENT} %.`,
            `Your creator account (${displayName || "Process"}) is pending. Send your TikTok or Instagram @ to activate your ${COMMISSION_PERCENT}% code.`
          )}
        </p>
        <SocialChannelForm displayName={displayName} compact />
      </div>
    </div>
  );
}

function OverviewPage({ dashboard, isPending, primaryCode, linkUrl, onConnectStripe, onManageStripe, stripeBusy }) {
  const earnings = dashboard?.stats?.lifetimeCents ?? 0;
  const payable = dashboard?.stats?.payableCents ?? 0;
  const paid = dashboard?.stats?.paidCents ?? 0;
  const payouts = dashboard?.payouts ?? [];
  const stripeReady = isStripePayoutReady(dashboard);

  return (
    <>
      {isPending ? (
        <PendingBanner displayName={dashboard?.displayName} />
      ) : null}

      <RewardsLinkCard primaryCode={primaryCode} linkUrl={linkUrl} isPending={isPending} />

      <div className="af-stats-grid">
        <div className="af-card af-stat-card af-stat-card-lg">
          <div className="af-card-head">
            <h3>
              {appCopy("Gains", "Earnings")}
              <IconExternal style={{ width: 12, height: 12, marginLeft: 4, opacity: 0.4 }} />
            </h3>
            <button type="button" className="af-chip-btn">
              <IconCalendar />
              {appCopy("30 derniers jours", "Last 30 days")}
              <IconChevronDown />
            </button>
          </div>
          <div className="af-stat-value">{money(earnings)}</div>
          <MiniChart color="#ec4899" active={earnings > 0} />
          <div className="af-chart-axis">
            <span>{formatShortDate(Date.now() - 30 * 86400000)}</span>
            <span>{formatShortDate(Date.now())}</span>
          </div>
        </div>

        <div className="af-card af-stat-card af-payouts-overview">
          <div className="af-card-head">
            <h3>{appCopy("Paiements", "Payouts")}</h3>
          </div>
          {payouts.length === 0 && payable === 0 && paid === 0 ? (
            <div className="af-empty" style={{ minHeight: 160, padding: "20px 0" }}>
              <IconWallet style={{ width: 32, height: 32, color: "#d1d5db", marginBottom: 8 }} />
              <strong>{appCopy("Aucun paiement", "No payouts")}</strong>
            </div>
          ) : (
            <div className="af-payouts-overview-body">
              <div>
                <span className="af-card-muted">{appCopy("À venir", "Upcoming")}</span>
                <div className="af-stat-value" style={{ fontSize: 22 }}>{money(payable)}</div>
              </div>
              <div>
                <span className="af-card-muted">{appCopy("Reçus", "Received")}</span>
                <div className="af-stat-value" style={{ fontSize: 22 }}>{money(paid)}</div>
              </div>
            </div>
          )}
          {!stripeReady ? (
            <button type="button" className="af-btn af-btn-sm af-btn-black" style={{ width: "100%", marginTop: 12 }} onClick={onConnectStripe} disabled={stripeBusy}>
              {appCopy("Connecter un compte", "Connect payout method")}
            </button>
          ) : (
            <button type="button" className="af-btn af-btn-sm af-btn-secondary" style={{ width: "100%", marginTop: 12 }} onClick={onManageStripe} disabled={stripeBusy}>
              {appCopy("Voir Stripe", "View Stripe dashboard")}
            </button>
          )}
        </div>
      </div>

      <div className="af-stats-bottom">
        {[
          { label: appCopy("Clics", "Clicks"), value: 0, color: "#3b82f6" },
          { label: appCopy("Leads", "Leads"), value: dashboard?.stats?.referredCount ?? 0, color: "#8b5cf6" },
          { label: appCopy("Ventes", "Sales"), value: dashboard?.stats?.activeSubscribers ?? 0, color: "#14b8a6" },
        ].map((item) => (
          <div key={item.label} className="af-card af-stat-card">
            <h3>{item.label}</h3>
            <div className="af-stat-value">{item.value}</div>
            <MiniChart color={item.color} className="af-mini-chart" active={item.value > 0} />
            <div className="af-chart-axis">
              <span>{formatShortDate(Date.now() - 30 * 86400000)}</span>
              <span>{formatShortDate(Date.now())}</span>
            </div>
          </div>
        ))}
      </div>
    </>
  );
}

function LinksPage({ dashboard, isPending, primaryCode, linkUrl }) {
  if (!primaryCode) {
    return (
      <div className="af-card af-empty">
        <div className="af-empty-content">
          <h2>{appCopy("Aucun lien", "No links yet")}</h2>
          <p>
            {appCopy(
              "Ton lien apparaîtra ici dès que tu auras un code créateur.",
              "Your link will show here once you have a creator code."
            )}
          </p>
        </div>
      </div>
    );
  }

  return (
    <>
      {isPending ? (
        <div className="af-form-info" style={{ marginBottom: 16 }}>
          <p>
            {appCopy(
              "Ton lien est réservé — les commissions s'activent dès validation de ton compte.",
              "Your link is reserved — commissions activate once your account is approved."
            )}
          </p>
        </div>
      ) : null}
    <div className="af-card af-link-card">
      <div className="af-link-card-top">
        <div>
          <div className="af-link-card-main">
            <ProcessAppIcon size={28} />
            <div>
              <strong>{linkUrl.replace("https://", "")}</strong>
              <div className="af-link-dest">↳ useprocess.xyz/app</div>
            </div>
          </div>
          <CopyButton text={linkUrl} />
        </div>
      </div>
      <div className="af-metrics-row">
        {[
          { label: appCopy("Clics", "Clicks"), value: 0, color: "#3b82f6", icon: IconCursor },
          { label: appCopy("Leads", "Leads"), value: dashboard?.stats?.referredCount ?? 0, color: "#8b5cf6", icon: IconUsers },
          { label: appCopy("Ventes", "Sales"), value: dashboard?.stats?.activeSubscribers ?? 0, color: "#14b8a6", icon: IconDollar },
        ].map(({ label, value, color, icon: Icon }) => (
          <div key={label} className="af-metric-col">
            <div className="af-metric-head">
              <Icon style={{ color }} />
              {label}
            </div>
            <div className="af-metric-val">{value}</div>
            <MiniChart color={color} className="af-mini-chart" />
            <div className="af-chart-axis">
              <span>{formatShortDate(Date.now() - 30 * 86400000)}</span>
              <span>{formatShortDate(Date.now())}</span>
            </div>
          </div>
        ))}
      </div>
    </div>
    </>
  );
}

function EarningsPage({ dashboard }) {
  const total = dashboard?.stats?.lifetimeCents ?? 0;
  const rows = dashboard?.recentCommissions ?? [];

  return (
    <>
      <div className="af-card af-card-pad af-view-bonus-card">
        <div className="af-card-head">
          <h2>{appCopy("Primes vues", "View bonuses")}</h2>
          <span className="af-card-muted">
            {appCopy(`En plus des ${COMMISSION_PERCENT} % à vie`, `On top of ${COMMISSION_PERCENT}% for life`)}
          </span>
        </div>
        <ViewBonusBoard variant="light" />
        <ViewBonusNote />
      </div>

      <div className="af-toolbar">
        <button type="button" className="af-chip-btn">
          <IconFilter />
          {appCopy("Filtrer", "Filter")}
          <IconChevronDown />
        </button>
        <button type="button" className="af-chip-btn">
          <IconCalendar />
          {appCopy("30 derniers jours", "Last 30 days")}
          <IconChevronDown />
        </button>
      </div>

      <div className="af-card af-card-pad">
        <div className="af-card-head">
          <div>
            <div className="af-card-muted">{appCopy("Gains totaux", "Total Earnings")}</div>
            <div className="af-stat-value">{money(total)}</div>
          </div>
        </div>
        <MiniChart color="#10b981" />
        <div className="af-chart-axis">
          <span>{formatShortDate(Date.now() - 30 * 86400000)}</span>
          <span>{formatShortDate(Date.now())}</span>
        </div>
      </div>

      <div className="af-card" style={{ marginTop: 16 }}>
        {rows.length === 0 ? (
          <div className="af-empty" style={{ minHeight: 200 }}>
            <IconCoin style={{ width: 28, height: 28, color: "#d1d5db" }} />
            <div className="af-empty-content">
              <h2>{appCopy("Aucune commission", "No commissions yet")}</h2>
              <p>
                {appCopy(
                  "Les commissions apparaîtront ici dès qu'un parrainage convertit.",
                  "Commissions will appear here once a referral converts."
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
          <h2>{appCopy("Aucun client", "No customers yet")}</h2>
          <p>
            {appCopy(
              "Aucun client enregistré pour l'instant. Dès que des utilisateurs convertissent via tes liens, ils apparaîtront ici.",
              "No customers have been recorded for this program yet. Once customers start converting through your links, they'll appear here."
            )}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="af-card af-card-pad">
      <p>{appCopy("Clients parrainés", "Referred customers")}: <strong>{count}</strong></p>
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
                ? appCopy("Connexion…", "Connecting…")
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

function SettingsPage({ user, dashboard, onConnectStripe, onManageStripe, stripeBusy, onSignOut }) {
  const [tab, setTab] = useState("general");
  const [displayName, setDisplayName] = useState(dashboard?.displayName || "");
  const initials = (displayName || user?.email || "P").charAt(0).toUpperCase();

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
                        "C'est ton prénom affiché sur Process.",
                        "This is your first name displayed on Process."
                      )}
                    </p>
                    <input
                      className="af-input"
                      value={displayName}
                      onChange={(e) => setDisplayName(e.target.value)}
                      maxLength={32}
                    />
                  </div>
                </div>
              </div>
              <div className="af-setting-footer">
                <span>{appCopy("32 caractères max.", "Max 32 characters.")}</span>
                <button type="button" className="af-btn af-btn-sm af-btn-secondary" disabled>
                  {appCopy("Enregistrer", "Save Changes")}
                </button>
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
                    <input className="af-input" value={user?.email || ""} readOnly />
                  </div>
                </div>
              </div>
              <div className="af-setting-footer">
                <a href={`mailto:${SUPPORT_EMAIL}`} style={{ color: "var(--af-accent)", textDecoration: "none" }}>
                  {appCopy("Préférences email", "Manage email preferences")} →
                </a>
                <button type="button" className="af-btn af-btn-sm af-btn-secondary" disabled>
                  {appCopy("Enregistrer", "Save Changes")}
                </button>
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
                    {appCopy("Connecter", "Connect")}
                  </button>
                )}
              </div>
            </div>

            <div className="af-card af-setting-card">
              <div className="af-card-pad">
                <h3>{appCopy("Ton identifiant", "Your User ID")}</h3>
                <p className="desc">
                  {appCopy(
                    "Identifiant unique de ton compte créateur.",
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
                "Contacte le support Process pour supprimer définitivement ton compte créateur.",
                "Contact Process support to permanently delete your creator account."
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
  user,
  dashboard,
  isPending,
  primaryCode,
  linkUrl,
  onConnectStripe,
  onManageStripe,
  stripeBusy,
  onSignOut,
}) {
  const pageTitles = {
    overview: appCopy("Vue d'ensemble", "Overview"),
    links: appCopy("Liens", "Links"),
    earnings: appCopy("Gains", "Earnings"),
    analytics: appCopy("Analytique", "Analytics"),
    events: appCopy("Événements", "Events"),
    customers: appCopy("Clients", "Customers"),
    bounties: appCopy("Bonus", "Bounties"),
    resources: appCopy("Ressources", "Resources"),
    payouts: appCopy("Paiements", "Payouts"),
    settings: appCopy("Paramètres", "Settings"),
  };

  const navItems = [
    { id: "overview", label: appCopy("Vue d'ensemble", "Overview"), icon: IconOverview },
    { id: "links", label: appCopy("Liens", "Links"), icon: IconLink },
    { id: "earnings", label: appCopy("Gains", "Earnings"), icon: IconCoin },
    { id: "payouts", label: appCopy("Paiements", "Payouts"), icon: IconWallet },
    { id: "settings", label: appCopy("Paramètres", "Settings"), icon: IconSettings },
  ];

  function renderPage() {
    switch (route) {
      case "links":
        return <LinksPage dashboard={dashboard} isPending={isPending} primaryCode={primaryCode} linkUrl={linkUrl} />;
      case "earnings":
        return <EarningsPage dashboard={dashboard} />;
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
          />
        );
      case "analytics":
      case "events":
      case "bounties":
      case "resources":
        return (
          <div className="af-card af-empty">
            <div className="af-empty-content">
              <h2>{pageTitles[route]}</h2>
              <p>{appCopy("Bientôt disponible.", "Coming soon.")}</p>
            </div>
          </div>
        );
      default:
        return (
          <OverviewPage
            dashboard={dashboard}
            isPending={isPending}
            primaryCode={primaryCode}
            linkUrl={linkUrl}
            onConnectStripe={onConnectStripe}
            onManageStripe={onManageStripe}
            stripeBusy={stripeBusy}
          />
        );
    }
  }

  const pageContent = renderPage();

  return (
    <div className="af-app af-shell">
      <aside className="af-sidebar">
        <div className="af-sidebar-logo">process</div>
        <div className="af-sidebar-user">
          <ProcessAppIcon size={24} />
          <div className="af-sidebar-user-text">
            <strong>{dashboard?.displayName || "Process"}</strong>
            <span>{user?.email || ""}</span>
          </div>
        </div>

        <nav className="af-nav" aria-label={appCopy("Navigation", "Navigation")}>
          {navItems.map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              type="button"
              className={`af-nav-item ${route === id ? "is-active" : ""}`}
              onClick={() => go(id)}
            >
              <Icon />
              {label}
            </button>
          ))}
        </nav>

        <PayoutSidebarWidget
          dashboard={dashboard}
          onConnect={onConnectStripe}
          onManage={() => {
            if (isStripePayoutReady(dashboard)) {
              onManageStripe();
            } else {
              go("payouts");
            }
          }}
          busy={stripeBusy}
        />

        <div className="af-sidebar-footer">
          <a className="af-support-link" href={`mailto:${SUPPORT_EMAIL}`}>
            <IconMail />
            {appCopy("Support", "Support")}
          </a>
          <a className="af-support-link" href={TERMS_URL}>
            <IconDoc />
            {appCopy("Conditions", "Terms")}
          </a>
          <button type="button" className="af-support-link af-sidebar-logout" onClick={onSignOut}>
            <IconLogout />
            {appCopy("Se déconnecter", "Log out")}
          </button>
        </div>
      </aside>

      <main className="af-main">
        {route !== "payouts" && route !== "settings" ? (
          <div className="af-page-head">
            <h1>
              {pageTitles[route] || pageTitles.overview}
              <IconInfo />
            </h1>
          </div>
        ) : null}
        <div className="af-page-panel" key={route}>
          {pageContent}
        </div>
      </main>
    </div>
  );
}

export function AffiliateApp() {
  const [, setLangTick] = useState(0);
  const [route, go] = useHashRoute();
  const [user, setUser] = useState(null);
  const [dashboard, setDashboard] = useState(null);
  const [bootstrapping, setBootstrapping] = useState(true);
  const [busy, setBusy] = useState(false);
  const [stripeBusy, setStripeBusy] = useState(false);
  const [stripeModalOpen, setStripeModalOpen] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [email, setEmail] = useState(() => getConsumedApplyPrefill()?.email || "");
  const [password, setPassword] = useState("");
  const [applyStep, setApplyStep] = useState(1);
  const [applyCodeError, setApplyCodeError] = useState("");
  const [applyAuthMode, setApplyAuthMode] = useState("signup");
  const [authNotice, setAuthNotice] = useState("");
  const [authNoticeTone, setAuthNoticeTone] = useState("info");
  const [authBusy, setAuthBusy] = useState(false);
  const bootstrappedRef = useRef(false);
  const dashboardLoadRef = useRef(null);
  const dashboardUserRef = useRef(null);
  const applyPrefill = getConsumedApplyPrefill();

  useEffect(() => {
    warmFirebaseAuth();
    dismissCrispChat();
    applySiteDocumentLanguage();
    return subscribeSiteLanguage(() => {
      applySiteDocumentLanguage();
      setLangTick((n) => n + 1);
    });
  }, []);

  const loadDashboard = useCallback(async (nextUser, { silent = false, force = false } = {}) => {
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
        const data = await affiliateApi("affiliateDashboard", { token });
        setDashboard(data);
        writeDashboardCache(nextUser.uid, data);
        return data;
      } catch (err) {
        if (err.status === 404) {
          setDashboard(null);
          clearDashboardCache(nextUser.uid);
        } else if (!silent) {
          setError(err.message || "dashboard_error");
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
    (async () => {
      if (!isFirebaseConfigured()) {
        setBootstrapping(false);
        return;
      }
      try {
        const auth = await getFirebaseAuth();
        const { onAuthStateChanged } = await import("firebase/auth");
        onAuthStateChanged(auth, (nextUser) => {
          if (cancelled) return;
          setUser(nextUser);

          if (!nextUser) {
            setDashboard(null);
            dashboardUserRef.current = null;
            bootstrappedRef.current = true;
            setBootstrapping(false);
            return;
          }

          const cached = readDashboardCache(nextUser.uid);
          if (cached) {
            setDashboard(cached);
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
    };
  }, [loadDashboard]);

  useEffect(() => {
    if (bootstrapping) return;
    if (!user && !LANDING_HASHES.has(route) && !["apply", "auth"].includes(route)) {
      go("program");
    }
    if (user && dashboard && LANDING_HASHES.has(route)) {
      go("overview");
    }
  }, [bootstrapping, user, dashboard, route, go]);

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
        await affiliateApi("affiliateStripeConnectSync", { token });
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

  function openStripeConnectModal() {
    setStripeModalOpen(true);
  }

  async function confirmStripeConnect() {
    if (!user) return;
    setStripeBusy(true);
    setError("");
    try {
      const token = await getAuthToken(user, false);
      const result = await affiliateApi("affiliateStripeConnectStart", { token });
      if (result?.url) {
        window.location.href = result.url;
        return;
      }
      throw new Error("STRIPE_NOT_CONFIGURED");
    } catch (err) {
      setError(err.message || "stripe_connect_failed");
      setStripeBusy(false);
      setStripeModalOpen(false);
    }
  }

  async function openStripeDashboard() {
    if (!user) return;
    setStripeBusy(true);
    setError("");
    try {
      const token = await getAuthToken(user, false);
      const result = await affiliateApi("affiliateStripeConnectDashboard", { token });
      if (result?.url) {
        window.open(result.url, "_blank", "noopener,noreferrer");
      }
    } catch (err) {
      if (err.status === 404) {
        openStripeConnectModal();
      } else {
        setError(err.message || "stripe_dashboard_failed");
      }
    } finally {
      setStripeBusy(false);
    }
  }

  async function handleApply(form) {
    setBusy(true);
    setError("");
    setApplyCodeError("");

    const normalizedCode = parseAcquisitionCodeFromInput(form.code);

    try {
      let currentUser = user;
      if (!currentUser) {
        const auth = await getFirebaseAuth();
        const { createUserWithEmailAndPassword, fetchSignInMethodsForEmail } =
          await getFirebaseAuthModule();

        try {
          const credential = await createUserWithEmailAndPassword(auth, form.email, form.password);
          currentUser = credential.user;
        } catch (createErr) {
          if (createErr?.code === "auth/email-already-in-use") {
            let oauthHint = "";
            try {
              const methods = await fetchSignInMethodsForEmail(auth, form.email);
              if (methods.length > 0 && !methods.includes("password")) {
                oauthHint = existingAccountOAuthHint();
              }
            } catch {
              /* ignore */
            }
            setApplyAuthMode("login");
            setAuthNotice(oauthHint || existingAccountPrompt());
            setAuthNoticeTone("info");
            setError("");
            return;
          }
          throw createErr;
        }
        setUser(currentUser);
      }

      const token = await getAuthToken(currentUser, false);
      const applyResult = await affiliateApi("affiliateApply", {
        token,
        body: {
          displayName: form.displayName,
          code: normalizedCode,
          email: form.email || currentUser.email || undefined,
        },
      });

      const optimistic = buildOptimisticDashboard({
        affiliateId: applyResult.affiliateId,
        displayName: form.displayName,
        code: applyResult.code || normalizedCode,
        status: applyResult.status,
        codes: applyResult.codes,
      });
      setDashboard(optimistic);
      writeDashboardCache(currentUser.uid, optimistic);

      setApplyStep(2);
      playSettingsChange();
      setSuccess(appCopy("Candidature envoyée.", "Application submitted."));
      void loadDashboard(currentUser, { silent: true, force: true });
    } catch (err) {
      const message = err?.data?.error || err?.message || "";
      if (message === "CODE_CONFLICT" || message === "INVALID_CODE") {
        setApplyCodeError(formatApplyError(err));
      } else if (String(err?.code || "").startsWith("auth/")) {
        setError(formatAuthError(err));
      } else {
        setError(formatApplyError(err));
      }
    } finally {
      setBusy(false);
    }
  }

  function switchApplyToLogin() {
    setApplyAuthMode("login");
    setError("");
    setAuthNotice("");
    setAuthNoticeTone("info");
    setPassword("");
  }

  async function handleApplyLogin({ email: loginEmail, password: loginPassword }) {
    setAuthBusy(true);
    setError("");
    setAuthNotice("");

    try {
      const auth = await getFirebaseAuth();
      const { signInWithEmailAndPassword } = await getFirebaseAuthModule();
      const credential = await signInWithEmailAndPassword(auth, loginEmail.trim(), loginPassword);
      setUser(credential.user);
      setEmail(credential.user.email || loginEmail.trim());
      setPassword("");
      setApplyAuthMode("signup");
      setAuthNotice(
        appCopy(
          "Connecté — complète ta candidature ci-dessous.",
          "Signed in — complete your application below."
        )
      );
      setAuthNoticeTone("success");
    } catch (err) {
      if (err?.code === "auth/invalid-credential" || err?.code === "auth/wrong-password") {
        setError(
          appCopy(
            "Mot de passe incorrect. Réessaie ou utilise un autre email.",
            "Incorrect password. Try again or use another email."
          )
        );
      } else {
        setError(formatAuthError(err));
      }
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
    setAuthNotice("");
    setAuthNoticeTone("info");
    setError("");
    setPassword("");
    setEmail("");
  }

  async function handleForgotPassword(targetEmail) {
    const normalized = String(targetEmail || "").trim();
    if (!isValidEmail(normalized)) {
      setError(
        appCopy(
          "Entre un email valide pour réinitialiser ton mot de passe.",
          "Enter a valid email to reset your password."
        )
      );
      return;
    }

    setAuthBusy(true);
    setError("");
    try {
      const auth = await getFirebaseAuth();
      const { sendPasswordResetEmail } = await import("firebase/auth");
      await sendPasswordResetEmail(auth, normalized);
      setApplyAuthMode("login");
      setAuthNotice(passwordResetSentMessage(normalized));
      setAuthNoticeTone("success");
    } catch (err) {
      setError(formatAuthError(err) || passwordResetErrorMessage());
    } finally {
      setAuthBusy(false);
    }
  }

  async function signOut() {
    const auth = await getFirebaseAuth();
    const { signOut: firebaseSignOut } = await import("firebase/auth");
    await firebaseSignOut(auth);
    clearDashboardCache(user?.uid);
    setDashboard(null);
    dashboardUserRef.current = null;
    setApplyStep(1);
    setApplyAuthMode("signup");
    setAuthNotice("");
    go("program");
  }

  const primaryCode = useMemo(() => dashboard?.codes?.[0]?.code || "", [dashboard]);
  const linkUrl = useMemo(
    () => (primaryCode ? buildCreatorLandingUrl(primaryCode) : ""),
    [primaryCode]
  );
  const isPending = dashboard?.status === "pending";
  const wantsApply =
    route === "apply" || (!user && hasAffiliatePrefill(applyPrefill));

  const applyFlow = (
    <ApplyFlow
      user={user}
      busy={busy}
      authBusy={authBusy}
      error={error}
      authMode={applyAuthMode}
      authNotice={authNotice}
      authNoticeTone={authNoticeTone}
      onUseAnotherEmail={resetApplyAuth}
      onForgotPassword={handleForgotPassword}
      onSwitchToLogin={switchApplyToLogin}
      onSwitchToSignup={switchApplyToSignup}
      onLogin={handleApplyLogin}
      onGoLogin={switchApplyToLogin}
      onSubmit={handleApply}
      email={email}
      setEmail={setEmail}
      password={password}
      setPassword={setPassword}
      applyStep={applyStep}
      serverCodeError={applyCodeError}
      onClearServerCodeError={() => setApplyCodeError("")}
      prefill={applyPrefill}
    />
  );

  const landing = (
    <AffiliatePageChrome>
      <ProgramLanding
        onApply={() => go("apply")}
        onLogin={() => {
          switchApplyToLogin();
          go("apply");
        }}
      />
      {error ? <div className="af-toast error">{error}</div> : null}
    </AffiliatePageChrome>
  );

  if (!user && !wantsApply) {
    return landing;
  }

  if (!isFirebaseConfigured() && wantsApply) {
    return (
      <AffiliatePageChrome>
        <div className="af-app af-grid-bg af-ld-apply">
          <AffiliateTopNav compact onApply={() => go("apply")} onLogin={() => {}} />
          <div className="af-flow">
            <h1>{appCopy("Portail créateur", "Creator portal")}</h1>
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

  if (bootstrapping && wantsApply) {
    return (
      <AffiliatePageChrome>
        <div className="af-app af-loading">
          <div className="af-spinner" />
          <span>{appCopy("Chargement…", "Loading…")}</span>
        </div>
      </AffiliatePageChrome>
    );
  }

  if (wantsApply) {
    return (
      <AffiliatePageChrome>
        {applyFlow}
        {success ? <div className="af-toast success">{success}</div> : null}
      </AffiliatePageChrome>
    );
  }

  if (!user) {
    return landing;
  }

  if (!dashboard && applyStep !== 2) {
    return (
      <AffiliatePageChrome>
        <DashboardSkeleton
        route={route}
        pageTitles={{
          overview: appCopy("Vue d'ensemble", "Overview"),
          links: appCopy("Liens", "Links"),
          earnings: appCopy("Gains", "Earnings"),
          analytics: appCopy("Analytique", "Analytics"),
          events: appCopy("Événements", "Events"),
          customers: appCopy("Clients", "Customers"),
          bounties: appCopy("Bonus", "Bounties"),
          resources: appCopy("Ressources", "Resources"),
          payouts: appCopy("Paiements", "Payouts"),
          settings: appCopy("Paramètres", "Settings"),
        }}
        />
      </AffiliatePageChrome>
    );
  }

  return (
    <AffiliatePageChrome>
      <DashboardShell
        route={["overview", "links", "earnings", "payouts", "settings"].includes(route) ? route : "overview"}
        go={go}
        user={user}
        dashboard={dashboard}
        isPending={isPending}
        primaryCode={primaryCode}
        linkUrl={linkUrl}
        onConnectStripe={openStripeConnectModal}
        onManageStripe={openStripeDashboard}
        stripeBusy={stripeBusy}
        onSignOut={signOut}
      />
      <StripeConnectModal
        open={stripeModalOpen}
        onClose={() => setStripeModalOpen(false)}
        onConfirm={confirmStripeConnect}
        busy={stripeBusy}
      />
      {error ? <div className="af-toast error">{error}</div> : null}
      {success ? <div className="af-toast success">{success}</div> : null}
    </AffiliatePageChrome>
  );
}
