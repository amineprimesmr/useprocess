import { appCopy } from "../features/app-copy.js";
import {
  COMMISSION_PERCENT,
  VIEW_BONUS_FLAGSHIP_UNLOCK_EUR,
  VIEW_BONUS_UNLOCK_EUR,
} from "./affiliate-utils.js";

const ASSET = "/assets/affiliate/method/bonus";

const TIERS = [
  {
    views: "100k",
    reward: "50€",
    img: `${ASSET}/eur50.png`,
    alt: { fr: "Billet de 50 euros", en: "50 euro banknote" },
  },
  {
    views: "500k",
    reward: "100€",
    img: `${ASSET}/eur100.png`,
    alt: { fr: "Billets de 100 euros", en: "100 euro banknotes" },
  },
  {
    views: "1M",
    reward: "150€",
    extra: { fr: "+ coaching 1-to-1", en: "+ 1-to-1 coaching" },
    img: `${ASSET}/coach.png`,
    vis: "coach",
    alt: { fr: "Coaching 1-to-1", en: "1-to-1 coaching" },
  },
  {
    views: "10M",
    reward: "iPhone 17",
    img: `${ASSET}/iphone.png`,
    alt: { fr: "iPhone 17", en: "iPhone 17" },
  },
];

const CONDITIONS = [
  {
    fr: "Le post doit contenir un CTA subtil vers Process (en respectant la méthodologie).",
    en: "The post must include a subtle CTA to Process (while following the methodology).",
  },
  {
    fr: `Les primes cash se débloquent à ${VIEW_BONUS_UNLOCK_EUR} € de commission déjà générée. L’iPhone à ${VIEW_BONUS_FLAGSHIP_UNLOCK_EUR} € — tes ventes d’abord, les primes en plus.`,
    en: `Cash bonuses unlock at ${VIEW_BONUS_UNLOCK_EUR} EUR of commission already earned. The iPhone at ${VIEW_BONUS_FLAGSHIP_UNLOCK_EUR} EUR — sales first, bonuses on top.`,
  },
  {
    fr: "Tu claims en DM à leks, avec le lien du compte TikTok, dès qu’un palier est hit.",
    en: "Claim in a DM to leks, with the TikTok account link, as soon as a tier is hit.",
  },
  {
    fr: `C’est en plus des ${COMMISSION_PERCENT} % du net — pas à la place.`,
    en: `This is on top of ${COMMISSION_PERCENT}% of the net — not instead of it.`,
  },
];

export function ClipperBonusLadder() {
  return (
    <div className="af-md-ladder">
      <div className="af-md-ladder__life">
        <span className="af-md-ladder__pct" aria-hidden>
          %
        </span>
        <div>
          <p className="af-md-ladder__life-main">
            {appCopy("À vie", "For life")} <em>{COMMISSION_PERCENT}%</em>
          </p>
          <p className="af-md-ladder__life-sub">
            {appCopy("du net sur chaque vente", "of the net on every sale")}
          </p>
        </div>
      </div>
      <p className="af-md-ladder__scope">
        {appCopy(
          "Les vues de toutes les vidéos du compte s’additionnent — ça avance plus vite, pas besoin d’une seule vidéo monstre.",
          "Views from every video on the account add up — so it moves faster. You don’t need one monster clip."
        )}
      </p>
      <ul className="af-md-ladder__list">
        {TIERS.map((tier) => (
          <li key={tier.views} className="af-md-ladder__row">
            <div className="af-md-ladder__views">
              <strong>{tier.views}</strong>
              <span>{appCopy("vues", "views")}</span>
            </div>
            <hr className="af-md-ladder__rule" />
            <div className="af-md-ladder__prize">
              <strong>{tier.reward}</strong>
              {tier.extra ? <span>{appCopy(tier.extra.fr, tier.extra.en)}</span> : null}
            </div>
            <img
              className={`af-md-ladder__vis${tier.vis ? ` af-md-ladder__vis--${tier.vis}` : ""}`}
              src={tier.img}
              alt={appCopy(tier.alt.fr, tier.alt.en)}
              width={88}
              height={72}
            />
          </li>
        ))}
      </ul>
      <ul className="af-md-ladder__conditions">
        {CONDITIONS.map((item) => (
          <li key={item.en}>{appCopy(item.fr, item.en)}</li>
        ))}
      </ul>
    </div>
  );
}
