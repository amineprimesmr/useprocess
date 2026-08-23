import { appCopy } from "../features/app-copy.js";

const BLOCKS = [
  {
    title: { fr: "1. Un format, une promesse", en: "1. One format, one promise" },
    body: {
      fr: "Glow-up, foods, POV, protocole. Une idée par vidéo. Le viewer doit comprendre en 1 seconde ce qu'il gagne.",
      en: "Glow-up, foods, POV, protocol. One idea per video. The viewer should get the payoff in one second.",
    },
  },
  {
    title: { fr: "2. Volume calme", en: "2. Calm volume" },
    body: {
      fr: "1 à 3 posts / jour, tous les jours. Mieux vaut 14 jours d'affilée que 10 vidéos le dimanche. Tes heures d'onboarding calibrent le rythme.",
      en: "1–3 posts a day, every day. 14 days in a row beats 10 videos on Sunday. Your onboarding hours set the pace.",
    },
  },
  {
    title: { fr: "3. Lien Process partout", en: "3. Process link everywhere" },
    body: {
      fr: "Bio, pin comment, sticker story. Un seul lien créateur. Chaque abo via ce lien = 40 % à vie + primes vues.",
      en: "Bio, pinned comment, story sticker. One creator link. Every sub through that link = 40% for life + view bonuses.",
    },
  },
  {
    title: { fr: "4. Recycle ce qui marche", en: "4. Recycle what works" },
    body: {
      fr: "Dès qu'une vidéo passe 40k, tu la dupliques (même hook, autre angle). Les primes sont plafonnées à $300 / vidéo — le volume de hits compte.",
      en: "When a video clears 40k, duplicate it (same hook, new angle). Bonuses cap at $300 / video — hit volume matters.",
    },
  },
];

export function AffiliateMethodPage() {
  return (
    <div className="af-card af-card-pad">
      <p className="af-ob-kicker" style={{ marginBottom: 8 }}>
        {appCopy("Méthode TikTok", "TikTok method")}
      </p>
      <h2 style={{ margin: "0 0 0.4rem", letterSpacing: "-0.03em" }}>
        {appCopy("Le playbook Process", "The Process playbook")}
      </h2>
      <p style={{ margin: "0 0 1.4rem", color: "#71717a", lineHeight: 1.5 }}>
        {appCopy(
          "Simple, répétable, fait pour convertir vers l'app — pas pour faire du contenu vide.",
          "Simple, repeatable, built to convert to the app — not empty content."
        )}
      </p>
      <div style={{ display: "grid", gap: 14 }}>
        {BLOCKS.map((block) => (
          <article key={block.title.en} className="af-card af-card-pad" style={{ margin: 0, boxShadow: "none" }}>
            <h3 style={{ margin: "0 0 0.35rem", fontSize: "1.02rem" }}>{appCopy(block.title.fr, block.title.en)}</h3>
            <p style={{ margin: 0, color: "#52525b", lineHeight: 1.5 }}>{appCopy(block.body.fr, block.body.en)}</p>
          </article>
        ))}
      </div>
    </div>
  );
}
