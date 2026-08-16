import { themeSwitchCopy } from "./process-landing-data.js";
import { useSiteTheme } from "./useSiteTheme.js";

function MoonIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <path
        fill="currentColor"
        d="M21 14.5A8.5 8.5 0 0 1 9.5 3 7 7 0 1 0 21 14.5Z"
      />
    </svg>
  );
}

function SunIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false" fill="none">
      <circle cx="12" cy="12" r="4" fill="currentColor" />
      <path
        d="M12 2.75v2.5M12 18.75v2.5M4.93 4.93l1.77 1.77M17.3 17.3l1.77 1.77M2.75 12h2.5M18.75 12h2.5M4.93 19.07l1.77-1.77M17.3 6.7l1.77-1.77"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeLinecap="round"
      />
    </svg>
  );
}

export function ThemeToggle({ className = "" }) {
  const { isDark, toggleTheme } = useSiteTheme();
  const copy = themeSwitchCopy();

  return (
    <button
      type="button"
      className={`fk-theme-toggle${className ? ` ${className}` : ""}`}
      onClick={toggleTheme}
      aria-label={isDark ? copy.light : copy.dark}
      aria-pressed={isDark}
    >
      {isDark ? <SunIcon /> : <MoonIcon />}
    </button>
  );
}
