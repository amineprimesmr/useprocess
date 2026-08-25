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
        {` ${appCopy("max de primes vues", "max in view bonuses")}`}
      </p>
    </div>
  );
}

export function ViewBonusNote() {
  const oneMillionBonus = viewBonusUsdForViews(1_000_000);
  return (
    <p className="af-view-bonus__note">
      {appCopy(
        `Toutes les vidéos du compte comptent (ex. 1M vues = $${oneMillionBonus}). En plus des ${COMMISSION_PERCENT} % du net, versés via Stripe.`,
        `Every video on the account counts (e.g. 1M views = $${oneMillionBonus}). On top of ${COMMISSION_PERCENT}% of net, paid via Stripe.`
      )}
    </p>
  );
}

export { viewBonusEligibilityLabel };
