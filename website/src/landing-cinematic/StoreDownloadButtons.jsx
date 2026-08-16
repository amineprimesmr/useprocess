import { useId } from "react";
import { appCopy } from "../features/app-copy.js";
import { getIosAppStoreUrl } from "../features/app-store-urls.js";
import "./store-download-buttons.css";

function AppStoreLogo({ className }) {
  const gradientId = useId().replace(/:/g, "");

  return (
    <svg className={className} viewBox="0 0 28 28" aria-hidden="true" focusable="false">
      <path
        fill={`url(#${gradientId})`}
        d="M14 26.25c6.765 0 12.25-5.485 12.25-12.25S20.765 1.75 14 1.75 1.75 7.235 1.75 14 7.235 26.25 14 26.25"
      />
      <path
        fill="#fff"
        d="M16.141 7.572a.97.97 0 0 0-.353-1.318.96.96 0 0 0-1.313.355l-.462.806-.461-.806a.96.96 0 0 0-1.313-.355.97.97 0 0 0-.353 1.318l1.019 1.779-3.223 5.624H7.086a.963.963 0 0 0-.961.966c0 .533.43.966.961.966h9.042c.08-.21.163-.569.074-.899-.133-.496-.627-1.032-1.455-1.032H11.9zm-5.959 10.402c-.164-.183-.532-.475-.854-.571-.491-.147-.863-.055-1.051.025l-.716 1.25a.97.97 0 0 0 .353 1.318.96.96 0 0 0 1.313-.355z"
      />
      <path
        fill="#fff"
        d="M19.45 16.906h1.464c.53 0 .961-.432.961-.965a.963.963 0 0 0-.961-.966h-2.57L15.45 9.923c-.215.206-.627.73-.69 1.325-.08.764.04 1.408.401 2.038q1.818 3.178 3.639 6.355a.96.96 0 0 0 1.312.355.97.97 0 0 0 .354-1.318l-1.015-1.772Z"
      />
      <defs>
        <linearGradient id={gradientId} x1="14" x2="14" y1="1.75" y2="26.25" gradientUnits="userSpaceOnUse">
          <stop stopColor="#2AC9FA" />
          <stop offset="1" stopColor="#1F65EB" />
        </linearGradient>
      </defs>
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
        <AppStoreLogo className="store-download-btn__logo store-download-btn__logo--appstore" />
        <span className="store-download-btn__copy">
          <span className="store-download-btn__eyebrow">{iosEyebrow}</span>
          <span className="store-download-btn__name">App Store</span>
        </span>
      </a>
    </div>
  );
}
