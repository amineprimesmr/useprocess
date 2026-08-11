/** FR / US English — aligné sur ProcessAppLanguage (device + préférence utilisateur web). */
export function prefersEnglish() {
  const langs = navigator.languages?.length
    ? navigator.languages
    : [navigator.language || "en"];
  for (const tag of langs) {
    const lower = String(tag).toLowerCase();
    if (lower.startsWith("fr")) return false;
    if (lower.startsWith("en")) return true;
  }
  return true;
}

export function appCopy(fr, en) {
  return prefersEnglish() ? en : fr;
}
