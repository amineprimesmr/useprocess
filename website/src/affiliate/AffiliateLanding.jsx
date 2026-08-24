import { useEffect, useId, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconChevronDown, IconX, ProcessAppIcon } from "./AffiliateIcons.jsx";
import {
  AFFILIATE_X_HANDLE,
  COMMISSION_PERCENT,
  HOLD_DAYS,
  SUPPORT_EMAIL,
  VIEW_BONUS_MAX_PER_VIDEO_USD,
  VIEW_BONUS_TIERS,
  formatViewCount,
  viewBonusUsdForViews,
} from "./affiliate-utils.js";
import { ViewBonusBoard, ViewBonusNote } from "./ViewBonusBoard.jsx";
import "./affiliate-landing.css";

const PRIVACY_URL = "https://useprocess.xyz/privacy";
const TERMS_URL = "https://useprocess.xyz/terms";
const YEAR = new Date().getFullYear();
const X_URL = `https://x.com/${AFFILIATE_X_HANDLE}`;

function BracketKicker({ children }) {
  return <p className="af-ld-kicker">[ {children} ]</p>;
}

function IconPersonPlus() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <circle cx="9" cy="8" r="3.1" />
      <path d="M3.6 19c.4-3 2.9-4.6 5.4-4.6s5 1.6 5.4 4.6" />
      <path d="M17 8v6M14 11h6" />
    </svg>
  );
}

function IconBubble() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <path d="M5 16.5V7.8A2.8 2.8 0 0 1 7.8 5h8.4A2.8 2.8 0 0 1 19 7.8v5.2A2.8 2.8 0 0 1 16.2 16H9l-4 3.2z" />
    </svg>
  );
}

function IconCoinMark() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden>
      <circle cx="12" cy="12" r="8" />
      <path d="M12 7.5v9M9.4 10.2h3.4a1.6 1.6 0 0 1 0 3.2H9.4" />
    </svg>
  );
}

export function AffiliateTopNav({
  onApply,
  onLogin,
  loggedIn = false,
  onWorkspace,
  compact = false,
}) {
  const label = loggedIn
    ? appCopy("Mon espace", "Dashboard")
    : compact
      ? appCopy("Se connecter", "Log in")
      : appCopy("Se connecter · S'inscrire", "Log in · Sign up");

  function handleAuth() {
    if (loggedIn) {
      onWorkspace?.();
      return;
    }
    if (compact) {
      onLogin?.();
      return;
    }
    onApply?.();
  }

  return (
    <header className="af-ld-topnav" role="banner">
      <div className="af-ld-topnav__inner">
        <a className="af-ld-brand" href="https://useprocess.xyz/">
          <ProcessAppIcon size={22} />
          <span>Process</span>
        </a>
        <button type="button" className="af-ld-topnav__cta" onClick={handleAuth}>
          {label}
        </button>
      </div>
    </header>
  );
}

function HeroBadge() {
  return (
    <p className="af-ld-hero-badge">
      <span className="af-ld-hero-badge__inner">
        {appCopy("Programme créateur", "Creator program")}
      </span>
    </p>
  );
}

function HeroCta({ onApply }) {
  return (
    <div className="af-ld-hero-cta-wrap">
      <button type="button" className="af-ld-hero-cta" onClick={onApply}>
        <ProcessAppIcon size={28} className="af-ld-hero-cta__icon" />
        <span className="af-ld-hero-cta__label">
          {appCopy("Devenir affilié", "Become an affiliate")}
        </span>
      </button>
    </div>
  );
}

const SIM_MIN = 0;
const SIM_MAX = 500;
const SIM_DEFAULT = 50;
const SIM_EUROS_PER = 25;
const SIM_VIEW_STOPS = [0, ...VIEW_BONUS_TIERS.map((tier) => tier.views)];
const SIM_VIEW_DEFAULT_INDEX = 2;

function formatSimInt(n) {
  return new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 }).format(n);
}

