import { appCopy } from "../features/app-copy.js";
import { getIosAppStoreUrl } from "../features/app-store-urls.js";
import "./store-download-buttons.css";

function AppleLogo({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path
        fill="currentColor"
        d="M16.7 12.4c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.8-3.1.8-.7 0-1.7-.7-2.8-.7-1.4 0-2.8.9-3.5 2.2-1.5 2.6-.4 6.4 1.1 8.5.7 1 1.6 2.2 2.7 2.1 1.1 0 1.5-.7 2.8-.7s1.7.7 2.8.7c1.2 0 1.9-1 2.6-2 .8-1.2 1.1-2.3 1.1-2.4-.1 0-2.2-.8-2.2-3.7zm-2-6.1c.6-.7 1-1.7.9-2.7-1 .1-2.1.6-2.8 1.4-.6.7-1.1 1.7-1 2.7 1 .1 2.1-.5 2.9-1.4z"
      />
    </svg>
  );
}

/** Bouton App Store. */
export function StoreDownloadButtons({ className = "" }) {
  const iosUrl = getIosAppStoreUrl();
  const iosEyebrow = appCopy("Télécharger sur", "Download on");
  const iosAria = appCopy("Télécharger sur App Store", "Download on App Store");

  return (
    <div className={`store-download-buttons${className ? ` ${className}` : ""}`}>
      <a
        className="store-download-btn store-download-btn--apple"
        href={iosUrl}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={iosAria}
      >
        <AppleLogo className="store-download-btn__logo store-download-btn__logo--apple" />
        <span className="store-download-btn__copy">
          <span className="store-download-btn__eyebrow">{iosEyebrow}</span>
          <span className="store-download-btn__name">App Store</span>
        </span>
      </a>
    </div>
  );
}
