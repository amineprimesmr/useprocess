import { useEffect, useId, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconChevronDown, IconX, ProcessAppIcon } from "./AffiliateIcons.jsx";
import { AFFILIATE_X_HANDLE, COMMISSION_PERCENT, HOLD_DAYS, SUPPORT_EMAIL } from "./affiliate-utils.js";
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

function BrandMark({ name }) {
  return <span className={`af-ld-brandmark af-ld-brandmark--${name}`} aria-hidden />;
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
      <span className="af-ld-hero-badge__dot" aria-hidden />
      {appCopy(
        `Programme créateur · ${COMMISSION_PERCENT} % à vie + primes`,
        `Creator program · ${COMMISSION_PERCENT}% lifetime + bonuses`
      )}
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

function RevenueSimulator() {
  const sliderId = useId();
  const [count, setCount] = useState(SIM_DEFAULT);
  const span = SIM_MAX - SIM_MIN || 1;
  const pct = (count - SIM_MIN) / span;
  const payout = count * SIM_EUROS_PER;

  return (
    <div className="af-ld-sim" aria-labelledby={sliderId}>
      <p id={sliderId} className="af-ld-sim__title">
        {appCopy("Simulateur de revenu", "Revenue simulator")}
      </p>
      <div className="af-ld-sim__slider">
        <div className="af-ld-sim__rail">
          <div className="af-ld-sim__track" />
          <div className="af-ld-sim__fill" style={{ width: `${pct * 100}%` }} />
          <input
            type="range"
            min={SIM_MIN}
            max={SIM_MAX}
            step={1}
            value={count}
            onChange={(e) => setCount(Number(e.target.value))}
            className="af-ld-sim__input"
            aria-valuemin={SIM_MIN}
            aria-valuemax={SIM_MAX}
            aria-valuenow={count}
            aria-label={appCopy("Nombre d'affiliés", "Number of affiliates")}
          />
          <div className="af-ld-sim__thumb" style={{ left: `${pct * 100}%` }}>
            <span className="af-ld-sim__bubble">{count}</span>
          </div>
        </div>
        <div className="af-ld-sim__bounds" aria-hidden>
          <span>{SIM_MIN}</span>
          <span>{SIM_MAX}</span>
        </div>
      </div>
      <div className="af-ld-sim__footer">
        <p className="af-ld-sim__payout">
          <span className="af-ld-sim__kicker">{appCopy("Versement", "Payout")}</span>
          <strong>{payout}€</strong>
          <span className="af-ld-sim__period">{appCopy("/mois", "/mo")}</span>
        </p>
        <span className="af-ld-sim__badge">
          {count === 1
            ? appCopy("1 affilié", "1 affiliate")
            : appCopy(`${count} affiliés`, `${count} affiliates`)}
        </span>
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
              <span className="af-ld-share__line af-ld-share__line--yt" />
              <span className="af-ld-share__line af-ld-share__line--ig" />
              <span className="af-ld-share__line af-ld-share__line--tt" />
              <span className="af-ld-share__line af-ld-share__line--x" />
              <BrandMark name="yt" />
              <BrandMark name="ig" />
              <BrandMark name="tt" />
              <BrandMark name="x" />
              <ProcessAppIcon size={44} className="af-ld-share__core" />
            </div>
          </div>
          <div className="af-ld-step__copy">
            <IconBubble />
            <div>
              <h3>{appCopy("Partagez votre lien affilié", "Share your affiliate link")}</h3>
              <p>
                {appCopy(
                  "Partagez votre lien affilié avec votre audience, vos followers, vos amis et vos clients.",
                  "Share your affiliate link with your audience, followers, friends, and customers."
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
          <FaqSection />
        </div>

        <ClosingSection onApply={onApply} />
      </main>

      <LandingFooter />
    </div>
  );
}