function SimSlider({
  labelId,
  label,
  min,
  max,
  step,
  value,
  onChange,
  bubble,
  startBound,
  endBound,
  ariaLabel,
  ariaValuetext,
}) {
  const pct = (value - min) / (max - min || 1);

  return (
    <div className="af-ld-sim__control">
      <p id={labelId} className="af-ld-sim__label">
        {label}
      </p>
      <div className="af-ld-sim__slider">
        <div className="af-ld-sim__rail">
          <div className="af-ld-sim__track" />
          <div className="af-ld-sim__fill" style={{ width: `${pct * 100}%` }} />
          <input
            type="range"
            min={min}
            max={max}
            step={step}
            value={value}
            onChange={(e) => onChange(Number(e.target.value))}
            className="af-ld-sim__input"
            aria-valuemin={min}
            aria-valuemax={max}
            aria-valuenow={value}
            aria-valuetext={ariaValuetext}
            aria-labelledby={labelId}
            aria-label={ariaLabel}
          />
          <div className="af-ld-sim__thumb" style={{ left: `${pct * 100}%` }}>
            <span className="af-ld-sim__bubble">{bubble}</span>
          </div>
        </div>
        <div className="af-ld-sim__bounds" aria-hidden>
          <span>{startBound}</span>
          <span>{endBound}</span>
        </div>
      </div>
    </div>
  );
}

function RevenueSimulator() {
  const affiliatesId = useId();
  const viewsId = useId();
  const [count, setCount] = useState(SIM_DEFAULT);
  const [viewIndex, setViewIndex] = useState(SIM_VIEW_DEFAULT_INDEX);
  const views = SIM_VIEW_STOPS[viewIndex] ?? 0;
  const commission = count * SIM_EUROS_PER;
  const bonus = viewBonusUsdForViews(views);
  const viewsLabel = views === 0 ? "0" : formatViewCount(views);

  return (
    <div
      className="af-ld-sim"
      aria-label={appCopy("Simulateur de revenu", "Revenue simulator")}
    >
      <p className="af-ld-sim__title">{appCopy("Simulateur de revenu", "Revenue simulator")}</p>
      <p className="af-ld-sim__lead">
        {appCopy(
          `${COMMISSION_PERCENT} % à vie + primes jusqu'à $${VIEW_BONUS_MAX_PER_VIDEO_USD} / vidéo`,
          `${COMMISSION_PERCENT}% for life + bonuses up to $${VIEW_BONUS_MAX_PER_VIDEO_USD} / video`
        )}
      </p>

      <SimSlider
        labelId={affiliatesId}
        label={appCopy("Affiliés", "Affiliates")}
        min={SIM_MIN}
        max={SIM_MAX}
        step={1}
        value={count}
        onChange={setCount}
        bubble={count}
        startBound={SIM_MIN}
        endBound={SIM_MAX}
        ariaLabel={appCopy("Nombre d'affiliés", "Number of affiliates")}
      />

      <SimSlider
        labelId={viewsId}
        label={appCopy("Vues par vidéo", "Views per video")}
        min={0}
        max={SIM_VIEW_STOPS.length - 1}
        step={1}
        value={viewIndex}
        onChange={setViewIndex}
        bubble={viewsLabel}
        startBound="0"
        endBound={formatViewCount(SIM_VIEW_STOPS[SIM_VIEW_STOPS.length - 1])}
        ariaLabel={appCopy("Vues par vidéo", "Views per video")}
        ariaValuetext={`${viewsLabel} ${appCopy("vues", "views")}`}
      />

      <ul className="af-ld-sim__tiers">
        {VIEW_BONUS_TIERS.map((tier, index) => {
          const reached = views >= tier.views;
          const current = views === tier.views;
          return (
            <li key={tier.views}>
              <button
                type="button"
                className={`af-ld-sim__tier${reached ? " is-on" : ""}${current ? " is-current" : ""}`}
                onClick={() => setViewIndex(index + 1)}
              >
                +${tier.amountUsd}
                <span> · {formatViewCount(tier.views)}</span>
              </button>
            </li>
          );
        })}
      </ul>

      <div className="af-ld-sim__results">
        <p className="af-ld-sim__payout">
          <span className="af-ld-sim__kicker">{appCopy("Commission", "Commission")}</span>
          <strong>
            {formatSimInt(commission)}€
            <span className="af-ld-sim__period">{appCopy("/mois", "/mo")}</span>
          </strong>
          <span className="af-ld-sim__hint">
            {count === 1
              ? appCopy("1 affilié", "1 affiliate")
              : appCopy(`${count} affiliés`, `${count} affiliates`)}
          </span>
        </p>
        <p className="af-ld-sim__payout af-ld-sim__payout--bonus">
          <span className="af-ld-sim__kicker">{appCopy("Primes", "Bonuses")}</span>
          <strong>
            +${bonus}
            <span className="af-ld-sim__period">{appCopy("/vidéo", "/video")}</span>
          </strong>
          <span className="af-ld-sim__hint">
            {views === 0
              ? appCopy("Aucun palier atteint", "No tier reached")
              : appCopy(`${viewsLabel} vues`, `${viewsLabel} views`)}
          </span>
        </p>
      </div>
    </div>
  );
}

