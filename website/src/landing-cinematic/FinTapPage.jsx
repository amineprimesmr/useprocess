import "./fintap-landing.css";
import { FinTapHeroScrollSection } from "./FinTapHeroScrollSection.jsx";
import { FinTapStepsScrollSection } from "./FinTapStepsScrollSection.jsx";
import { ProcessFinalCtaSection } from "./ProcessFinalCtaSection.jsx";

/** Landing Process : hero, étapes, CTA. */
export function FinTapPage() {
  return (
    <main className="fintap-landing" id="fintap-main" role="main">
      <FinTapHeroScrollSection />
      <FinTapStepsScrollSection />
      <ProcessFinalCtaSection />
    </main>
  );
}
