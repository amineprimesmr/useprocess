import { languageSwitchCopy } from "./process-landing-data.js";
import { useSiteLanguage } from "./useSiteLanguage.js";

export function LanguageSwitch() {
  const { lang, setLanguage } = useSiteLanguage();
  const copy = languageSwitchCopy();

  return (
    <div className="fk-lang-switch site-lang-switch" role="group" aria-label={copy.aria}>
      {["fr", "en"].map((code) => (
        <button
          key={code}
          type="button"
          data-lang={code}
          className={lang === code ? "is-active" : ""}
          aria-pressed={lang === code}
          onClick={() => setLanguage(code)}
        >
          {code === "fr" ? copy.fr : copy.en}
        </button>
      ))}
    </div>
  );
}
