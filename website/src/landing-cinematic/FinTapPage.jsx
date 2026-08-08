import "./fintap-landing.css";
import { FinTapHeroScrollSection } from "./FinTapHeroScrollSection.jsx";

/** Landing Process : hero seul. */
export function FinTapPage() {
  return (
    <main className="fintap-landing" id="fintap-main" role="main">
      <FinTapHeroScrollSection />
    </main>
  );
}
