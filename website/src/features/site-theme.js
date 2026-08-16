export const SITE_THEME_KEY = "process.site.theme";

const listeners = new Set();

function prefersDarkFromSystem() {
  if (typeof window === "undefined") return false;
  return window.matchMedia("(prefers-color-scheme: dark)").matches;
}

export function getSiteTheme() {
  if (typeof window === "undefined") return "light";

  try {
    const stored = localStorage.getItem(SITE_THEME_KEY);
    if (stored === "light" || stored === "dark") return stored;
  } catch {
    /* private mode */
  }

  return prefersDarkFromSystem() ? "dark" : "light";
}

export function applySiteTheme(theme) {
  const normalized = theme === "dark" ? "dark" : "light";
  document.documentElement.classList.toggle("fk-theme-dark", normalized === "dark");
  document.documentElement.style.colorScheme = normalized;

  const themeColor = document.querySelector('meta[name="theme-color"]');
  if (themeColor) {
    themeColor.setAttribute("content", normalized === "dark" ? "#0a0a10" : "#f2f2f2");
  }
}

export function subscribeSiteTheme(callback) {
  listeners.add(callback);
  return () => listeners.delete(callback);
}

function notifyThemeChange(theme) {
  for (const cb of listeners) cb(theme);
  window.dispatchEvent(new CustomEvent("process:theme-change", { detail: theme }));
}

export function setSiteTheme(theme) {
  const normalized = theme === "dark" ? "dark" : "light";
  try {
    localStorage.setItem(SITE_THEME_KEY, normalized);
  } catch {
    /* ignore */
  }
  applySiteTheme(normalized);
  notifyThemeChange(normalized);
}

export function toggleSiteTheme() {
  setSiteTheme(getSiteTheme() === "dark" ? "light" : "dark");
}

/** À appeler au boot avant le montage React (évite le flash). */
export function initSiteTheme() {
  applySiteTheme(getSiteTheme());
}
