import { languageSwitchCopy } from "./process-landing-data.js";
import { useSiteLanguage } from "./useSiteLanguage.js";
import { SITE_LANGUAGES } from "../features/languages.js";

export function LanguageSwitch() {
  const { lang, setLanguage } = useSiteLanguage();
  const copy = languageSwitchCopy();

  return (
    <label className="fk-lang-switch site-lang-switch site-lang-switch--select">
      <span className="sr-only">{copy.aria}</span>
      <select
        aria-label={copy.aria}
        value={lang}
        onChange={(event) => setLanguage(event.target.value)}
      >
        {SITE_LANGUAGES.map((item) => (
          <option key={item.code} value={item.code}>
            {item.label}
          </option>
        ))}
      </select>
    </label>
  );
}
