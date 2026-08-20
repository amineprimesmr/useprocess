import { ScrollReveal } from "./ScrollReveal.jsx";
import { StoreDownloadButtons } from "./StoreDownloadButtons.jsx";
import { appCopy } from "../features/app-copy.js";
import "./process-final-cta.css";

/** CTA final — bouton App Store. */
export function ProcessFinalCtaSection() {
  return (
    <section className="process-final-cta" id="telecharger" aria-labelledby="process-final-cta-heading">
      <div className="process-final-cta__inner">
        <ScrollReveal>
          <h2 id="process-final-cta-heading" className="process-final-cta__title">
            {appCopy("Prêt à dégonfler ton visage ?", "Ready to debloat your face?")}
          </h2>
          <p className="process-final-cta__lead">
            {appCopy(
              "Scan visage, protocole debloat et coach IA — disponible sur iOS.",
              "Face scan, debloat protocol and AI coach — available on iOS."
            )}
          </p>
        </ScrollReveal>
        <ScrollReveal delay={0.08}>
          <StoreDownloadButtons />
        </ScrollReveal>
      </div>
    </section>
  );
}