function StepBadge({ n }) {
  return (
    <div className="af-ld-step__badge">
      <span>{n}</span>
      {appCopy(`ÉTAPE ${n}`, `STEP ${n}`)}
    </div>
  );
}

function StepsSection() {
  return (
    <section id="comment" className="af-ld-how" aria-labelledby="af-ld-how-heading">
      <header className="af-ld-how__header">
        <BracketKicker>{appCopy("COMMENT ÇA MARCHE", "HOW IT WORKS")}</BracketKicker>
        <h2 id="af-ld-how-heading">{appCopy("Devenez affilié en 3 étapes", "Become an affiliate in 3 steps")}</h2>
        <p>
          {appCopy(
            `Configuré en moins de 2 minutes. Partagez votre lien. Gagnez ${COMMISSION_PERCENT}% sur chaque abonnement généré, chaque mois, pour toujours.`,
            `Set up in under 2 minutes. Share your link. Earn ${COMMISSION_PERCENT}% on every subscription you generate, every month, forever.`
          )}
        </p>
      </header>

      <div className="af-ld-how__grid">
        <article className="af-ld-step">
          <StepBadge n={1} />
          <div className="af-ld-step__visual" aria-hidden>
            <p className="af-ld-step__link-label">{appCopy("Your referral link", "Your referral link")}</p>
            <div className="af-ld-step__link">
              <span>https://useprocess.xyz/join/</span>
              <em>ZKKUN</em>
            </div>
          </div>
          <div className="af-ld-step__copy">
            <IconPersonPlus />
            <div>
              <h3>{appCopy("Créez votre compte affilié", "Create your affiliate account")}</h3>
              <p>
                {appCopy(
                  "Moins de 2 minutes. Vous recevez instantanément un lien personnalisé et un code de tracking.",
                  "Under 2 minutes. You instantly get a personal link and a tracking code."
                )}
              </p>
            </div>
          </div>
        </article>

        <article className="af-ld-step">
          <StepBadge n={2} />
          <div className="af-ld-step__visual" aria-hidden>
            <div className="af-ld-share">
              <ProcessAppIcon size={44} className="af-ld-share__core" />
              <span className="af-ld-share__line" />
              <img
                className="af-ld-share__tiktok"
                src="/assets/logos/tiktok.png"
                alt=""
                width={48}
                height={48}
              />
            </div>
          </div>
          <div className="af-ld-step__copy">
            <IconBubble />
            <div>
              <h3>{appCopy("Automatisez vos slideshow", "Automate your slideshows")}</h3>
              <p>
                {appCopy(
                  "Partagez votre lien affilié sur TikTok. Vos slideshow tournent, vos commissions aussi.",
                  "Share your affiliate link on TikTok. Your slideshows run, your commissions too."
                )}
              </p>
            </div>
          </div>
        </article>

        <article className="af-ld-step">
          <StepBadge n={3} />
          <div className="af-ld-step__visual" aria-hidden>
            <div className="af-ld-payout">
              <div>
                <span>{appCopy("Pending", "Pending")}</span>
                <strong>$56</strong>
              </div>
              <div>
                <span>{appCopy("Available", "Available")}</span>
                <strong>$1.674</strong>
              </div>
              <em>{appCopy("Payout", "Payout")}</em>
            </div>
          </div>
          <div className="af-ld-step__copy">
            <IconCoinMark />
            <div>
              <h3>{appCopy("Gagnez chaque mois", "Earn every month")}</h3>
              <p>
                {appCopy(
                  `Recevez ${COMMISSION_PERCENT}% de chaque abonnement généré, tant que votre filleul reste actif.`,
                  `Receive ${COMMISSION_PERCENT}% of every subscription generated, as long as your referral stays active.`
                )}
              </p>
            </div>
          </div>
        </article>
      </div>
    </section>
  );
}

