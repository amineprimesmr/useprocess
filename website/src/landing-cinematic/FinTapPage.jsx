import "./fintap-landing.css";
import { FinTapHeroScrollSection } from "./FinTapHeroScrollSection.jsx";
import { ProcessFinalCtaSection } from "./ProcessFinalCtaSection.jsx";

/** Landing Process : hero + CTA. */
export function FinTapPage() {
  return (
    <main className="fintap-landing" id="fintap-main" role="main">
      <FinTapHeroScrollSection />
      <ProcessFinalCtaSection />
    </main>
  );
}
