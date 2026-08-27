import { appCopy } from "../features/app-copy.js";
import { IconDownload, ProcessAppIcon, ProcessNavIcon } from "./AffiliateIcons.jsx";
import { SuccessActionButton } from "./action-feedback.jsx";
import "./affiliate-process-assets.css";

const KIT = "/assets/affiliate/kit";

const GROUPS = [
  {
    id: "logo",
    title: { fr: "Logo", en: "Logo" },
    items: [
      {
        src: "/assets/icone.png",
        file: "process-icon.png",
        kind: "square",
        fr: "Icône app",
        en: "App icon",
      },
      {
        src: `${KIT}/head.jpg`,
        file: "process-head.jpg",
        kind: "square",
        fr: "Tête",
        en: "Head",
      },
    ],
  },
  {
    id: "screens",
    title: { fr: "Screens app", en: "App screens" },
    items: [
      {
        src: `${KIT}/home-en.jpg`,
        file: "process-home.jpg",
        kind: "phone",
        fr: "Home",
        en: "Home",
      },
      {
        src: `${KIT}/scan-light-fr.jpg`,
        file: "process-scan-light-fr.jpg",
        kind: "phone",
        fr: "Scan clair",
        en: "Light scan",
      },
      {
        src: `${KIT}/scan-dark-fr.jpg`,
        file: "process-scan-dark-fr.jpg",
        kind: "phone",
        fr: "Scan sombre",
        en: "Dark scan",
      },
      {
        src: `${KIT}/scan-en.jpg`,
        file: "process-scan-en.jpg",
        kind: "phone",
        fr: "Scan EN",
        en: "EN scan",
      },
      {
        src: `${KIT}/scan-before.jpg`,
        file: "process-scan-before.jpg",
        kind: "phone",
        fr: "Scan before",
        en: "Scan before",
      },
      {
        src: `${KIT}/scan-after.jpg`,
        file: "process-scan-after.jpg",
        kind: "phone",
        fr: "Scan after",
        en: "Scan after",
      },
      {
        src: `${KIT}/recipes.jpg`,
        file: "process-recipes.jpg",
        kind: "photo",
        fr: "Recettes",
        en: "Recipes",
      },
    ],
  },
  {
    id: "store",
    title: { fr: "App Store", en: "App Store" },
    items: [
      {
        src: `${KIT}/appstore-card.jpg`,
        file: "process-appstore-card.jpg",
        kind: "banner",
        fr: "Carte App Store",
        en: "App Store card",
      },
      {
        src: `${KIT}/appstore-listing.jpg`,
        file: "process-appstore-listing.jpg",
        kind: "promo",
        fr: "Fiche App Store",
        en: "App Store listing",
      },
      {
        src: "/assets/get/app_store_white.svg",
        file: "app-store-badge.svg",
        kind: "badge",
        fr: "Badge Download",
        en: "Download badge",
      },
      {
        src: "/assets/logos/app-store.png",
        file: "app-store-logo.png",
        kind: "square",
        fr: "Logo App Store",
        en: "App Store logo",
      },
    ],
  },
];

async function downloadFile(item) {
  const response = await fetch(item.src);
  if (!response.ok) throw new Error("download_failed");
  const blob = await response.blob();
  const href = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = href;
  link.download = item.file;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(href), 1500);
}

function AssetCard({ item }) {
  return (
    <article className={`af-asset-card is-${item.kind}`}>
      <div className="af-asset-preview">
        <img src={item.src} alt={appCopy(item.fr, item.en)} />
      </div>
      <div className="af-asset-meta">
        <strong>{appCopy(item.fr, item.en)}</strong>
        <SuccessActionButton
          className="af-btn af-btn-sm af-btn-black"
          idleLabel={
            <>
              <IconDownload />
              {appCopy("Télécharger", "Download")}
            </>
          }
          savingLabel={appCopy("Téléchargement…", "Downloading…")}
          successLabel={appCopy("OK", "Done")}
          onAction={() => downloadFile(item)}
        />
      </div>
    </article>
  );
}

export function AffiliateProcessAssetsPage() {
  return (
    <div className="af-assets">
      <header className="af-assets-head">
        <p className="af-assets-kicker">
          <ProcessNavIcon />
          Process
        </p>
        <h2>
          <ProcessAppIcon size={28} />
          Process Assets
        </h2>
        <p className="af-assets-lead">
          {appCopy(
            "Fichiers officiels à coller dans tes slideshows : logo, screens app, carte App Store. Télécharge, n’écrase pas le visuel.",
            "Official files to drop in your slideshows: logo, app screens, App Store card. Download them — don’t redraw the look."
          )}
        </p>
      </header>

      {GROUPS.map((group) => (
        <section key={group.id} className="af-assets-group">
          <h3>{appCopy(group.title.fr, group.title.en)}</h3>
          <div className="af-assets-grid">
            {group.items.map((item) => (
              <AssetCard key={item.file} item={item} />
            ))}
          </div>
        </section>
      ))}
    </div>
  );
}
