import { appCopy } from "../features/app-copy.js";
import { IconCheck, IconLink } from "./AffiliateIcons.jsx";
import { COMMISSION_PERCENT, HOLD_DAYS } from "./affiliate-utils.js";
import { readMethodPace, readOnboardingDraft } from "./affiliate-onboarding-state.js";
import { paceFromHours } from "./method-catalog.js";
import "./affiliate-method.css";

const BUDGET_STACKS = [
  {
    id: "0",
    title: { fr: "0 € — TikTok natif", en: "$0 — native TikTok" },
    items: [
      {
        fr: "Brouillons Photo Mode. Un rappel quotidien. Un compte.",
        en: "Photo Mode drafts. One daily reminder. One account.",
      },
      {
        fr: "Tu publies à la main, tu épingles le commentaire tout de suite.",
        en: "You publish by hand, you pin the comment immediately.",
      },
    ],
  },
  {
    id: "lt50",
    title: { fr: "Moins de 50 € — file d'attente", en: "Under $50 — a queue" },
    items: [
      {
        fr: "Un scheduler (brouillons, pas publish auto). 1–2 comptes.",
        en: "One scheduler (drafts, not auto-publish). 1–2 accounts.",
      },
      {
        fr: "Chaque slot = visuels différents. Jamais 10 posts le dimanche.",
        en: "Each slot = different visuals. Never 10 posts on Sunday.",
      },
    ],
  },
  {
    id: "50-150",
    title: { fr: "50–150 € — plusieurs comptes", en: "$50–150 — multiple accounts" },
    items: [
      {
        fr: "Un scheduler, N comptes. Chauffe 2 jours avant d'augmenter le volume.",
        en: "One scheduler, N accounts. Warm 2 days before raising volume.",
      },
      {
        fr: "Même format, photos et hooks différents. Le pin reste manuel.",
        en: "Same format, different photos and hooks. The pin stays manual.",
      },
    ],
  },
  {
    id: "150+",
    title: { fr: "150 €+ — volume", en: "$150+ — volume" },
    items: [
      {
        fr: "3–5 comptes. Un opérateur qui épingle après chaque publish.",
        en: "3–5 accounts. An operator who pins after every publish.",
      },
      {
        fr: "Pas de Spark Ads. Pas de pack Manny recollé à l'identique.",
        en: "No Spark Ads. Don't reupload the identical Manny pack.",
      },
    ],
  },
];

function readAutomationProfile() {
  const pace = readMethodPace();
  const draft = readOnboardingDraft();
  const answers = draft?.answers || {};
  return {
    hoursPerDay: pace.hoursPerDay || answers.hoursPerDay || "",
    accountCount: pace.accountCount || answers.accountCount || "",
    toolBudget: pace.toolBudget || answers.toolBudget || "",
  };
}

function StackCard({ stack, active }) {
  return (
    <article className={`af-auto-stack${active ? " is-on" : ""}`}>
      <h3>
        {active ? <IconCheck /> : null}
        {appCopy(stack.title.fr, stack.title.en)}
      </h3>
      <ul>
        {stack.items.map((item) => (
          <li key={item.en}>{appCopy(item.fr, item.en)}</li>
        ))}
      </ul>
    </article>
  );
}

