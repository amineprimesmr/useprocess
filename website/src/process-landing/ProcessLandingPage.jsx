import { useState } from "react";
import "./process-landing.css";
import "./process-lang-switch.css";
import { useSiteLanguage } from "./useSiteLanguage.js";
import {
  APP_STORE_URL,
  HERO_PHONE_IMAGE,
  LANDING_MEDIA,
  PROCESS_APP_ICON,
  navLinks,
  heroCopy,
  statsCopy,
  benefitsCopy,
  systemCopy,
  potentialCopy,
  testimonialsCopy,
  faqCopy,
  finalCtaCopy,
  footerCopy,
  languageSwitchCopy,
  chromeAriaCopy,
} from "./process-landing-data.js";

function ProcessAppIcon({ size = 32, className = "" }) {
  const aria = chromeAriaCopy();
  return (
    <img
      src={PROCESS_APP_ICON}
      alt={aria.processIcon}
      width={size}
      height={size}
      className={className}
      decoding="async"
    />
  );
}

function CommunityAvatars({ sources, size = 28, className = "" }) {
  return (
    <span className={`fk-community-avatars ${className}`.trim()} aria-hidden="true">
      {sources.map((src) => (
        <img key={src} src={src} alt="" width={size} height={size} />
      ))}
    </span>
  );
}

function ChevronDown() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="none" aria-hidden="true">
      <path d="M4 6l4 4 4-4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function LanguageSwitch({ className = "" }) {
  const { lang, setLanguage } = useSiteLanguage();
  const copy = languageSwitchCopy();

  return (
    <div className={`fk-lang-switch ${className}`.trim()} role="group" aria-label={copy.aria}>
      <button
        type="button"
        className={lang === "fr" ? "is-active" : ""}
        aria-pressed={lang === "fr"}
        onClick={() => setLanguage("fr")}
      >
        {copy.fr}
      </button>
      <button
        type="button"
        className={lang === "en" ? "is-active" : ""}
        aria-pressed={lang === "en"}
        onClick={() => setLanguage("en")}
      >
        {copy.en}
      </button>
    </div>
  );
}

function Nav() {
  const [open, setOpen] = useState(false);
  const links = navLinks();
  const hero = heroCopy();
  const aria = chromeAriaCopy();

  return (
    <header className="fk-nav">
      <div className="fk-nav-inner">
        <a href="/" className="fk-logo">
          <ProcessAppIcon size={32} />
          Process
        </a>
        <button
          type="button"
          className="fk-nav-toggle"
          aria-label={aria.menu}
          aria-expanded={open}
          onClick={() => setOpen((v) => !v)}
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
            <path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          </svg>
        </button>
        <nav className={`fk-nav-links${open ? " is-open" : ""}`} aria-label={aria.mainNav}>
          {links.map((link) => (
            <a key={link.id} href={`#${link.id}`} onClick={() => setOpen(false)}>
              {link.label}
            </a>
          ))}
          <LanguageSwitch className="fk-lang-switch--mobile" />
        </nav>
        <div className="fk-nav-actions">
          <LanguageSwitch />
          <a className="fk-btn fk-btn--nav" href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
            {hero.cta}
          </a>
        </div>
      </div>
    </header>
  );
}

function Hero() {
  const hero = heroCopy();

  return (
    <section className="fk-hero">
      <div className="fk-container fk-container--hero">
        <div className="fk-trust-pill">
          <CommunityAvatars sources={hero.trustAvatars} size={28} />
          {hero.trustBadge}
        </div>
        <h1>{hero.title}</h1>
        <p className="fk-hero-sub fk-hero-sub--desktop">{hero.subtitle}</p>
        <p className="fk-hero-sub fk-hero-sub--mobile">{hero.subtitleMobile}</p>
        <div className="fk-hero-cta-row">
          <a className="fk-btn fk-btn--hero" href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
            {hero.cta}
          </a>
        </div>
        <div className="fk-app-store-line">
          <ProcessAppIcon size={20} className="fk-icon-process" />
          {hero.appAvailable}
          <img
            className="fk-icon-store"
            src={`${LANDING_MEDIA}/icon-appstore.svg`}
            alt="App Store"
            width={28}
            height={28}
          />
        </div>
      </div>
      <div className="fk-hero-phones" aria-hidden="true">
        <img
          className="fk-hero-phone"
          src={HERO_PHONE_IMAGE}
          alt=""
          width={320}
          height={650}
        />
      </div>
      <p className="fk-trust-line">{hero.trustLine}</p>
    </section>
  );
}

function SectionBadge({ children }) {
  return (
    <div className="fk-section-badge">
      <ProcessAppIcon size={16} className="fk-section-badge-icon" />
      {children}
    </div>
  );
}

function Stats() {
  const stats = statsCopy();

  return (
    <section className="fk-stats" id="benefits">
      <div className="fk-container">
        <ProcessAppIcon size={108} className="fk-stats-logo" />
        <h2>{stats.title}</h2>
        <div className="fk-stats-grid">
          {stats.items.map((item) => (
            <div className="fk-stat" key={item.value}>
              <div className="fk-stat-value">{item.value}</div>
              <div className="fk-stat-label">{item.label}</div>
            </div>
          ))}
        </div>
        <SectionBadge>{stats.badge}</SectionBadge>
      </div>
    </section>
  );
}

function FeatureCard({ icon, title, body, darkIcon = true }) {
  return (
    <article className="fk-card">
      <div
        className={`fk-card-icon${darkIcon ? "" : " fk-card-icon--light"}`}
      >
        <img src={icon} alt="" />
      </div>
      <h3>{title}</h3>
      <p>{body}</p>
    </article>
  );
}