function PrimesSection() {
  return (
    <section id="primes" className="af-ld-primes" aria-labelledby="af-ld-primes-heading">
      <header className="af-ld-primes__intro">
        <BracketKicker>{appCopy("PRIMES", "BONUSES")}</BracketKicker>
        <h2 id="af-ld-primes-heading">
          {appCopy(
            `Jusqu'à $${VIEW_BONUS_MAX_PER_VIDEO_USD} par vidéo`,
            `Up to $${VIEW_BONUS_MAX_PER_VIDEO_USD} per video`
          )}
        </h2>
        <p>
          {appCopy(
            `En plus des ${COMMISSION_PERCENT} % à vie. Les paliers se cumulent sur une même vidéo, jusqu'au plafond.`,
            `On top of ${COMMISSION_PERCENT}% for life. Tiers stack on the same video, up to the cap.`
          )}
        </p>
      </header>
      <div className="af-ld-primes__board">
        <ViewBonusBoard variant="light" />
        <ViewBonusNote />
      </div>
    </section>
  );
}

function FaqSection() {
  const baseId = useId();
  const [openId, setOpenId] = useState(null);
  const items = [
    {
      id: "payout",
      q: appCopy("A quelle fréquence les paiements sont effectués ?", "How often are payouts made?"),
      a: appCopy(
        `Les virements passent par Stripe Connect, vers ton compte bancaire. Les commissions sont retenues ${HOLD_DAYS} jours, puis disponibles au payout. Compte 3 à 5 jours pour que les fonds apparaissent sur ton compte.`,
        `Payouts go through Stripe Connect to your bank account. Commissions are held for ${HOLD_DAYS} days, then available to withdraw. Allow 3 to 5 days for funds to appear.`
      ),
    },
    {
      id: "track",
      q: appCopy("Comment suivre les inscriptions que j'ai référées ?", "How do I track the signups I referred?"),
      a: appCopy(
        "Connecte-toi à ton dashboard affilié. Si ton lien unique ou ton code a bien été utilisé, tes inscriptions, ventes et gains s'affichent en temps réel.",
        "Sign in to your affiliate dashboard. If your unique link or code was used, your signups, sales, and earnings show up in real time."
      ),
    },
    {
      id: "code",
      q: appCopy(
        "Le code promo tracke-t-il les affiliés même s'ils n'utilisent pas le lien affilié ?",
        "Does the promo code track affiliates even if they don't use the affiliate link?"
      ),
      a: appCopy(
        "Oui. Si quelqu'un s'abonne avec ton code créateur sans passer par ton lien, la vente est quand même créditée sur ton compte — comme s'il avait cliqué le lien.",
        "Yes. If someone subscribes with your creator code without using your link, the sale is still credited to your account — as if they had clicked the link."
      ),
    },
    {
      id: "ads",
      q: appCopy("Est-ce que je peux faire de la pub avec mon lien affilié ?", "Can I run ads with my affiliate link?"),
      a: appCopy(
        "La publicité payante n'est pas autorisée. Si tu utilises de la pub payante, tes commissions ne seront pas versées. On peut te demander une preuve des méthodes utilisées en cas de doute.",
        "Paid advertising is not allowed. If you run paid ads, commissions will not be paid. We may ask for proof of the methods used if anything looks off."
      ),
    },
    {
      id: "cookies",
      q: appCopy("Comment fonctionne le tracking des liens ?", "How does link tracking work?"),
      a: appCopy(
        "Ton lien et ton code trackent tes filleuls pendant 30 jours. Chaque clic ou usage du code réinitialise cette fenêtre. Même s'ils partent et reviennent plus tard, tu gardes le crédit.",
        "Your link and code track referrals for 30 days. Each click or code use resets that window. Even if they leave and come back later, you keep the credit."
      ),
    },
  ];

  return (
    <section id="faq" className="af-ld-faq" aria-labelledby="af-ld-faq-heading">
      <div className="af-ld-faq__intro">
        <BracketKicker>FAQ</BracketKicker>
        <h2 id="af-ld-faq-heading">{appCopy("Les questions fréquentes", "Frequently asked questions")}</h2>
        <p>
          {appCopy("Vous ne trouvez pas la réponse à votre question ? Contactez-nous en ", "Can't find the answer? Contact us by ")}
          <a href={`mailto:${SUPPORT_EMAIL}`}>{appCopy("cliquant ici.", "clicking here.")}</a>
        </p>
      </div>

      <div className="af-ld-faq__list">
        {items.map((item) => {
          const open = openId === item.id;
          const buttonId = `${baseId}-${item.id}-btn`;
          const panelId = `${baseId}-${item.id}-panel`;
          return (
            <article key={item.id} className={open ? "is-open" : ""}>
              <h3>
                <button
                  type="button"
                  id={buttonId}
                  aria-expanded={open}
                  aria-controls={panelId}
                  onClick={() => setOpenId(open ? null : item.id)}
                >
                  <span>{item.q}</span>
                  <IconChevronDown />
                </button>
              </h3>
              <div id={panelId} role="region" aria-labelledby={buttonId} hidden={!open}>
                <p>{item.a}</p>
              </div>
            </article>
          );
        })}
      </div>
    </section>
  );
}

