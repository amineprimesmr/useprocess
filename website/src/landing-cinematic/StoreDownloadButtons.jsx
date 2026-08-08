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

function PlayLogo({ className }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path fill="#EA4335" d="M3.6 2.2 13.4 12 3.6 21.8c-.4-.2-.6-.6-.6-1V3.2c0-.4.2-.8.6-1z" />
      <path fill="#FBBC04" d="m13.4 12 2.7-2.7 4.4 2.5c.6.3.6 1.1 0 1.4l-4.4 2.5L13.4 12z" />
      <path fill="#4285F4" d="M13.4 12 3.6 2.2c.3-.2.6-.2.9 0l11.6 6.6L13.4 12z" />
      <path fill="#34A853" d="M13.4 12 16.1 14.7 4.5 21.8c-.3.2-.6.1-.9 0L13.4 12z" />
    </svg>
  );
}

/** Boutons App Store + Play Store (Coming soon). */
export function StoreDownloadButtons({ className = "" }) {
  const iosUrl = getIosAppStoreUrl();

  return (
    <div className={`store-download-buttons${className ? ` ${className}` : ""}`}>
      <a
        className="store-download-btn store-download-btn--apple"
        href={iosUrl}
        target="_blank"
        rel="noopener noreferrer"
        aria-label="Télécharger l'app sur l'App Store"
      >
        <AppleLogo className="store-download-btn__logo store-download-btn__logo--apple" />
        <span className="store-download-btn__copy">
          <span className="store-download-btn__eyebrow">Télécharger l&apos;app</span>
          <span className="store-download-btn__name">App Store</span>
        </span>
      </a>

      <span
        className="store-download-btn store-download-btn--play store-download-btn--soon"
        role="status"
        aria-label="Google Play — Coming soon"
      >
        <PlayLogo className="store-download-btn__logo store-download-btn__logo--play" />
        <span className="store-download-btn__copy">
          <span className="store-download-btn__eyebrow">Coming soon</span>
          <span className="store-download-btn__name">Google Play</span>
        </span>
      </span>
    </div>
  );
}
