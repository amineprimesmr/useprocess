import { useEffect, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { detectInAppBrowser, getSafariStoreLandingUrl, openInExternalBrowser } from "../features/in-app-browser-escape.js";
import "./in-app-escape-hint.css";

export function InAppEscapeHint() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    setVisible(Boolean(detectInAppBrowser()));
  }, []);

  if (!visible) return null;

  const title = appCopy(
    "Tu es dans le navigateur TikTok",
    "You're in TikTok's in-app browser"
  );
  const body = appCopy(
    "TikTok bloque les liens App Store. Ouvre d’abord Safari, puis télécharge Process.",
    "TikTok blocks App Store links. Open Safari first, then download Process."
  );
  const cta = appCopy("Ouvrir dans Safari", "Open in Safari");
  const manual = appCopy(
    "Sinon : ⋯ en haut à droite → Ouvrir dans Safari",
    "Or: ⋯ top-right → Open in Safari"
  );

  return (
    <div className="fk-inapp-hint" role="status">
      <div className="fk-inapp-hint__copy">
        <strong>{title}</strong>
        <p>{body}</p>
        <p className="fk-inapp-hint__manual">{manual}</p>
      </div>
      <button
        type="button"
        className="fk-inapp-hint__cta"
        onClick={() => openInExternalBrowser(getSafariStoreLandingUrl())}
      >
        {cta}
      </button>
    </div>
  );
}