function Benefits() {
  const benefits = benefitsCopy();
  const [left, right] = [benefits.cards.slice(0, 2), benefits.cards.slice(2, 4)];

  return (
    <section className="fk-benefits">
      <div className="fk-container">
        <h2>{benefits.title}</h2>
        <p className="fk-benefits-sub">{benefits.subtitle}</p>
        <div className="fk-benefits-layout">
          <div className="fk-benefits-col">
            {left.map((card) => (
              <FeatureCard key={card.title} {...card} />
            ))}
          </div>
          <div className="fk-benefits-phone">
            <img src={`${LANDING_MEDIA}/phone-features.png`} alt="" width={320} height={640} />
          </div>
          <div className="fk-benefits-col">
            {right.map((card) => (
              <FeatureCard key={card.title} {...card} />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function System() {
  const system = systemCopy();

  return (
    <section className="fk-system" id="features">
      <div className="fk-container fk-system-inner">
        <div className="fk-system-phone">
          <img src={`${LANDING_MEDIA}/phone-scan.png`} alt="" width={420} height={840} />
        </div>
        <div>
          <h2>{system.title}</h2>
          <div className="fk-system-grid">
            {system.cards.map((card) => (
              <FeatureCard key={card.title} {...card} darkIcon={false} />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}

function Potential() {
  const potential = potentialCopy();
  const aria = chromeAriaCopy();

  return (
    <section className="fk-potential">
      <div className="fk-container fk-potential-inner">
        <div>
          <h2>{potential.title}</h2>
          <p className="fk-potential-sub">{potential.subtitle}</p>
          <ul className="fk-checklist">
            {potential.checklist.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
          <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
            <img
              className="fk-app-store-badge"
              src={`${LANDING_MEDIA}/app-store-badge.png`}
              alt={aria.appStoreBadge}
              height={48}
            />
          </a>
        </div>
        <div className="fk-potential-phone">
          <img src={`${LANDING_MEDIA}/phone-progress.png`} alt="" width={420} height={840} />
        </div>
      </div>
    </section>
  );
}

function Testimonials() {
  const testimonials = testimonialsCopy();

  return (
    <section className="fk-testimonials" id="testimonial">
      <div className="fk-container">
        <div className="fk-section-badge fk-section-badge--community">
          <CommunityAvatars sources={testimonials.badgeAvatars} size={24} />
          {testimonials.badge}
        </div>
        <h2>{testimonials.title}</h2>
        <p className="fk-testimonials-sub">{testimonials.subtitle}</p>
      </div>
      <div className="fk-testimonials-track">
        {testimonials.items.map((item) => (
          <article className="fk-testimonial" key={item.name}>
            <q>{item.quote}</q>
            <div className="fk-testimonial-author">
              <img src={item.avatar} alt="" width={40} height={40} />
              <span>{item.name}</span>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}

function FAQ() {
  const faq = faqCopy();
  const [openIndex, setOpenIndex] = useState(null);

  return (
    <section className="fk-faq" id="faq">
      <div className="fk-container">
        <SectionBadge>{faq.badge}</SectionBadge>
        <h2>{faq.title}</h2>
        <div className="fk-faq-list">
          {faq.items.map((item, index) => {
            const isOpen = openIndex === index;
            return (
              <div className={`fk-faq-item${isOpen ? " is-open" : ""}`} key={item.q}>
                <button
                  type="button"
                  className="fk-faq-q"
                  aria-expanded={isOpen}
                  onClick={() => setOpenIndex(isOpen ? null : index)}
                >
                  {item.q}
                  <ChevronDown />
                </button>
                <div className="fk-faq-a">
                  <p>{item.a}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

function FinalCta() {
  const cta = finalCtaCopy();
  const aria = chromeAriaCopy();

  return (
    <section className="fk-final-cta">
      <div className="fk-container">
        <h2>{cta.title}</h2>
        <p>{cta.subtitle}</p>
        <a href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
          <img
            className="fk-app-store-badge"
            src={`${LANDING_MEDIA}/app-store-badge.png`}
            alt={aria.appStoreBadge}
            height={48}
          />
        </a>
      </div>
    </section>
  );
}

function Footer() {
  const footer = footerCopy();
  const links = navLinks();
  const aria = chromeAriaCopy();

  return (
    <footer className="fk-footer">
      <div className="fk-container">
        <div className="fk-footer-top">
          <a href="/" className="fk-logo">
            <ProcessAppIcon size={32} />
            Process
          </a>
          <nav className="fk-footer-nav" aria-label={aria.footerNav}>
            {links.map((link) => (
              <a key={link.id} href={`#${link.id}`}>
                {link.label}
              </a>
            ))}
            <a className="fk-btn" href={APP_STORE_URL} target="_blank" rel="noopener noreferrer">
              {heroCopy().cta}
            </a>
          </nav>
          <p className="fk-footer-tagline">{footer.tagline}</p>
        </div>
        <div className="fk-footer-bottom">
          <a href={`mailto:${footer.email}`}>{footer.email}</a>
          <div className="fk-footer-legal">
            <a href={footer.privacyHref}>{footer.privacy}</a>
            <a href={footer.termsHref}>{footer.terms}</a>
          </div>
        </div>
      </div>
    </footer>
  );
}

export function ProcessLandingPage() {
  useSiteLanguage();

  return (
    <div className="fk-page">
      <Nav />
      <main>
        <Hero />
        <Stats />
        <Benefits />
        <System />
        <Potential />
        <Testimonials />
        <FAQ />
        <FinalCta />
      </main>
      <Footer />
    </div>
  );
}
