import { useEffect, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconChevronLeft, ProcessAppIcon } from "./AffiliateIcons.jsx";
import { isValidEmail } from "./affiliate-utils.js";
import {
  emptyOnboardingAnswers,
  readOnboardingDraft,
  writeOnboardingDraft,
} from "./affiliate-onboarding-state.js";
import "./affiliate-onboarding.css";

const TERMS_URL = "https://useprocess.xyz/terms";

function isValidPhone(raw) {
  const digits = String(raw || "").replace(/\D/g, "");
  return digits.length >= 8 && digits.length <= 15;
}

export function AffiliateOnboarding({
  user,
  busy,
  authBusy,
  error,
  authMode,
  authNotice,
  authNoticeTone,
  emailLinkConfirm = false,
  onUseAnotherEmail,
  onSwitchToLogin,
  onSwitchToSignup,
  onLogin,
  onLeave,
  onSubmit,
  email,
  setEmail,
  prefill,
  onFinished,
}) {
  const draft = readOnboardingDraft();
  const [firstName, setFirstName] = useState(
    () => prefill?.name || draft.answers?.firstName || user?.displayName || ""
  );
  const [phone, setPhone] = useState(() => draft.answers?.phone || "");
  const [terms, setTerms] = useState(false);

  useEffect(() => {
    if (prefill?.email && !email) setEmail(prefill.email);
  }, [prefill?.email, email, setEmail]);

  useEffect(() => {
    if (user?.email) setEmail(user.email);
  }, [user, setEmail]);

  const emailValue = (user?.email || email || "").trim();
  const nameOk = firstName.trim().length >= 2;
  const emailOk = isValidEmail(emailValue);
  const phoneOk = isValidPhone(phone);
  const canSubmit = nameOk && emailOk && phoneOk && terms && !busy && !authBusy;

  function persistAnswers(nextFirstName = firstName, nextPhone = phone) {
    writeOnboardingDraft({
      ...readOnboardingDraft(),
      answers: {
        ...emptyOnboardingAnswers(),
        ...readOnboardingDraft().answers,
        firstName: nextFirstName.trim(),
        phone: nextPhone.trim(),
      },
    });
  }

  async function handleSubmit(event) {
    event?.preventDefault?.();
    if (!canSubmit) return;
    persistAnswers();
    const ok = await onSubmit({
      displayName: firstName.trim(),
      email: emailValue,
      phone: phone.trim(),
      onboarding: {
        firstName: firstName.trim(),
        phone: phone.trim(),
      },
    });
    if (ok) onFinished?.();
  }

  if (authMode === "login") {
    return (
      <div className="af-app af-ob af-ld-apply">
        <div className="af-ob-shell">
          <div className="af-ob-toolbar">
            <button type="button" className="af-ob-back" onClick={onLeave} aria-label={appCopy("Retour", "Back")}>
              <IconChevronLeft />
            </button>
          </div>
          <div className="af-ob-card">
            <div className="af-ob-brand">
              <ProcessAppIcon size={36} />
            </div>
            <p className="af-ob-kicker">{appCopy("Compte", "Account")}</p>
            <h1 className="af-ob-title">
              {emailLinkConfirm
                ? appCopy("Confirme ton email", "Confirm your email")
                : appCopy("Reconnecte-toi", "Sign back in")}
            </h1>
            <p className="af-ob-lead">
              {emailLinkConfirm
                ? appCopy(
                    "Tu viens du lien reçu par email — entre le même email pour te connecter.",
                    "You opened the email link — enter the same email to sign in."
                  )
                : appCopy(
                    "Tu t'es inscrit sur un autre appareil ? Entre le même email — on t'envoie un lien, sans mot de passe.",
                    "Signed up on another device? Enter the same email — we'll send a link, no password."
                  )}
            </p>
            <ApplyLoginInline
              email={email}
              setEmail={setEmail}
              authBusy={authBusy}
              busy={busy}
              error={error}
              authNotice={authNotice}
              authNoticeTone={authNoticeTone}
              emailLinkConfirm={emailLinkConfirm}
              onLogin={onLogin}
              onSwitchToSignup={onSwitchToSignup}
              onUseAnotherEmail={onUseAnotherEmail}
            />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="af-app af-ob af-ld-apply">
      <div className="af-ob-shell">
        <div className="af-ob-toolbar">
          <button type="button" className="af-ob-back" onClick={onLeave} aria-label={appCopy("Retour", "Back")}>
            <IconChevronLeft />
          </button>
        </div>
        <div className="af-ob-card">
          <div className="af-ob-brand">
            <ProcessAppIcon size={36} />
          </div>
          <p className="af-ob-kicker">{appCopy("Programme clipper", "Clipper program")}</p>
          <h1 className="af-ob-title">{appCopy("Crée ton lien clipper", "Create your clipper link")}</h1>
          <p className="af-ob-lead">
            {appCopy(
              "Prénom, email, téléphone. Ton lien clipper est créé tout de suite — pas besoin de l’app.",
              "First name, email, phone. Your clipper link is created right away — no app needed."
            )}
          </p>

          <form className="af-ob-form" onSubmit={handleSubmit}>
            <label className="af-ob-field">
              <span>{appCopy("Prénom", "First name")}</span>
              <input
                className="af-ob-input"
                value={firstName}
                onChange={(e) => {
                  setFirstName(e.target.value);
                  persistAnswers(e.target.value, phone);
                }}
                placeholder={appCopy("Ex. Amine", "e.g. Amine")}
                autoComplete="given-name"
                autoFocus
              />
            </label>

            <label className="af-ob-field">
              <span>{appCopy("Email", "Email")}</span>
              <input
                className="af-ob-input"
                type="email"
                value={emailValue}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="email@icloud.com"
                autoComplete="email"
                disabled={Boolean(user?.email)}
              />
            </label>

            <label className="af-ob-field">
              <span>{appCopy("Téléphone", "Phone")}</span>
              <input
                className="af-ob-input"
                type="tel"
                inputMode="tel"
                value={phone}
                onChange={(e) => {
                  setPhone(e.target.value);
                  persistAnswers(firstName, e.target.value);
                }}
                placeholder="+33 6 12 34 56 78"
                autoComplete="tel"
              />
            </label>

            <label className="af-ob-check">
              <input type="checkbox" checked={terms} onChange={(e) => setTerms(e.target.checked)} />
              <span>
                {appCopy("J’accepte les", "I agree to the")}{" "}
                <a href={TERMS_URL} target="_blank" rel="noopener noreferrer">
                  {appCopy("conditions", "terms")}
                </a>.
              </span>
            </label>

            {error ? <p className="af-ob-error">{error}</p> : null}

            <button type="submit" className="af-ob-btn af-ob-btn--primary" disabled={!canSubmit}>
              {busy
                ? appCopy("Création du lien…", "Creating your link…")
                : appCopy("Créer mon lien", "Create my link")}
            </button>
          </form>

          <p className="af-ob-switch">
            {appCopy("Déjà inscrit ?", "Already in?")}{" "}
            <button type="button" className="af-ob-inline-link" onClick={onSwitchToLogin}>
              {appCopy("Connexion", "Sign in")}
            </button>
          </p>
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
  emailLinkConfirm = false,
  onLogin,
  onSwitchToSignup,
  onUseAnotherEmail,
}) {
  const emailOk = isValidEmail(email.trim());
  return (
    <form
      className="af-ob-form"
      onSubmit={(e) => {
        e.preventDefault();
        if (!emailOk) return;
        onLogin?.({ email: email.trim() });
      }}
    >
      <label className="af-ob-field">
        <span>{appCopy("Email", "Email")}</span>
        <input
          className="af-ob-input"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="email@icloud.com"
          autoComplete="email"
          autoFocus
        />
      </label>
      {authNotice ? (
        <p className={`af-ob-help ${authNoticeTone === "success" ? "is-ok" : ""}`}>{authNotice}</p>
      ) : null}
      {error ? <p className="af-ob-error">{error}</p> : null}
      <button
        type="submit"
        className="af-ob-btn af-ob-btn--primary"
        disabled={!emailOk || authBusy || busy}
      >
        {authBusy
          ? appCopy("Connexion…", "Signing in…")
          : emailLinkConfirm
            ? appCopy("Se connecter", "Sign in")
            : appCopy("Recevoir le lien", "Send the link")}
      </button>
      <p className="af-ob-switch">
        {appCopy("Pas encore de compte ?", "No account yet?")}{" "}
        <button type="button" className="af-ob-inline-link" onClick={onSwitchToSignup}>
          {appCopy("Inscription", "Sign up")}
        </button>
        {onUseAnotherEmail ? (
          <>
            {" · "}
            <button type="button" className="af-ob-inline-link" onClick={onUseAnotherEmail}>
              {appCopy("Autre email", "Another email")}
            </button>
          </>
        ) : null}
      </p>
    </form>
  );
}
