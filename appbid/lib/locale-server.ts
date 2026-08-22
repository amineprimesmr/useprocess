import { cookies, headers } from "next/headers";
import type { Locale } from "@/lib/copy";
import { LOCALE_COOKIE, resolveLocale } from "@/lib/locale";

export async function getRequestLocale(): Promise<Locale> {
  const h = await headers();
  const fromMiddleware = h.get("x-appmog-locale");
  if (fromMiddleware === "en" || fromMiddleware === "fr") return fromMiddleware;

  const cookieStore = await cookies();
  const fromCookie = cookieStore.get(LOCALE_COOKIE)?.value;
  if (fromCookie === "en" || fromCookie === "fr") return fromCookie;

  const country = h.get("x-vercel-ip-country") ?? h.get("cf-ipcountry");
  const acceptLanguage = h.get("accept-language");
  return resolveLocale(country, acceptLanguage);
}
