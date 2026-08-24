import { useEffect, useRef, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { playDashboardOpen } from "../features/process-sound.js";
import { getIosAppStoreUrl } from "../features/app-store-urls.js";
import { getStoreButtonHref } from "../features/in-app-browser-escape.js";
import { parseAcquisitionCodeFromInput } from "../features/acquisition-link.js";
import { IconCheck, IconChevronLeft, ProcessAppIcon } from "./AffiliateIcons.jsx";
import { ViewBonusBoard, ViewBonusNote } from "./ViewBonusBoard.jsx";
import {
  checkAffiliateCodeAvailability,
  COMMISSION_PERCENT,
  isValidEmail,
  money,
  validateAffiliateCodeFormat,
} from "./affiliate-utils.js";
import {
  isQuestionStep,
  nextOnboardingStep,
  prevOnboardingStep,
  questionStepCount,
  questionStepIndex,
  readOnboardingDraft,
  syncOnboardingDraftFromStripeReturn,
  writeOnboardingDraft,
} from "./affiliate-onboarding-state.js";
import "./affiliate-onboarding.css";

const TERMS_URL = "https://useprocess.xyz/terms";

const HOURS = [
  { id: "lt1", fr: "Moins d'1 h", en: "Under 1 hour" },
  { id: "1-2", fr: "1 à 2 h", en: "1–2 hours" },
  { id: "3-4", fr: "3 à 4 h", en: "3–4 hours" },
  { id: "5+", fr: "5 h et plus", en: "5+ hours" },
];

const BUDGETS = [
  { id: "0", fr: "0 €", en: "$0" },
  { id: "lt50", fr: "Moins de 50 € / mois", en: "Under $50 / month" },
  { id: "50-150", fr: "50–150 € / mois", en: "$50–150 / month" },
  { id: "150+", fr: "150 € et plus", en: "$150+" },
];

const EXPERIENCE = [
  { id: "never", fr: "Jamais posté", en: "Never posted" },
  { id: "videos", fr: "Déjà posté des vidéos", en: "Already posted videos" },
  { id: "slideshow", fr: "Déjà posté des slideshows", en: "Already posted slideshows" },
  { id: "ugc", fr: "Déjà posté de l'UGC", en: "Already posted UGC" },
];

const ACCOUNT_MIN = 1;
const ACCOUNT_MAX = 5;
const ACCOUNT_OPTIONS = [1, 2, 3, 4, 5].map((n) => ({
  id: String(n),
  fr: n === 1 ? "1 compte" : `${n} comptes`,
  en: n === 1 ? "1 account" : `${n} accounts`,
}));
const LEGACY_GOALS = { side: 1, replace: 3, agency: 5 };

function parseAccountCount(answers) {
  const fromCount = Number(answers?.accountCount);
  if (Number.isFinite(fromCount) && fromCount >= ACCOUNT_MIN) {
    return Math.min(ACCOUNT_MAX, Math.round(fromCount));
  }
  const fromGoal = Number(answers?.goal);
  if (Number.isFinite(fromGoal) && fromGoal >= ACCOUNT_MIN) {
    return Math.min(ACCOUNT_MAX, Math.round(fromGoal));
  }
  return LEGACY_GOALS[answers?.goal] || 0;
}

function ChoiceList({ options, value, onChange }) {
  return (
    <div className="af-ob-choices" role="listbox">
      {options.map((option) => (
        <button
          key={option.id}
          type="button"
          role="option"
          aria-selected={value === option.id}
          className={`af-ob-choice ${value === option.id ? "is-on" : ""}`}
          onClick={() => onChange(option.id)}
        >
          {appCopy(option.fr, option.en)}
        </button>
      ))}
    </div>
  );
}

function Progress({ step }) {
  if (!isQuestionStep(step)) return null;
  const total = questionStepCount();
  const current = questionStepIndex(step) + 1;
  return (
    <div className="af-ob-progress" aria-hidden>
      <div className="af-ob-progress__track">
        <div className="af-ob-progress__bar" style={{ width: `${(current / total) * 100}%` }} />
      </div>
      <span className="af-ob-progress__label">
        {current}/{total}
      </span>
    </div>
  );
}

function Actions({ onNext, nextLabel, nextDisabled }) {
  return (
    <div className="af-ob-actions">
      <button
        type="submit"
        className="af-ob-btn af-ob-btn--primary"
        disabled={nextDisabled}
        onClick={(event) => {
          if (event.currentTarget.closest("form")) return;
          onNext?.();
        }}
      >
        {nextLabel}
      </button>
    </div>
  );
}

const DEMO_MONTH_CENTS = 38400;
const DEMO_SALES = [
  { productFr: "Process Annuel", productEn: "Process Annual", cents: 1399, mrr: false, whenFr: "Il y a 2 h", whenEn: "2h ago" },
  { productFr: "Process Mensuel", productEn: "Process Monthly", cents: 899, mrr: true, whenFr: "Il y a 5 h", whenEn: "5h ago" },
  { productFr: "Process Mensuel", productEn: "Process Monthly", cents: 899, mrr: true, whenFr: "Hier", whenEn: "Yesterday" },
];

function SimulatedDashboard({ live = false }) {
  const [cents, setCents] = useState(live ? 0 : DEMO_MONTH_CENTS);
  const [ready, setReady] = useState(!live);

  useEffect(() => {
    if (!live) {
      setCents(DEMO_MONTH_CENTS);
      setReady(true);
      return undefined;
    }
    setReady(false);
    setCents(0);
    const target = DEMO_MONTH_CENTS;
    const started = performance.now();
    const duration = 1900;
    let frame = 0;
    const tick = (now) => {
      const t = Math.min(1, (now - started) / duration);
      const eased = 1 - (1 - t) ** 3;
      setCents(Math.round(target * eased));
      if (t < 1) frame = window.requestAnimationFrame(tick);
    };
    frame = window.requestAnimationFrame(tick);
    const done = window.setTimeout(() => {
      setCents(target);
      setReady(true);
    }, 2100);
    return () => {
      window.cancelAnimationFrame(frame);
      window.clearTimeout(done);
    };
  }, [live]);

  return (
    <div className={`af-ob-demo ${live ? "is-live" : ""} ${ready ? "is-ready" : ""}`}>
      {live && ready ? (
        <div className="af-ob-demo__stamp" aria-hidden>
          <span className="af-ob-status__icon is-success">
            <IconCheck />
          </span>
        </div>
      ) : null}
      <div className="af-ob-demo__head">
        <span>
          {live
            ? ready
              ? appCopy("Prêt", "Ready")
              : appCopy("Création", "Creating")
            : appCopy("Exemple", "Sample")}
        </span>
        <strong>
          {live
            ? ready
              ? appCopy("Dashboard ouvert", "Dashboard open")
              : appCopy("Ton espace se construit", "Building your space")
            : appCopy("Ce qui t'attend", "What's waiting for you")}
        </strong>
      </div>
      <div className="af-ob-demo__earn">
        <span>{appCopy("Gains ce mois", "This month")}</span>
        <b>{money(cents)}</b>
      </div>
      <svg className="af-ob-demo__chart" viewBox="0 0 320 64" preserveAspectRatio="none" aria-hidden>
        <defs>
          <linearGradient id="afObDemoGrad" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#ec4899" stopOpacity="0.28" />
            <stop offset="100%" stopColor="#ec4899" stopOpacity="0" />
          </linearGradient>
        </defs>
        <path className={live ? "af-ob-demo__fill" : ""} d="M0,52 C28,50 48,46 72,40 C96,34 112,38 140,28 C168,18 188,22 216,14 C244,7 268,12 320,4 L320,64 L0,64 Z" fill="url(#afObDemoGrad)" />
        <path className={live ? "af-ob-demo__line" : ""} d="M0,52 C28,50 48,46 72,40 C96,34 112,38 140,28 C168,18 188,22 216,14 C244,7 268,12 320,4" fill="none" stroke="#ec4899" strokeWidth="2.4" />
      </svg>
      <ul className="af-ob-demo__sales">
        {DEMO_SALES.map((sale, index) => (
          <li key={`${sale.productEn}-${index}`} style={live ? { animationDelay: `${0.55 + index * 0.32}s` } : undefined}>
            <span className="af-ob-demo__logo is-stripe">
              <img src="/assets/logos/stripe-icon.png" alt="" />
            </span>
            <span>
              <strong>{appCopy(sale.productFr, sale.productEn)}</strong>
              <em>{appCopy(sale.whenFr, sale.whenEn)}</em>
            </span>
            <b>
              +{money(sale.cents)}
              {sale.mrr ? " MRR" : ""}
            </b>
          </li>
        ))}
      </ul>
    </div>
  );
}

function StepForm({ onSubmit, disabled, children }) {
  return (
    <form
      onSubmit={(event) => {
        event.preventDefault();
        if (disabled) return;
        onSubmit?.();
      }}
    >
      {children}
    </form>
  );
}

export function AffiliateOnboarding({
  user,
  busy,
  authBusy,
  error,
  authMode,
  authNotice,
  authNoticeTone,
  onUseAnotherEmail,
  onSwitchToLogin,
  onSwitchToSignup,
  onLogin,
  onLeave,
  onSubmit,
  onClaimCode,
  onConnectStripe,
  stripeBusy,
  email,
  setEmail,
  serverCodeError,
  onClearServerCodeError,
  prefill,
  onFinished,
  dashboard,
  linkUrl,
  stripeReady = false,
}) {
  const [draft, setDraft] = useState(() => {
    const initial = syncOnboardingDraftFromStripeReturn();
    if (prefill?.name && !initial.answers.firstName) {
      initial.answers.firstName = prefill.name;
    }
    return initial;
  });
  const [terms, setTerms] = useState(false);
  const [code, setCode] = useState(() => prefill?.code || "");
  const [codeError, setCodeError] = useState("");
  const [codeChecking, setCodeChecking] = useState(false);
  const [codeOk, setCodeOk] = useState(false);
  const debounceRef = useRef(null);

  const step = draft.step;
  const answers = draft.answers;

  useEffect(() => {
    if (prefill?.email && !email) setEmail(prefill.email);
  }, [prefill?.email, email, setEmail]);

  useEffect(() => {
    if (user?.email) setEmail(user.email);
    if (user?.displayName && !answers.firstName) {
      persistDraft({
        ...draft,
        answers: { ...draft.answers, firstName: user.displayName },
      });
    }
  }, [user, setEmail, answers.firstName]);

  useEffect(() => {
    const latest = readOnboardingDraft();
    if (latest.step === "preview" && step !== "preview") {
      setDraft(latest);
    }
  }, [stripeReady, dashboard, step]);

  useEffect(() => {
    if (step !== "preview") return undefined;
    playDashboardOpen();
    return undefined;
  }, [step]);

  function persistDraft(next) {
    writeOnboardingDraft(next);
    setDraft(next);
  }

  function patchAnswers(partial) {
    persistDraft({
      ...draft,
      answers: { ...draft.answers, ...partial },
    });
  }

  function goTo(next) {
    persistDraft({ ...draft, step: next });
  }

  function goNext() {
    goTo(nextOnboardingStep(step, answers));
  }

  function goBack() {
    goTo(prevOnboardingStep(step, answers));
  }

  function handleBack() {
    if (step === "firstName") {
      onLeave?.();
      return;
    }
    if (step === "stripe") {
      goTo("terms");
      return;
    }
    if (step === "preview") {
      goTo("stripe");
      return;
    }
    if (step === "invite") {
      goTo("preview");
      return;
    }
    if (step === "codeHelp") {
      goTo("invite");
      return;
    }
    goBack();
  }

  const emailValue = (user?.email || email).trim();

  async function createDashboard() {
    if (!answers.firstName.trim() || !terms || busy) return;
    persistDraft({ ...draft, applied: true, step: "stripe" });
    const ok = await onSubmit({
      displayName: answers.firstName.trim(),
      code: "",
      onboarding: answers,
    });
    if (!ok) {
      persistDraft({ ...readOnboardingDraft(), applied: false, step: "terms" });
    }
  }

  async function validateInvite(raw, { strict = false } = {}) {
    onClearServerCodeError?.();
    const trimmed = String(raw || "").trim();
    if (!trimmed) {
      setCodeError("");
      setCodeOk(false);
      return false;
    }
    const format = validateAffiliateCodeFormat(trimmed);
    if (!format.ok) {
      setCodeError(format.error);
      setCodeOk(false);
      return false;
    }
    setCodeChecking(true);
    try {
      const result = await checkAffiliateCodeAvailability(trimmed, { uid: user?.uid });
      setCodeError(result.ok ? "" : result.error);
      setCodeOk(result.ok);
      return result.ok;
    } finally {
      setCodeChecking(false);
    }
  }

  useEffect(() => {
    if (serverCodeError) {
      setCodeError(serverCodeError);
      setCodeOk(false);
    }
  }, [serverCodeError]);

  useEffect(() => {
    if (step !== "invite") return undefined;
    if (debounceRef.current) window.clearTimeout(debounceRef.current);
    if (!code.trim()) {
      setCodeError("");
      setCodeOk(false);
      return undefined;
    }
    debounceRef.current = window.setTimeout(() => {
      validateInvite(code);
    }, 450);
    return () => {
      if (debounceRef.current) window.clearTimeout(debounceRef.current);
    };
  }, [code, step, user?.uid]);

  async function finishWithCode() {
    const valid = await validateInvite(code, { strict: true });
    if (!valid) return;
    const ok = await onClaimCode?.({
      displayName: answers.firstName.trim(),
      code: parseAcquisitionCodeFromInput(code),
      email: emailValue,
      onboarding: answers,
    });
    if (ok !== false) onFinished?.();
  }

  function renderStep() {
    if (!draft.applied && authMode === "login") {
      return (
        <div className="af-ob-login">
          <p className="af-ob-kicker">{appCopy("Compte", "Account")}</p>
          <h1 className="af-ob-title">{appCopy("Reconnecte-toi", "Sign back in")}</h1>
          <p className="af-ob-lead">
            {appCopy(
              "Entre ton email — on t'envoie un lien, sans mot de passe.",
              "Enter your email — we'll send a link, no password."
            )}
          </p>
          <div style={{ marginTop: 22 }}>
            <ApplyLoginInline
              email={email}
              setEmail={setEmail}
              authBusy={authBusy}
              busy={busy}
              error={error}
              authNotice={authNotice}
              authNoticeTone={authNoticeTone}
              onLogin={onLogin}
              onSwitchToSignup={onSwitchToSignup}
              onUseAnotherEmail={onUseAnotherEmail}
            />
          </div>
        </div>
      );
    }

    if (step === "firstName") {
      return (
        <StepForm onSubmit={goNext} disabled={!answers.firstName.trim()}>
          <p className="af-ob-kicker">{appCopy("Onboarding créateur", "Creator onboarding")}</p>
          <h1 className="af-ob-title">{appCopy("C'est quoi ton prénom ?", "What's your first name?")}</h1>
          <p className="af-ob-lead">
            {appCopy("On l'utilise pour ton espace et tes virements.", "We use it for your workspace and payouts.")}
          </p>
          <input
            className="af-ob-input"
            value={answers.firstName}
            onChange={(e) => patchAnswers({ firstName: e.target.value })}
            placeholder={appCopy("Ex. Amine", "e.g. Amine")}
            autoComplete="given-name"
            autoFocus
          />
          <Actions
            onNext={goNext}
            nextDisabled={!answers.firstName.trim()}
            nextLabel={appCopy("Continuer", "Continue")}
          />
        </StepForm>
      );
    }

    if (step === "tiktokHandle") {
      const handles = Array.isArray(answers.tiktokHandles) && answers.tiktokHandles.length
        ? answers.tiktokHandles
        : [answers.tiktokHandle || ""];
      const hasOne = handles.some((value) => value.trim());

      function setHandles(next) {
        const list = next.length ? next.slice(0, 8) : [""];
        patchAnswers({
          tiktokHandles: list,
          tiktokHandle: list.map((value) => value.trim()).filter(Boolean).join(" "),
        });
      }

      return (
        <StepForm onSubmit={goNext} disabled={!hasOne}>
          <p className="af-ob-kicker">TikTok</p>
          <h1 className="af-ob-title">{appCopy("C'est quoi ton @ ?", "What's your @?")}</h1>
          <p className="af-ob-lead">
            {appCopy(
              "TikTok, Instagram… tu peux en ajouter plusieurs. Sinon, passe.",
              "TikTok, Instagram… you can add several. Or skip."
            )}
          </p>
          <div className="af-ob-handles">
            {handles.map((value, index) => (
              <div key={`handle-${index}`} className="af-ob-handle">
                <input
                  className="af-ob-input"
                  value={value}
                  onChange={(e) => {
                    const next = [...handles];
                    next[index] = e.target.value;
                    setHandles(next);
                  }}
                  placeholder={index === 0 ? "@manny" : appCopy("@autrecompte", "@otheraccount")}
                  autoComplete="username"
                  autoFocus={index === 0}
                />
                {handles.length > 1 ? (
                  <button
                    type="button"
                    className="af-ob-handle__remove"
                    onClick={() => setHandles(handles.filter((_, i) => i !== index))}
                    aria-label={appCopy("Retirer ce compte", "Remove this account")}
                  >
                    ×
                  </button>
                ) : null}
              </div>
            ))}
          </div>
          {handles.length < 8 ? (
            <button
              type="button"
              className="af-ob-add"
              onClick={() => setHandles([...handles, ""])}
            >
              {appCopy("+ Ajouter un compte", "+ Add an account")}
            </button>
          ) : null}
          <Actions
            onNext={goNext}
            nextDisabled={!hasOne}
            nextLabel={appCopy("Continuer", "Continue")}
          />
          <button type="button" className="af-ob-btn af-ob-btn--ghost af-ob-btn--skip" onClick={goNext}>
            {appCopy("Passer", "Skip")}
          </button>
        </StepForm>
      );
    }

    if (step === "hours") {
      return (
        <>
          <p className="af-ob-kicker">{appCopy("Disponibilité", "Availability")}</p>
          <h1 className="af-ob-title">
            {appCopy("Combien d'heures par jour tu peux bosser ?", "How many hours a day can you work?")}
          </h1>
          <ChoiceList
            options={HOURS}
            value={answers.hoursPerDay}
            onChange={(id) => {
              patchAnswers({ hoursPerDay: id });
              window.setTimeout(() => goTo("budget"), 160);
            }}
          />
          <Actions onNext={goNext} nextDisabled={!answers.hoursPerDay} nextLabel={appCopy("Continuer", "Continue")} />
        </>
      );
    }

    if (step === "budget") {
      return (
        <>
          <p className="af-ob-kicker">{appCopy("Outils", "Tools")}</p>
          <h1 className="af-ob-title">
            {appCopy("Ton budget pour les tools d'automatisation ?", "What's your automation-tools budget?")}
          </h1>
          <p className="af-ob-lead">
            {appCopy("On calibre la méthode là-dessus.", "We calibrate the method around this.")}
          </p>
          <ChoiceList
            options={BUDGETS}
            value={answers.toolBudget}
            onChange={(id) => {
              patchAnswers({ toolBudget: id });
              window.setTimeout(() => goTo("experience"), 160);
            }}
          />
          <Actions onNext={goNext} nextDisabled={!answers.toolBudget} nextLabel={appCopy("Continuer", "Continue")} />
        </>
      );
    }

    if (step === "experience") {
      return (
        <>
          <p className="af-ob-kicker">{appCopy("Niveau", "Level")}</p>
          <h1 className="af-ob-title">{appCopy("Où tu en es aujourd'hui ?", "Where are you today?")}</h1>
          <p className="af-ob-lead">
            {appCopy("On calibre la méthode sur ce que tu as déjà posté.", "We calibrate the method from what you've already posted.")}
          </p>
          <ChoiceList
            options={EXPERIENCE}
            value={answers.experience}
            onChange={(id) => {
              patchAnswers({ experience: id });
              window.setTimeout(() => goTo("tiktokHandle"), 160);
            }}
          />
          <Actions onNext={goNext} nextDisabled={!answers.experience} nextLabel={appCopy("Continuer", "Continue")} />
        </>
      );
    }

    if (step === "goal") {
      const count = parseAccountCount(answers);
      return (
        <>
          <p className="af-ob-kicker">{appCopy("Comptes", "Accounts")}</p>
          <h1 className="af-ob-title">
            {appCopy(
              "Combien de comptes TikTok peux-tu encore créer ?",
              "How many more TikTok accounts can you still create?"
            )}
          </h1>
          <p className="af-ob-hint">
            {appCopy("Maximum 5 comptes par iPhone.", "Maximum 5 accounts per iPhone.")}
          </p>
          <ChoiceList
            options={ACCOUNT_OPTIONS}
            value={count ? String(count) : ""}
            onChange={(id) => {
              const value = Math.min(ACCOUNT_MAX, Math.max(ACCOUNT_MIN, Number(id)));
              patchAnswers({ accountCount: value, goal: String(value) });
            }}
          />
          <Actions
            onNext={goNext}
            nextDisabled={!count}
            nextLabel={appCopy("Continuer", "Continue")}
          />
        </>
      );
    }

    if (step === "terms") {
      return (
        <>
          <p className="af-ob-kicker">{appCopy("Presque", "Almost")}</p>
          <h1 className="af-ob-title">
            {appCopy("On ouvre ton dashboard", "Let's open your dashboard")}
          </h1>
          <p className="af-ob-lead">
            {appCopy(
              `Ensuite tu connectes Stripe pour tes ${COMMISSION_PERCENT} % et tu vois ton espace.`,
              `Next you connect Stripe for your ${COMMISSION_PERCENT}% and preview your workspace.`
            )}
          </p>
          <label className="af-ob-check">
            <input type="checkbox" checked={terms} onChange={(e) => setTerms(e.target.checked)} />
            <span>
              {appCopy("J'accepte les", "I agree to the")}{" "}
              <a href={TERMS_URL} target="_blank" rel="noopener noreferrer">
                {appCopy("Conditions du programme Process", "Process Program Terms")}
              </a>
            </span>
          </label>
          {error ? <p className="af-ob-error">{error}</p> : null}
          <Actions
            onNext={createDashboard}
            nextDisabled={busy || !answers.firstName.trim() || !terms}
            nextLabel={appCopy("Créer mon dashboard", "Create my dashboard")}
          />
        </>
      );
    }

    if (step === "stripe") {
      return (
        <div className="af-ob-status">
          <img className="af-ob-stripe-logo" src="/assets/logos/stripe-wordmark.png" alt="Stripe" />
          <h2>{appCopy("Reçois tes paiements", "Get paid")}</h2>
          <p className="af-ob-lead">
            {appCopy(
              `Configure Stripe Affiliate pour encaisser tes ${COMMISSION_PERCENT} %. Compte courant, IBAN exact, même nom que ton profil.`,
              `Set up Stripe Affiliate to receive your ${COMMISSION_PERCENT}%. Checking account, exact IBAN, same name as your profile.`
            )}
          </p>
          {error ? <p className="af-ob-error">{error}</p> : null}
          <div className="af-ob-actions" style={{ width: "100%" }}>
            <button
              type="button"
              className="af-ob-btn af-ob-btn--primary"
              disabled={stripeBusy}
              onClick={() => {
                persistDraft({ ...draft, stripeStarted: true });
                onConnectStripe?.();
              }}
            >
              {stripeBusy
                ? appCopy("Redirection…", "Redirecting…")
                : appCopy("Configurer Stripe Affiliate", "Set up Stripe Affiliate")}
            </button>
          </div>
          <button
            type="button"
            className="af-ob-btn af-ob-btn--ghost af-ob-btn--skip"
            disabled={stripeBusy}
            onClick={() => goTo("preview")}
          >
            {appCopy("Configurer plus tard", "Set up later")}
          </button>
        </div>
      );
    }

    if (step === "preview") {
      return (
        <div>
          <p className="af-ob-kicker">{appCopy("Aperçu", "Preview")}</p>
          <h1 className="af-ob-title">{appCopy("Voici ton dashboard", "Here's your dashboard")}</h1>
          <p className="af-ob-lead">
            {appCopy(
              "Ton espace se construit. Les ventes et tes primes arrivent ici.",
              "Your workspace is building. Sales and bonuses land here."
            )}
          </p>
          <SimulatedDashboard live />
          <div className="af-ob-primes">
            <div className="af-ob-primes__head">
              <span>{appCopy("Primes", "Bonuses")}</span>
              <strong>{appCopy("Primes à débloquer", "Bonuses to unlock")}</strong>
            </div>
            <ViewBonusBoard variant="light" compact showEligibility={false} />
            <ViewBonusNote />
          </div>
          {error ? <p className="af-ob-error">{error}</p> : null}
          <Actions
            onNext={() => goTo("invite")}
            nextLabel={appCopy("Continuer", "Continue")}
          />
        </div>
      );
    }

    if (step === "codeHelp") {
      const appStoreHref = getStoreButtonHref(getIosAppStoreUrl());
      const howTo = [
        {
          n: "1",
          titleFr: "Télécharge Process",
          titleEn: "Download Process",
          textFr: "Installe l'app, ouvre-la et avance jusqu'au paywall.",
          textEn: "Install the app, open it, and go through to the paywall.",
          href: appStoreHref,
          img: "/assets/affiliate-howto/00-open.png",
          wide: true,
        },
        {
          n: "2",
          titleFr: "Appuie 3 fois sur la croix",
          titleEn: "Tap the X 3 times",
          textFr: "En haut à droite du paywall. Pas une fois : trois fois.",
          textEn: "Top-right of the paywall. Not once — three times.",
          img: "/assets/affiliate-howto/01-tap-x.png",
        },
        {
          n: "3",
          titleFr: "Prends l'offre lifetime 19 $",
          titleEn: "Grab the $19 lifetime offer",
          textFr: "Le pop-up « Attends ! » s'ouvre. Appuie sur Tente ta chance, puis prends l'offre à vie à 19 $.",
          textEn: "The “Wait!” popup appears. Tap Try your luck, then take the $19 lifetime offer.",
          img: "/assets/affiliate-howto/02-popup.png",
        },
        {
          n: "4",
          titleFr: "Réglages → Parrainage",
          titleEn: "Settings → Referral",
          textFr: "Ouvre Réglages, puis Parrainage. Pas Programme créateurs.",
          textEn: "Open Settings, then Referral. Not Creator Program.",
          img: "/assets/affiliate-howto/03-parrainage.png",
        },
        {
          n: "5",
          titleFr: "Copie ton code",
          titleEn: "Copy your code",
          textFr: "Ton code est sur la carte. Appuie sur Copier, reviens ici, colle-le.",
          textEn: "Your code is on the card. Tap Copy, come back here, paste it.",
          img: "/assets/affiliate-howto/04-code.png",
        },
      ];
      return (
        <div className="af-ob-guide">
          <p className="af-ob-kicker">{appCopy("Code", "Code")}</p>
          <h1 className="af-ob-title">
            {appCopy("Comment avoir ton code", "How to get your code")}
          </h1>
          <p className="af-ob-lead">
            {appCopy(
              "5 étapes. Offre lifetime 19 $, puis ton code dans Parrainage.",
              "5 steps. $19 lifetime offer, then your code in Referral."
            )}
          </p>
          <ol className="af-ob-guide__list">
            {howTo.map((item) => (
              <li key={item.n} className={`af-ob-guide__step ${item.wide ? "is-wide" : ""}`}>
                <div className="af-ob-guide__meta">
                  <span>{item.n}</span>
                  <div>
                    <strong>{appCopy(item.titleFr, item.titleEn)}</strong>
                    <p>{appCopy(item.textFr, item.textEn)}</p>
                    {item.href ? (
                      <a className="af-ob-btn af-ob-btn--primary af-ob-guide__open" href={item.href} target="_blank" rel="noopener noreferrer">
                        <img src="/assets/logos/app-store.png" alt="" />
                        {appCopy("Ouvrir Process", "Open Process")}
                      </a>
                    ) : null}
                  </div>
                </div>
                {item.img ? (
                  item.href ? (
                    <a className="af-ob-guide__shot-link" href={item.href} target="_blank" rel="noopener noreferrer">
                      <img className="af-ob-guide__shot" src={item.img} alt="" />
                    </a>
                  ) : (
                    <img className="af-ob-guide__shot" src={item.img} alt="" />
                  )
                ) : null}
              </li>
            ))}
          </ol>
          <div className="af-ob-actions">
            <button type="button" className="af-ob-btn af-ob-btn--primary" onClick={() => goTo("invite")}>
              {appCopy("J'ai mon code", "I have my code")}
            </button>
          </div>
        </div>
      );
    }

    return (
      <StepForm
        onSubmit={finishWithCode}
        disabled={busy || !code.trim() || Boolean(codeError) || codeChecking}
      >
        <p className="af-ob-kicker">{appCopy("Accès", "Access")}</p>
        <h1 className="af-ob-title">
          {appCopy("Entre ton code de parrainage pour activer ton compte", "Enter your referral code to activate your account")}
        </h1>
        <p className="af-ob-lead">
          {appCopy(
            "Ce code débloque ton dashboard et la méthode TikTok Process.",
            "This code unlocks your dashboard and the Process TikTok method."
          )}
        </p>
        <input
          className="af-ob-input"
          value={code}
          onChange={(e) => {
            onClearServerCodeError?.();
            setCode(parseAcquisitionCodeFromInput(e.target.value));
          }}
          placeholder="ZKKUN"
          autoComplete="off"
          spellCheck={false}
          autoFocus
        />
        {codeChecking ? (
          <p className="af-ob-help">{appCopy("Vérification…", "Checking…")}</p>
        ) : codeError ? (
          <p className="af-ob-error">{codeError}</p>
        ) : codeOk ? (
          <p className="af-ob-help">{appCopy("Code valide — tu peux entrer.", "Valid code — you can enter.")}</p>
        ) : null}
        {error ? <p className="af-ob-error">{error}</p> : null}
        <Actions
          onNext={finishWithCode}
          nextDisabled={busy || !code.trim() || Boolean(codeError) || codeChecking}
          nextLabel={busy ? appCopy("Ouverture…", "Opening…") : appCopy("Accéder au dashboard", "Enter dashboard")}
        />
        <button type="button" className="af-ob-btn af-ob-btn--ghost af-ob-btn--skip" onClick={() => goTo("codeHelp")}>
          {appCopy("Je n'ai pas de code", "I don't have a code")}
        </button>
      </StepForm>
    );
  }

  return (
    <div className="af-app af-ob af-ld-apply">
        <div className={`af-ob-shell ${step === "codeHelp" ? "is-guide" : ""}`}>
        <div className="af-ob-toolbar">
          <button type="button" className="af-ob-back" onClick={handleBack} aria-label={appCopy("Retour", "Back")}>
            <IconChevronLeft />
          </button>
          <Progress step={step} />
        </div>
        <div className="af-ob-card" key={step}>
          {step === "firstName" ? (
            <div style={{ display: "flex", justifyContent: "center", marginBottom: 18 }}>
              <ProcessAppIcon size={36} />
            </div>
          ) : null}
          {renderStep()}
        </div>
      </div>
    </div>
  );
}

function ApplyLoginInline({
  email,
  setEmail,
  authBusy,
  busy,
  error,
  authNotice,
  authNoticeTone,
  onLogin,
  onSwitchToSignup,
  onUseAnotherEmail,
}) {
  const emailOk = isValidEmail(email.trim());
  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        if (!emailOk) return;
        onLogin?.({ email: email.trim() });
      }}
    >
      <input
        className="af-ob-input"
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="email@icloud.com"
        autoComplete="email"
      />
      {authNotice ? (
        <p className="af-ob-help">
          {authNotice}{" "}
          {authNoticeTone !== "success" ? (
            <button type="button" className="af-inline-link" onClick={() => onUseAnotherEmail?.()}>
              {appCopy("Autre email", "Another email")}
            </button>
          ) : null}
        </p>
      ) : null}
      {error ? <p className="af-ob-error">{error}</p> : null}
      <div className="af-ob-actions">
        <button
          type="submit"
          className="af-ob-btn af-ob-btn--primary"
          disabled={!emailOk || authBusy || busy}
        >
          {authBusy ? appCopy("Envoi…", "Sending…") : appCopy("Recevoir le lien", "Email me the link")}
        </button>
      </div>
      <button type="button" className="af-text-link-below" onClick={() => onSwitchToSignup?.()}>
        {appCopy("Créer un compte", "Create an account")}
      </button>
    </form>
  );
}
