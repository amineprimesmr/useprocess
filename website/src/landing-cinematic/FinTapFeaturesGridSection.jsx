import { ScrollReveal } from "./ScrollReveal.jsx";
import { PROCESS_FEATURES } from "./process-features-data.js";
import { ProcessFeatureIcon } from "./ProcessFeatureIcon.jsx";
import "./fintap-features-grid.css";
import "./process-feature-cards.css";

/** Section fonctionnalités Process — cartes sombres texte + icônes. */
export function FinTapFeaturesGridSection() {
  return (
    <section
      className="fintap-features-grid"
      id="fonctionnalites"
      aria-labelledby="fintap-features-grid-heading"
    >
      <div className="fintap-section-inner fintap-features-grid__inner">
        <header className="fintap-features-grid__header">
          <ScrollReveal>
            <h2 id="fintap-features-grid-heading" className="fintap-steps-scroll__h2">
              Tout ce qu&apos;il faut pour dégonfler ton visage
            </h2>
          </ScrollReveal>
          <ScrollReveal delay={0.1}>
            <p className="fintap-steps-scroll__intro fintap-features-grid__intro">
              Scan IA, nutrition drainante et suivi Santé — un protocole complet pour des résultats visibles.
            </p>
          </ScrollReveal>
        </header>
      </div>

      <ScrollReveal delay={0.06}>
        <ul className="process-feature-cards" role="list">
          {PROCESS_FEATURES.map((feature) => (
            <li key={feature.id} className="process-feature-card" role="listitem">
              <span className="process-feature-card__icon" aria-hidden="true">
                <ProcessFeatureIcon name={feature.icon} />
              </span>
              <h3 className="process-feature-card__title">{feature.title}</h3>
              <p className="process-feature-card__desc">{feature.desc}</p>
            </li>
          ))}
        </ul>
      </ScrollReveal>

      <div className="fintap-section-inner fintap-features-grid__inner">
        <div className="fintap-features-grid__cta-wrap">
          <ScrollReveal delay={0.08}>
            <a href="/get" className="fintap-features-grid__cta">
              Télécharger Process
            </a>
          </ScrollReveal>
        </div>
      </div>
    </section>
  );
}