export function AffiliateAutomationPage({ primaryCode = "", linkUrl = "", onGoFormats, onGoOverview }) {
  const paceState = readAutomationProfile();
  const pace = paceFromHours(paceState.hoursPerDay);
  const budget = paceState.toolBudget;
  const code = primaryCode || "CODE";
  const link = linkUrl.replace(/^https:\/\//, "") || "useprocess.xyz/join/CODE";
  const accounts = paceState.accountCount
    ? appCopy(`${paceState.accountCount} compte(s)`, `${paceState.accountCount} account(s)`)
    : "";

  return (
    <div className="af-md af-md--solo">
      <article className="af-md-page">
        <p className="af-md-kicker">{appCopy("Volume sans te cramer", "Volume without burning the account")}</p>
        <h2>{appCopy("Automatisation", "Automation")}</h2>
        <p className="af-md-lead">
          {appCopy(
            `Les ${COMMISSION_PERCENT} % sont déjà automatiques dès qu'un abo passe par ton lien. Le posting, non. Cette page, c'est la file : rythme, outils, pin.`,
            `The ${COMMISSION_PERCENT}% is already automatic once a sub comes through your link. Posting is not. This page is the queue: pace, tools, pin.`
          )}
        </p>

        <p className="af-md-pace">
          {appCopy("Ton rythme :", "Your pace:")} <strong>{appCopy(pace.fr, pace.en)}</strong>
          {accounts ? ` · ${accounts}` : ""}
        </p>

        <section className="af-md-section">
          <h3>{appCopy("Ce qui est auto", "What's automatic")}</h3>
          <ol className="af-md-ol">
            <li>
              {appCopy(
                "Attribution lien / code — cookie 30 jours, reset à chaque clic.",
                "Link / code attribution — 30-day cookie, resets on every click."
              )}
            </li>
            <li>
              {appCopy(
                `Commissions → Stripe après ${HOLD_DAYS} jours de retenue.`,
                `Commissions → Stripe after a ${HOLD_DAYS}-day hold.`
              )}
            </li>
            <li>
              {appCopy(
                "Les primes vues ne sont pas auto. Review manuelle, DM leks.",
                "View bonuses are not automatic. Manual review, DM leks."
              )}
            </li>
          </ol>
        </section>

        <section className="af-md-section">
          <h3>{appCopy("Stack selon le budget", "Stack by budget")}</h3>
          <div className="af-auto-stacks">
            {BUDGET_STACKS.map((stack) => (
              <StackCard key={stack.id} stack={stack} active={budget === stack.id} />
            ))}
          </div>
        </section>

        <section className="af-md-section">
          <h3>{appCopy("La séquence", "The sequence")}</h3>
          <ol className="af-md-ol">
            <li>{appCopy("Copier un format (page Formats).", "Copy a format (Formats page).")}</li>
            <li>{appCopy("Changer photos + hook. Jamais le même JPG.", "Change photos + hook. Never the same JPG.")}</li>
            <li>{appCopy("Brouillon ou file — pas 10 posts d'un coup.", "Draft or queue — not 10 posts at once.")}</li>
            <li>{appCopy("Publier en Photo Mode.", "Publish in Photo Mode.")}</li>
            <li>
              {appCopy(
                `Épingler : ${link} · code ${code}`,
                `Pin: ${link} · code ${code}`
              )}
            </li>
            <li>{appCopy("Bio = le même lien. Toujours.", "Bio = the same link. Always.")}</li>
          </ol>
        </section>

        <section className="af-md-section af-md-section--dont">
          <h3>{appCopy("Ne jamais automatiser", "Never automate")}</h3>
          <ul className="af-md-ul">
            <li>{appCopy("Recoller le pack Manny identique.", "Reuploading the identical Manny pack.")}</li>
            <li>{appCopy("Poster sans pin + bio.", "Posting without pin + bio.")}</li>
            <li>{appCopy("TikTok Ads, Spark, Meta.", "TikTok Ads, Spark, Meta.")}</li>
            <li>{appCopy("Claims médicaux (“guérit”, “diagnostic”).", "Medical claims (“cures”, “diagnosis”).")}</li>
          </ul>
        </section>

        <p className="af-md-callout">
          {appCopy(
            "Sans pin, tu fais des vues pour TikTok. Avec pin, tu fais des abos pour Process.",
            "Without the pin, you're making views for TikTok. With the pin, you're making subs for Process."
          )}
        </p>

        <div className="af-auto-ctas">
          {onGoFormats ? (
            <button type="button" className="af-md-inline-link" onClick={onGoFormats}>
              {appCopy("Ouvrir Formats", "Open Formats")}
            </button>
          ) : null}
          {onGoOverview ? (
            <button type="button" className="af-md-inline-link" onClick={onGoOverview}>
              <IconLink />
              {appCopy("Voir mon lien", "See my link")}
            </button>
          ) : null}
        </div>
      </article>
    </div>
  );
}
