const BRAND_ICON = "/assets/icone.png?v=20260808";

/** Logo Process — affiché en haut du hero cinéma sur mobile (icône seule). */
export function FinTapHeroMobileLogo() {
  return (
    <a href="/" className="fintap-hero-iphone__brand" aria-label="Process — Accueil">
      <img
        className="fintap-hero-iphone__brand-icon"
        src={BRAND_ICON}
        alt="Process"
        width={40}
        height={40}
        decoding="async"
        draggable={false}
      />
    </a>
  );
}
