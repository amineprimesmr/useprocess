import { appCopy } from "../features/app-copy.js";
import {
  COMMISSION_PERCENT,
  VIEW_BONUS_MAX_PER_VIDEO_USD,
  VIEW_BONUS_TIERS,
  formatViewCount,
  viewBonusEligibilityLabel,
  viewBonusUsdForViews,
} from "./affiliate-utils.js";
import "./view-bonus.css";

export function ViewBonusBoard({
  variant = "light",
  showEligibility = true,
  compact = false,
}) {
  return (
    <div className={`af-view-bonus af-view-bonus--${variant}${compact ? " is-compact" : ""}`}>
      {showEligibility ? (
        <p className="af-view-bonus__elig">{viewBonusEligibilityLabel()}</p>
      ) : null}

      <ul className="af-view-bonus__list">
        {VIEW_BONUS_TIERS.map((tier) => (
          <li key={tier.views} className="af-view-bonus__row">
            <span className="af-view-bonus__amount">+${tier.amountUsd}</span>
            <span className="af-view-bonus__at" aria-hidden>
              @
            </span>
            <span className="af-view-bonus__views">
              {formatViewCount(tier.views)} {appCopy("vues", "views")}
            </span>
          </li>
        ))}
      </ul>

      <p className="af-view-bonus__cap">
        <strong>${VIEW_BONUS_MAX_PER_VIDEO_USD}</strong>
        {` ${appCopy("max par vidéo", "max per video")}`}
      </p>
    </div>
  );
}

export function ViewBonusNote() {
  const oneMillionBonus = viewBonusUsdForViews(1_000_000);
  return (
    <p className="af-view-bonus__note">
      {appCopy(
        `Les paliers se cumulent sur une même vidéo (ex. 1M vues = $${oneMillionBonus}). En plus des ${COMMISSION_PERCENT} % à vie, versés via Stripe.`,
        `Tiers stack on the same video (e.g. 1M views = $${oneMillionBonus}). On top of ${COMMISSION_PERCENT}% for life, paid via Stripe.`
      )}
    </p>
  );
}

export { viewBonusEligibilityLabel };
