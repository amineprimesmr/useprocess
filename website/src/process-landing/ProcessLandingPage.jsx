import { useEffect, useRef, useState } from "react";
import { motion, useReducedMotion } from "framer-motion";
import "./process-landing.css";
import "./process-landing-motion.css";
import { ScrollReveal } from "../landing-cinematic/ScrollReveal.jsx";
import { useSiteLanguage } from "./useSiteLanguage.js";
import { useSmoothAnchorScroll } from "./useLandingMotion.js";
import { appCopy } from "../features/app-copy.js";
import { StoreDownloadButtons } from "../landing-cinematic/StoreDownloadButtons.jsx";
import { BeforeAfterSlider } from "./BeforeAfterSlider.jsx";
import { StatAnimatedValue } from "./StatAnimatedValue.jsx";
import { StickyDownloadBar } from "./StickyDownloadBar.jsx";
import { LanguageSwitch } from "./LanguageSwitch.jsx";
import {
  APP_STORE_URL,
  HERO_PHONE_IMAGE,
  BENEFITS_PHONE_IMAGE,
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
  footerCopy,
  chromeAriaCopy,
} from "./process-landing-data.js";

const MOTION_EASE = [0.22, 1, 0.36, 1];

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

function Hero() {
  const hero = heroCopy();
  const reduce = useReducedMotion();
  const motionProps = (delay = 0) =>
    reduce
      ? {}
      : {
          initial: { opacity: 0, y: 28, filter: "blur(8px)" },
          animate: { opacity: 1, y: 0, filter: "blur(0px)" },
          transition: { duration: 0.75, ease: MOTION_EASE, delay },
        };

  return (
    <section className="fk-hero" id="fk-hero">
      <div className="fk-container fk-container--hero">
        <motion.div className="fk-trust-pill" {...motionProps(0.05)}>
          <CommunityAvatars sources={hero.trustAvatars} size={28} />
          {hero.trustBadge}
        </motion.div>
        <motion.h1 {...motionProps(0.12)}>{hero.title}</motion.h1>
        <motion.p className="fk-hero-sub fk-hero-sub--desktop" {...motionProps(0.2)}>
          {hero.subtitle}
        </motion.p>
        <motion.p className="fk-hero-sub fk-hero-sub--mobile" {...motionProps(0.2)}>
          {hero.subtitleMobile}
        </motion.p>
        <motion.div className="fk-hero-cta-row" {...motionProps(0.28)}>
          <StoreDownloadButtons />
        </motion.div>
      </div>
      <motion.div
        className="fk-hero-phones"
        aria-hidden="true"
        {...(reduce
          ? {}
          : {
              initial: { opacity: 0, y: 48, scale: 0.96 },
              animate: { opacity: 1, y: 0, scale: 1 },
              transition: { duration: 0.95, ease: MOTION_EASE, delay: 0.18 },
            })}
      >
        <img
          className="fk-hero-phone"
          src={HERO_PHONE_IMAGE}
          alt=""
          width={320}
          height={650}
        />
      </motion.div>
      <motion.p className="fk-trust-line" {...motionProps(0.34)}>
        {hero.trustLine}
      </motion.p>
    </section>
  );
}

function SectionBadge({ children, variant = "default" }) {
  if (variant === "3d") {
    return (
      <div className="fk-section-badge fk-section-badge--3d">
        <span className="fk-section-badge__pulse" aria-hidden="true" />
        {children}
      </div>
    );
  }

  return (
    <div className="fk-section-badge">
      <ProcessAppIcon size={16} className="fk-section-badge-icon" />
      {children}
    </div>
  );
}

function Stats() {
  const stats = statsCopy();
  const sectionRef = useRef(null);
  const [active, setActive] = useState(false);

  useEffect(() => {
    const section = sectionRef.current;
    if (!section) return undefined;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setActive(true);
          observer.disconnect();
        }
      },
      { threshold: 0.35, rootMargin: "0px 0px -8% 0px" }
    );

    observer.observe(section);
    return () => observer.disconnect();
  }, []);

  return (
    <section className="fk-stats" ref={sectionRef}>
      <div className="fk-container">
        <ScrollReveal variant="scale-up">
          <ProcessAppIcon size={108} className="fk-stats-logo" />
        </ScrollReveal>
        <ScrollReveal delay={0.06}>
          <h2>{stats.title}</h2>
        </ScrollReveal>
        <div className="fk-stats-grid">
          {stats.items.map((item, index) => (
            <ScrollReveal key={item.target} delay={index * 0.08} className="fk-stat">
              <StatAnimatedValue
                target={item.target}
                format={item.format}
                active={active}
                delay={index * 140}
              />
              <div className="fk-stat-label">{item.label}</div>
            </ScrollReveal>
          ))}
        </div>
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
    <section className="fk-benefits" id="benefits">
      <div className="fk-container">
        <ScrollReveal>
          <div className="fk-benefits-intro">
            <SectionBadge variant="3d">{benefits.badge}</SectionBadge>
            <h2>{benefits.title}</h2>
          </div>
        </ScrollReveal>
        <ScrollReveal delay={0.08}>
          <p className="fk-benefits-sub">{benefits.subtitle}</p>
        </ScrollReveal>
        <div className="fk-benefits-layout">
          <ScrollReveal className="fk-benefits-col" variant="slide-left" delay={0.05}>
            {left.map((card) => (
              <FeatureCard key={card.title} {...card} />
            ))}
          </ScrollReveal>
          <ScrollReveal variant="scale-up" delay={0.12}>
            <div className="fk-benefits-phone" aria-hidden="true">
              <img
                className="fk-benefits-phone-img"
                src={BENEFITS_PHONE_IMAGE}
                alt=""
                width={1260}
                height={2736}
              />
            </div>
          </ScrollReveal>
          <ScrollReveal className="fk-benefits-col" variant="slide-right" delay={0.05}>
            {right.map((card) => (
              <FeatureCard key={card.title} {...card} />
            ))}
          </ScrollReveal>
        </div>
      </div>
    </section>
  );
}

