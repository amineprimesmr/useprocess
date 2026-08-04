import "./fintap-landing.css";
import { FinTapHeroScrollSection } from "./FinTapHeroScrollSection.jsx";
import { FinTapFeaturesGridSection } from "./FinTapFeaturesGridSection.jsx";
import { FinTapStepsScrollSection } from "./FinTapStepsScrollSection.jsx";
import { ProcessFinalCtaSection } from "./ProcessFinalCtaSection.jsx";

/** Landing Process : hero, features, étapes, CTA. */
export function FinTapPage() {
  return (
    <main className="fintap-landing" id="fintap-main" role="main">
      <FinTapHeroScrollSection />
      <FinTapFeaturesGridSection />
      <FinTapStepsScrollSection />
      <ProcessFinalCtaSection />
    </main>
  );
}