function ClosingSection({ onApply }) {
  return (
    <section id="rejoindre" className="af-ld-ready" aria-labelledby="af-ld-ready-heading">
      <h2 id="af-ld-ready-heading">
        {appCopy("Prêt à prendre 50-300$ de commission par jour ?", "Ready to take $50–300 in commission per day?")}
      </h2>
      <button type="button" className="af-ld-ready__cta" onClick={onApply}>
        {appCopy("Devenir affilié", "Become an affiliate")}
        <span aria-hidden>›</span>
      </button>
    </section>
  );
}

function LandingFooter() {
  const nav = [
    { href: "#programme", label: appCopy("Programme", "Program") },
    { href: "#comment", label: appCopy("Comment ça marche", "How it works") },
    { href: "#primes", label: appCopy("Primes", "Bonuses") },
    { href: "#faq", label: "FAQ" },
    { href: "#rejoindre", label: appCopy("Rejoindre", "Join") },
  ];
  const legal = [
    { href: TERMS_URL, label: appCopy("Conditions générales", "Terms of Service") },
    { href: PRIVACY_URL, label: appCopy("Politique de confidentialité", "Privacy Policy") },
    { href: "/support", label: "Support" },
  ];

  return (
    <footer className="af-ld-footer" aria-label={appCopy("Pied de page", "Footer")}>
      <div className="af-ld-footer__inner">
        <div className="af-ld-footer__grid">
          <div>
            <a className="af-ld-brand" href="https://useprocess.xyz/">
              <ProcessAppIcon size={28} />
              <span>Process</span>
            </a>
            <div className="af-ld-footer__socials">
              <a href={X_URL} target="_blank" rel="noopener noreferrer" aria-label="X">
                <IconX />
              </a>
            </div>
          </div>
          <section>
            <h2>{appCopy("Navigation", "Navigation")}</h2>
            <ul>
              {nav.map((item) => (
                <li key={item.href}>
                  <a href={item.href}>{item.label}</a>
                </li>
              ))}
            </ul>
          </section>
          <section>
            <h2>{appCopy("Informations", "Information")}</h2>
            <ul>
              {legal.map((item) => (
                <li key={item.href}>
                  <a href={item.href}>{item.label}</a>
                </li>
              ))}
            </ul>
          </section>
        </div>
        <p className="af-ld-footer__copy">© {YEAR} Process. {appCopy("Tous droits réservés.", "All rights reserved.")}</p>
      </div>
    </footer>
  );
}

export function AffiliateLanding({ onApply, onLogin, loggedIn = false, onWorkspace }) {
  useEffect(() => {
    const id = String(window.location.hash || "").replace("#", "").split("?")[0];
    if (!id || id.startsWith("/")) return;
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ block: "start" });
  }, []);

  return (
    <div className="af-ld">
      <AffiliateTopNav onApply={onApply} onLogin={onLogin} loggedIn={loggedIn} onWorkspace={onWorkspace} />

      <main>
        <section id="programme" className="af-ld-hero" aria-labelledby="af-ld-hero-title">
          <HeroBadge />
          <h1 id="af-ld-hero-title" className="af-ld-hero-title">
            {appCopy(
              `Gagnez ${COMMISSION_PERCENT}% à vie sur chaque abonnement généré`,
              `Earn ${COMMISSION_PERCENT}% for life on every subscription you generate`
            )}
          </h1>
          <p className="af-ld-hero-lead">
            {appCopy(
              "Un lien et un code de réduction. Sans limites. Revenus mensuels automatisés.",
              "A link and a discount code. No limits. Automated monthly income."
            )}
          </p>
          <HeroCta onApply={onApply} />
          <RevenueSimulator />
        </section>

        <div className="af-ld-sheet">
          <StepsSection />
          <PrimesSection />
          <FaqSection />
        </div>

        <ClosingSection onApply={onApply} />
      </main>

      <LandingFooter />
    </div>
  );
}
