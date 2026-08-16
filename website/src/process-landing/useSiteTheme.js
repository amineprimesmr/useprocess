import { useEffect, useState } from "react";
import { getSiteTheme, setSiteTheme, subscribeSiteTheme, toggleSiteTheme } from "../features/site-theme.js";

export function useSiteTheme() {
  const [theme, setTheme] = useState(() => getSiteTheme());

  useEffect(() => subscribeSiteTheme(setTheme), []);

  return {
    theme,
    isDark: theme === "dark",
    setTheme: setSiteTheme,
    toggleTheme: toggleSiteTheme,
  };
}
