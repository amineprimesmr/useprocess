import { useEffect, useState } from "react";
import { getSiteLanguage, setSiteLanguage, subscribeSiteLanguage } from "../features/app-copy.js";

export function useSiteLanguage() {
  const [lang, setLang] = useState(() => getSiteLanguage());

  useEffect(() => subscribeSiteLanguage(setLang), []);

  return {
    lang,
    isEnglish: lang === "en",
    setLanguage: setSiteLanguage,
  };
}