function SystemTestimonials() {
  const testimonials = testimonialsCopy();

  return (
    <div className="fk-system-testimonials" id="testimonial">
      <ScrollReveal>
        <h2>{testimonials.title}</h2>
      </ScrollReveal>
      <ScrollReveal delay={0.06}>
        <p className="fk-system-testimonials-sub">{testimonials.subtitle}</p>
      </ScrollReveal>
      <div className="fk-testimonials-track fk-testimonials-track--embedded">
        {testimonials.items.map((item, index) => (
          <ScrollReveal
            key={item.name}
            tag="article"
            className="fk-testimonial"
            delay={index * 0.08}
            variant="fade-up"
          >
            <TestimonialStars />
            <q>{item.quote}</q>
            <div className="fk-testimonial-author">
              <img src={item.avatar} alt="" width={40} height={40} />
              <span>{item.name}</span>
            </div>
          </ScrollReveal>
        ))}
      </div>
    </div>
  );
}

function System() {
  const system = systemCopy();

  return (
    <section className="fk-system" id="features">
      <div className="fk-container fk-system-inner">
        <ScrollReveal>
          <header className="fk-system-head">
            <div className="fk-system-intro">
              <SectionBadge variant="3d">{system.badge}</SectionBadge>
              <h2>{system.title}</h2>
            </div>
            <p className="fk-system-sub">{system.subtitle}</p>
          </header>
        </ScrollReveal>

        <ScrollReveal variant="scale-up" delay={0.1}>
          <div className="fk-system-transform" aria-label={system.title}>
            <BeforeAfterSlider
              pairs={system.pairs}
              beforeLabel={system.beforeLabel}
              afterLabel={system.afterLabel}
              seeMoreLabel={system.seeMore}
            />
          </div>
        </ScrollReveal>

        <SystemTestimonials />
      </div>
    </section>
  );
}

function Potential() {
  const potential = potentialCopy();

  return (
    <section className="fk-potential">
      <div className="fk-container fk-potential-inner">
        <ScrollReveal className="fk-potential-copy" variant="slide-left">
          <h2>{potential.title}</h2>
          <p className="fk-potential-sub">{potential.subtitle}</p>
          <ul className="fk-checklist fk-checklist--potential">
            {potential.checklist.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
          <StoreDownloadButtons className="fk-potential-download" />
        </ScrollReveal>
        <ScrollReveal variant="slide-right" delay={0.08}>
          <div className="fk-potential-phone" aria-hidden="true">
            <img src={`${LANDING_MEDIA}/phone-progress.png`} alt="" width={420} height={840} />
          </div>
        </ScrollReveal>
      </div>
    </section>
  );
}

function TestimonialStars() {
  const label = appCopy("5 étoiles sur 5", "5 out of 5 stars");

  return (
    <div className="fk-testimonial-stars" aria-label={label} role="img">
      {"⭐".repeat(5)}
    </div>
  );
}


function FAQ() {
  const faq = faqCopy();
  const [openIndex, setOpenIndex] = useState(null);

  return (
    <section className="fk-faq" id="faq">
      <div className="fk-container">
        <ScrollReveal>
          <div className="fk-faq-intro">
            <SectionBadge variant="3d">{faq.badge}</SectionBadge>
            <h2>{faq.title}</h2>
          </div>
        </ScrollReveal>
        <div className="fk-faq-list">
          {faq.items.map((item, index) => {
            const isOpen = openIndex === index;
            return (
              <ScrollReveal key={item.q} delay={index * 0.05} variant="fade-up">
                <div className={`fk-faq-item${isOpen ? " is-open" : ""}`}>
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
                    <div className="fk-faq-a-inner">
                      <p>{item.a}</p>
                    </div>
                  </div>
                </div>
              </ScrollReveal>
            );
          })}
        </div>
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
      <ScrollReveal variant="fade-in">
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
      </ScrollReveal>
    </footer>
  );
}

export function ProcessLandingPage() {
  useSiteLanguage();
  useSmoothAnchorScroll();

  return (
    <div className="fk-page">
      <LanguageSwitch />
      <main>
        <Hero />
        <Stats />
        <Benefits />
        <System />
        <FAQ />
        <Potential />
      </main>
      <Footer />
      <StickyDownloadBar />
    </div>
  );
}
