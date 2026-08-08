import { ScrollReveal } from "./ScrollReveal.jsx";
import { StoreDownloadButtons } from "./StoreDownloadButtons.jsx";
import "./process-final-cta.css";

/** CTA final — boutons App Store + Play Store. */
export function ProcessFinalCtaSection() {
  return (
    <section className="process-final-cta" id="telecharger" aria-labelledby="process-final-cta-heading">
      <div className="process-final-cta__inner">
        <ScrollReveal>
          <h2 id="process-final-cta-heading" className="process-final-cta__title">
            Prêt à dégonfler ton visage ?
          </h2>
          <p className="process-final-cta__lead">
            Scan visage, protocole debloat et coach IA — essai gratuit 3 jours sur iOS.
          </p>
        </ScrollReveal>
        <ScrollReveal delay={0.08}>
          <StoreDownloadButtons />
        </ScrollReveal>
      </div>
    </section>
  );
}
