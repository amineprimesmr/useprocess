import "./fintap-hero-media-badge.css";

/** Badge iOS — bas du panneau (mobile) ou barre hero (desktop). */
export function FinTapHeroMediaBadge({ placement = "bottom" }) {
  return (
    <div
      className={`fintap-hero-media-badge-anchor fintap-hero-media-badge-anchor--${placement}`}
      aria-hidden="false"
    >
      <div className="fintap-hero-media-badge" aria-label="Disponible sur iOS">
        <span className="fintap-hero-media-badge__kicker">Disponible sur</span>
        <span className="fintap-hero-media-badge__kicker" style={{ fontWeight: 700 }}>
          iOS
        </span>
      </div>
    </div>
  );
}
