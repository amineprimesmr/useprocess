import { useEffect, useState } from "react";
import { StoreDownloadButtons } from "../landing-cinematic/StoreDownloadButtons.jsx";
import { chromeAriaCopy } from "./process-landing-data.js";

/** Bouton App Store flottant — visible dès que le hero sort de l'écran. */
export function StickyDownloadBar() {
  const [visible, setVisible] = useState(false);
  const aria = chromeAriaCopy();

  useEffect(() => {
    const hero = document.getElementById("fk-hero");
    if (!hero) return undefined;

    const observer = new IntersectionObserver(
      ([entry]) => setVisible(!entry.isIntersecting),
      { threshold: 0, rootMargin: "0px 0px 0px 0px" }
    );

    observer.observe(hero);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    document.querySelector(".fk-page")?.classList.toggle("fk-page--sticky-dl", visible);
    return () => document.querySelector(".fk-page")?.classList.remove("fk-page--sticky-dl");
  }, [visible]);

  return (
    <div
      className={`fk-sticky-dl${visible ? " is-visible" : ""}`}
      aria-hidden={!visible}
      role="region"
      aria-label={aria.appStoreBadge}
    >
      <StoreDownloadButtons className="fk-sticky-dl__buttons" />
    </div>
  );
}
