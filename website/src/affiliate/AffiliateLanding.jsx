import { useCallback, useEffect, useId, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { ProcessAppIcon } from "./AffiliateIcons.jsx";
import { COMMISSION_PERCENT, HOLD_DAYS, SUPPORT_EMAIL } from "./affiliate-utils.js";
import { ViewBonusBoard, ViewBonusNote } from "./ViewBonusBoard.jsx";
import "./affiliate-landing.css";

const PRIVACY_URL = "https://useprocess.xyz/privacy";
const TERMS_URL = "https://useprocess.xyz/terms";
const YEAR = new Date().getFullYear();

const PHONES = [
  { src: "/assets/process-landing/phone-hero-app.png", alt: "Process" },
  { src: "/assets/process-landing/phone-features-scan.png", alt: "Scan" },
  { src: "/assets/iphone-custom-clean.png", alt: "Progress" },
];

const AVATARS = [
  "/assets/onboarding-community/gars1.png",
  "/assets/onboarding-community/leo.png",
  "/assets/onboarding-community/estebanprime.png",
  "/assets/onboarding-community/lucasprime.png",
  "/assets/onboarding-community/imranprime.png",
];

function StarRow() {
  return (
    <span className="af-ld-stars" aria-hidden>
      {Array.from({ length: 5 }, (_, i) => (
        <svg key={i} viewBox="0 0 20 20">
          <path d="M10 1.5 12.4 7l5.9.5-4.5 3.8 1.4 5.7L10 14.2 4.8 16.9l1.4-5.7L1.7 7.5 7.6 7 10 1.5Z" />
        </svg>
      ))}
    </span>
  );
}

function AvatarStack({ className = "" }) {
  return (
    <span className={`af-ld-avatars ${className}`.trim()} aria-hidden>
      {AVATARS.map((src, index) => (
        <span key={`${src}-${index}`} className="af-ld-avatar">
          <img src={src} alt="" width={36} height={36} loading="lazy" decoding="async" />
        </span>
      ))}
    </span>
  );
}

function CtaDot() {
  return <span className="af-ld-cta-dot" aria-hidden />;
}

export function AffiliateTopNav({
  onApply,
  onLogin,
  loggedIn = false,
  onWorkspace,
  compact = false,
}) {
  const menuId = useId();
  const [menuOpen, setMenuOpen] = useState(false);
  const closeMenu = useCallback(() => setMenuOpen(false), []);

  useEffect(() => {
    if (!menuOpen) return undefined;
    document.body.classList.add("af-ld-menu-open");
    const onKey = (event) => {
      if (event.key === "Escape") closeMenu();
    };
    window.addEventListener("keydown", onKey);
    return () => {
      document.body.classList.remove("af-ld-menu-open");
      window.removeEventListener("keydown", onKey);
    };
  }, [closeMenu, menuOpen]);

  const links = [
    { href: "#programme", label: appCopy("Programme", "Program") },
    { href: "#comment", label: appCopy("Comment ça marche", "How it works") },
    { href: "#primes", label: appCopy("Primes", "Bonuses") },
    { href: "#faq", label: "FAQ" },
  ];

  return (
    <>
      <header
        className={`af-ld-topnav${loggedIn ? " is-logged-in" : ""}${menuOpen ? " is-menu-open" : ""}`}
        role="banner"
      >
        <div className="af-ld-topnav__inner">
          <a className="af-ld-brand" href="https://useprocess.xyz/">
            <ProcessAppIcon size={24} />
            <span>Process</span>
          </a>

          <nav className="af-ld-topnav__nav" aria-label={appCopy("Navigation", "Navigation")}>
            {links.map((link) => (
              <a key={link.href} href={link.href} className="af-ld-topnav__link">
                {link.label}
              </a>
            ))}
          </nav>

          <div className="af-ld-topnav__actions">
            {loggedIn ? (
              <button type="button" className="af-ld-topnav__cta af-ld-topnav__cta--solid af-ld-topnav__cta--desk" onClick={onWorkspace}>
                {appCopy("Mon espace", "Dashboard")}
              </button>
            ) : (
              <>
                <button type="button" className="af-ld-topnav__signin" onClick={onLogin}>
                  {appCopy("Se connecter", "Log in")}
                </button>
                {compact ? null : (
                  <button type="button" className="af-ld-topnav__cta af-ld-topnav__cta--desk" onClick={onApply}>
                    {appCopy("Postuler", "Apply")}
                  </button>
                )}
              </>
            )}

            <button
              type="button"
              className={`af-ld-topnav__menu-btn${menuOpen ? " is-open" : ""}`}
              aria-expanded={menuOpen}
              aria-controls={menuId}
              aria-label={menuOpen ? appCopy("Fermer le menu", "Close menu") : appCopy("Ouvrir le menu", "Open menu")}
              onClick={() => setMenuOpen((open) => !open)}
            >
              <span aria-hidden />
              <span aria-hidden />
              <span aria-hidden />
            </button>
          </div>
        </div>
      </header>

      {menuOpen ? (
        <>
          <button type="button" className="af-ld-topnav__overlay" aria-label={appCopy("Fermer le menu", "Close menu")} onClick={closeMenu} />
          <nav id={menuId} className="af-ld-topnav__drawer" aria-label={appCopy("Menu mobile", "Mobile menu")}>
            <div className="af-ld-topnav__drawer-head">
              <ProcessAppIcon size={28} />
              <span>Process</span>
            </div>
            <div className="af-ld-topnav__drawer-links">
              {links.map((link) => (
                <a key={link.href} href={link.href} className="af-ld-topnav__drawer-link" onClick={closeMenu}>
                  {link.label}
                </a>
              ))}
            </div>
            <div className="af-ld-topnav__drawer-foot">
              {loggedIn ? (
                <button
                  type="button"
                  className="af-ld-topnav__drawer-cta"
                  onClick={() => {
                    closeMenu();
                    onWorkspace?.();
                  }}
                >
                  {appCopy("Mon espace", "Dashboard")}
                </button>
              ) : compact ? (
                <button
                  type="button"
                  className="af-ld-topnav__drawer-cta"
                  onClick={() => {
                    closeMenu();
                    onLogin?.();
                  }}
                >
                  {appCopy("Se connecter", "Log in")}
                </button>
              ) : (
                <>
                  <button
                    type="button"
                    className="af-ld-topnav__drawer-cta"
                    onClick={() => {
                      closeMenu();
                      onApply?.();
                    }}
                  >
                    {appCopy("Postuler", "Apply")}
                  </button>
                  <button
                    type="button"
                    className="af-ld-topnav__drawer-signout"
                    onClick={() => {
                      closeMenu();
                      onLogin?.();
                    }}
                  >
                    {appCopy("Se connecter", "Log in")}
                  </button>
                </>
              )}
            </div>
          </nav>
        </>
      ) : null}
    </>
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
          {appCopy("Postuler", "Apply")}
          <span className="af-ld-hero-cta__pricing">
            <span className="af-ld-hero-cta__price">{COMMISSION_PERCENT}%</span>
          </span>
        </span>
      </button>
    </div>
  );
}

function PhoneGallery() {
  return (
    <div className="af-ld-phones" aria-hidden>
      {PHONES.map((phone, index) => (
        <div key={phone.src} className={`af-ld-phone af-ld-phone--${index + 1}`}>
          <img
            src={phone.src}
            alt=""
            width={390}
            height={844}
            loading={index === 0 ? "eager" : "lazy"}
            decoding="async"
            fetchPriority={index === 0 ? "high" : "low"}
          />
        </div>
      ))}
    </div>
  );
}

function StepsSection({ onApply }) {
  const steps = [
    {
      id: "apply",
      title: appCopy("Postule en 2 minutes", "Apply in 2 minutes"),
      desc: appCopy(
        "Choisis ton code créateur, envoie ta candidature, et récupère ton lien unique.",
        "Pick your creator code, submit your application, and get your unique link."
      ),
    },
    {
      id: "share",
      title: appCopy("Partage ton lien", "Share your link"),
      desc: appCopy(
        "TikTok, Instagram, bio, stories — chaque abonnement via ton lien t'est attribué.",
        "TikTok, Instagram, bio, stories — every subscription through your link is attributed to you."
      ),
    },
    {
      id: "earn",
      title: appCopy(`Encaisse ${COMMISSION_PERCENT} % à vie`, `Earn ${COMMISSION_PERCENT}% for life`),
      desc: appCopy(
        `Tu touches ${COMMISSION_PERCENT} % à vie, plus des primes cash jusqu'à $300 par vidéo qui explose. Virements Stripe.`,
        `You earn ${COMMISSION_PERCENT}% for life, plus cash bonuses up to $300 per video that pops. Payouts via Stripe.`
      ),
    },
  ];

  return (
    <section id="comment" className="af-ld-steps" aria-labelledby="af-ld-steps-heading">
      <div className="af-ld-steps__inner">
        <header className="af-ld-steps__header">
          <span className="af-ld-pill-light">{appCopy("Processus", "Process")}</span>
          <h2 id="af-ld-steps-heading" className="af-ld-steps__title">
            <span>{appCopy("3 étapes simples", "3 simple steps")}</span>
            <span className="is-muted">{appCopy("pour commencer à gagner", "to start earning")}</span>
          </h2>
          <div className="af-ld-steps__intro">
            <p>
              <strong>
                {appCopy(
                  "Une méthode claire : postule, partage, encaisse.",
                  "A clear method: apply, share, get paid."
                )}
              </strong>{" "}
              <span>
                {appCopy(
                  "Pas d'outil à installer — ton lien Process suffit.",
                  "Nothing to install — your Process link is enough."
                )}
              </span>
            </p>
            <button type="button" className="af-ld-dark-cta" onClick={onApply}>
              <CtaDot />
              {appCopy("Postuler", "Apply")}
              <span aria-hidden>›</span>
            </button>
          </div>
        </header>

        <div className="af-ld-steps__grid" role="list">
          {steps.map((step, index) => (
            <article key={step.id} className="af-ld-step-card" role="listitem">
              <div className={`af-ld-step-visual af-ld-step-visual--${step.id}`} aria-hidden>
                {step.id === "apply" ? (
                  <div className="af-ld-step-icons">
                    <ProcessAppIcon size={72} />
                    <ProcessAppIcon size={56} />
                    <ProcessAppIcon size={48} />
                  </div>
                ) : null}
                {step.id === "share" ? (
                  <div className="af-ld-step-chips">
                    <span>useprocess.xyz/join/…</span>
                    <span>TikTok</span>
                    <span>Instagram</span>
                    <span>Bio</span>
                  </div>
                ) : null}
                {step.id === "earn" ? (
                  <div className="af-ld-step-earn">
                    <span className="af-ld-step-earn__amount">{COMMISSION_PERCENT}%</span>
                    <span className="af-ld-step-earn__pill">Stripe</span>
                  </div>
                ) : null}
              </div>
              <h3>
                {index + 1} - {step.title}
              </h3>
              <p>{step.desc}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}

function PrimesSection({ onApply }) {
  return (
    <section id="primes" className="af-ld-primes" aria-labelledby="af-ld-primes-heading">
      <div className="af-ld-primes__inner">
        <header className="af-ld-primes__header">
          <span className="af-ld-pill-light">{appCopy("Primes vues", "View bonuses")}</span>
          <h2 id="af-ld-primes-heading" className="af-ld-primes__title">
            <span>{appCopy("Jusqu'à $300", "Up to $300")}</span>
            <span className="is-muted">{appCopy("par vidéo qui explose", "per video that pops")}</span>
          </h2>
          <p className="af-ld-primes__lede">
            {appCopy(
              `En plus des ${COMMISSION_PERCENT} % à vie. Les paliers se cumulent sur une même vidéo, jusqu'au plafond.`,
              `On top of ${COMMISSION_PERCENT}% for life. Tiers stack on the same video, up to the cap.`
            )}
          </p>
        </header>

        <div className="af-ld-primes__board">
          <ViewBonusBoard variant="dark" />
          <ViewBonusNote />
        </div>

        <button type="button" className="af-ld-dark-cta af-ld-primes__cta" onClick={onApply}>
          <CtaDot />
          {appCopy("Postuler", "Apply")}
          <span aria-hidden>›</span>
        </button>
      </div>
    </section>
  );
}

function OfferSection({ onApply }) {
  const items = [
    appCopy(
      `${COMMISSION_PERCENT} % de commission à vie sur chaque abonnement`,
      `${COMMISSION_PERCENT}% lifetime commission on every subscription`
    ),
    appCopy(
      "Primes vues : +$20 @ 40k · +$30 @ 100k · +$100 @ 500k · +$150 @ 1M ($300 max / vidéo)",
      "View bonuses: +$20 @ 40k · +$30 @ 100k · +$100 @ 500k · +$150 @ 1M ($300 max / video)"
    ),
    appCopy("Lien unique useprocess.xyz/join/TONCODE", "Unique link useprocess.xyz/join/YOURCODE"),
    appCopy("Dashboard : clics, ventes, gains, virements", "Dashboard: clicks, sales, earnings, payouts"),
    appCopy("Virements bancaires via Stripe Connect", "Bank payouts via Stripe Connect"),
    appCopy(`Période de retenue ${HOLD_DAYS} jours`, `${HOLD_DAYS}-day holding period`),
    appCopy("Code créateur dans l'app Process", "Creator code inside the Process app"),
    appCopy("Support créateur par email et X", "Creator support via email and X"),
    appCopy("FR + EN — même programme", "FR + EN — same program"),
  ];

  return (
    <section id="offre" className="af-ld-offer" aria-labelledby="af-ld-offer-heading">
      <div className="af-ld-offer__inner">
        <h2 id="af-ld-offer-heading">
          <span>
            {appCopy("Rejoins Process", "Join Process")}
            <span className="af-ld-offer__mark">
              <ProcessAppIcon size={22} />
            </span>
          </span>
          <span>{appCopy("et encaisse", "and earn")}</span>
          <span>
            {COMMISSION_PERCENT}% {appCopy("à vie", "for life")}
          </span>
        </h2>

        <div className="af-ld-offer__proof">
          <AvatarStack />
          <span className="af-ld-offer__proof-meta">
            <StarRow />
            <span>{appCopy("Créateurs Process", "Process creators")}</span>
          </span>
        </div>

        <article className="af-ld-offer__card">
          <p className="af-ld-offer__kicker">{appCopy("Programme créateur — accès complet", "Creator program — full access")}</p>
          <p className="af-ld-offer__price-row">
            <span className="af-ld-offer__price">{COMMISSION_PERCENT}%</span>
            <span>{appCopy("par vente, à vie", "per sale, lifetime")}</span>
          </p>

          <div className="af-ld-offer__story">
            <p className="af-ld-offer__quote">
              {appCopy(
                `“${COMMISSION_PERCENT} % à vie sur chaque abonnement.”`,
                `“${COMMISSION_PERCENT}% for life on every subscription.”`
              )}
            </p>
            <div className="af-ld-offer__story-div" />
            <div className="af-ld-offer__story-id">
              <span className="af-ld-offer__story-avatar">
                <img src="/assets/icone.png" alt="" width={40} height={40} loading="lazy" decoding="async" />
              </span>
              <span>
                <strong>Process</strong>
                <em>@useprocess</em>
              </span>
            </div>
            <p>
              {appCopy(
                "Tu partages Process. Dès qu'un abonnement passe par ton lien, la commission t'est créditée — et elle continue à chaque renouvellement.",
                "You share Process. As soon as a subscription goes through your link, the commission is credited to you — and it continues on every renewal."
              )}
            </p>
          </div>

          <h3>{appCopy("Ce qui est inclus :", "What's included:")}</h3>
          <ul>
            {items.map((item) => (
              <li key={item}>
                <span aria-hidden>✓</span>
                {item}
              </li>
            ))}
          </ul>

          <button type="button" className="af-ld-offer__cta" onClick={onApply}>
            <CtaDot />
            {appCopy("Rejoindre le programme", "Join the program")}
            <span aria-hidden>›</span>
          </button>
        </article>

        <a className="af-ld-offer__more" href="#faq">
          {appCopy("En savoir plus", "Learn more")}
        </a>
      </div>
    </section>
  );
}

function FaqSection() {
  const baseId = useId();
  const [openId, setOpenId] = useState(null);
  const items = [
    {
      id: "what",
      q: appCopy("Le programme créateur Process, c'est quoi ?", "What is the Process creator program?"),
      a: appCopy(
        `Tu partages Process avec ton audience. Pour chaque abonnement généré via ton lien, tu touches ${COMMISSION_PERCENT} % — à vie, y compris les renouvellements. En plus, des primes cash jusqu'à $300 par vidéo.`,
        `You share Process with your audience. For every subscription generated through your link, you earn ${COMMISSION_PERCENT}% — for life, including renewals. Plus cash bonuses up to $300 per video.`
      ),
    },
    {
      id: "join",
      q: appCopy("Comment postuler ?", "How do I apply?"),
      a: appCopy(
        "Clique sur Postuler, crée ou connecte ton compte, choisis un code créateur, puis envoie ton @ TikTok ou Instagram pour accélérer la validation.",
        "Tap Apply, create or sign in to your account, pick a creator code, then send your TikTok or Instagram @ to speed up approval."
      ),
    },
    {
      id: "primes",
      q: appCopy("Comment marchent les primes vues ?", "How do view bonuses work?"),
      a: appCopy(
        "En plus des 40 % à vie : +$20 à 40k vues, +$30 à 100k, +$100 à 500k, +$150 à 1M — cumulés sur la même vidéo, plafonnés à $300. Pour être éligible : 500k+ vues sur 28 jours et 5+ vidéos Process. On calcule sur tes stats TikTok, puis on verse via Stripe.",
        "On top of 40% for life: +$20 at 40k views, +$30 at 100k, +$100 at 500k, +$150 at 1M — stacked on the same video, capped at $300. Eligibility: 500k+ views in 28 days and 5+ Process videos. We score from your TikTok stats, then pay via Stripe."
      ),
    },
    {
      id: "payout",
      q: appCopy("Comment je suis payé ?", "How do I get paid?"),
      a: appCopy(
        `Les virements passent par Stripe Connect, vers ton compte bancaire. Les commissions sont retenues ${HOLD_DAYS} jours. Les primes vues sont versées sur le même compte après review de tes stats.`,
        `Payouts go through Stripe Connect to your bank account. Commissions are held for ${HOLD_DAYS} days. View bonuses hit the same account after we review your stats.`
      ),
    },
    {
      id: "lifetime",
      q: appCopy("C'est vraiment à vie ?", "Is it really lifetime?"),
      a: appCopy(
        "Oui — tant que le client reste abonné via ton attribution, tu continues à percevoir ta part à chaque renouvellement.",
        "Yes — as long as the customer stays subscribed under your attribution, you keep earning on every renewal."
      ),
    },
    {
      id: "app",
      q: appCopy("Faut-il déjà avoir l'app ?", "Do I need the app already?"),
      a: appCopy(
        "Le code se crée aussi depuis l'app (Réglages → Programme créateurs). Tu peux aussi tout faire ici, sur cette page.",
        "You can also create your code in the app (Settings → Creator Program). You can complete everything here on this page too."
      ),
    },
    {
      id: "approval",
      q: appCopy("Combien de temps pour être validé ?", "How long does approval take?"),
      a: appCopy(
        "Dès que ton @ est envoyé, on review le compte. Ton lien peut déjà être réservé pendant la validation.",
        "Once your @ is sent, we review the account. Your link can already be reserved while we review."
      ),
    },
    {
      id: "stack",
      q: appCopy("Est-ce compatible avec mon lien de parrainage ?", "Does this work with my referral link?"),
      a: appCopy(
        "Le programme créateur (affiliation) et le parrainage ami sont deux mécaniques séparées. Ton code créateur sert aux commissions clipper.",
        "The creator program (affiliate) and friend referrals are separate. Your creator code is for clipper commissions."
      ),
    },
    {
      id: "results",
      q: appCopy("Vous garantissez un revenu ?", "Do you guarantee income?"),
      a: appCopy(
        "Non — ça dépend de ton audience et de ton exécution. On te donne le lien, le dashboard et les virements. Le reste, c'est ton contenu.",
        "No — it depends on your audience and execution. We give you the link, dashboard, and payouts. The rest is your content."
      ),
    },
  ];

  return (
    <section id="faq" className="af-ld-faq" aria-labelledby="af-ld-faq-heading">
      <div className="af-ld-faq__inner">
        <header className="af-ld-faq__header">
          <div>
            <span className="af-ld-pill-light">FAQ</span>
            <h2 id="af-ld-faq-heading">
              <span>{appCopy("Vos questions.", "Your questions.")}</span>
              <span className="is-muted">{appCopy("Nos réponses", "Our answers")}</span>
            </h2>
            <p>
              {appCopy("Si tu ne trouves pas la réponse,", "If you can't find the answer,")}{" "}
              <a href={`mailto:${SUPPORT_EMAIL}`}>{appCopy("contacte-nous ici.", "contact us here.")}</a>
            </p>
          </div>
          <a className="af-ld-dark-cta" href={`mailto:${SUPPORT_EMAIL}`}>
            <CtaDot />
            {appCopy("Contactez-nous", "Contact us")}
            <span aria-hidden>›</span>
          </a>
        </header>

        <div className="af-ld-faq__list" role="list">
          {items.map((item) => {
            const open = openId === item.id;
            const buttonId = `${baseId}-${item.id}-btn`;
            const panelId = `${baseId}-${item.id}-panel`;
            return (
              <article key={item.id} className={`af-ld-faq__item${open ? " is-open" : ""}`} role="listitem">
                <h3>
                  <button
                    type="button"
                    id={buttonId}
                    aria-expanded={open}
                    aria-controls={panelId}
                    onClick={() => setOpenId(open ? null : item.id)}
                  >
                    <span>{item.q}</span>
                    <span className="af-ld-faq__icon" aria-hidden />
                  </button>
                </h3>
                <div id={panelId} role="region" aria-labelledby={buttonId} hidden={!open}>
                  <p>{item.a}</p>
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function ClosingSection({ onApply }) {
  return (
    <section className="af-ld-closing" aria-labelledby="af-ld-closing-heading">
      <div className="af-ld-closing__stage">
        <article className="af-ld-closing__card">
          <h2 id="af-ld-closing-heading">
            {appCopy("40 % à vie. La nouvelle norme.", "40% for life. The new norm.")}
          </h2>
          <p>
            <strong>{appCopy("Partage Process", "Share Process")}</strong>{" "}
            {appCopy(
              "et évolue dans un programme où chaque abonnement compte — pour toi, à vie.",
              "and grow in a program where every subscription counts — for you, for life."
            )}
          </p>
          <div className="af-ld-closing__proof">
            <AvatarStack />
            <span className="af-ld-offer__proof-meta">
              <StarRow />
              <span>{appCopy("Créateurs Process", "Process creators")}</span>
            </span>
          </div>
          <button type="button" className="af-ld-closing__cta" onClick={onApply}>
            <CtaDot />
            {appCopy("Rejoindre le programme", "Join the program")}
            <span aria-hidden>›</span>
          </button>
        </article>
        <div className="af-ld-closing__brand" aria-hidden>
          <img src="/assets/icone.png" alt="" width={800} height={320} loading="lazy" decoding="async" />
        </div>
      </div>
    </section>
  );
}

function LandingFooter() {
  const nav = [
    { href: "#programme", label: appCopy("Programme", "Program") },
    { href: "#comment", label: appCopy("Comment ça marche", "How it works") },
    { href: "#primes", label: appCopy("Primes", "Bonuses") },
    { href: "#offre", label: appCopy("Rejoindre", "Join") },
    { href: "#faq", label: "FAQ" },
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
            <a className="af-ld-footer__email" href={`mailto:${SUPPORT_EMAIL}`}>
              {SUPPORT_EMAIL}
            </a>
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
        <p className="af-ld-footer__copy">© {YEAR} Process — All rights reserved</p>
      </div>
    </footer>
  );
}

export function AffiliateLanding({ onApply, onLogin, loggedIn = false, onWorkspace }) {
  useEffect(() => {
    const id = String(window.location.hash || "").replace("#", "");
    if (!id) return;
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
            {appCopy("Gagne 40 % à vie", "Earn 40% for life")}
            <br />
            <span className="af-ld-hero-title__line2">
              <span>{appCopy("en partageant", "by sharing")}</span>
              <ProcessAppIcon size={48} className="af-ld-hero-icon" />
              <span>Process</span>
            </span>
          </h1>
          <HeroCta onApply={onApply} />
        </section>

        <section className="af-ld-gallery" aria-labelledby="af-ld-gallery-title">
          <div className="af-ld-gallery-kicker">
            <span>{appCopy("L'app", "The app")}</span>
          </div>
          <h2 id="af-ld-gallery-title" className="af-ld-gallery-title">
            {appCopy("Ce que tes filleuls découvrent", "What your referrals discover")}
          </h2>
          <p className="af-ld-gallery-meta">
            <span className="af-ld-live-dot" aria-hidden />
            {appCopy("Scan · hydratation · protocole", "Scan · hydration · protocol")}
          </p>
          <PhoneGallery />
        </section>

        <StepsSection onApply={onApply} />
        <PrimesSection onApply={onApply} />
        <OfferSection onApply={onApply} />
        <FaqSection />
        <ClosingSection onApply={onApply} />
      </main>

      <LandingFooter />
    </div>
  );
}
