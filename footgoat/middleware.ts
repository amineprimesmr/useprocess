import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import type { Locale } from "@/lib/copy";
import { LOCALE_COOKIE, resolveLocale } from "@/lib/locale";

function localeFromQuery(value: string | null): Locale | null {
  if (value === "en" || value === "us") return "en";
  if (value === "fr") return "fr";
  return null;
}

export function middleware(request: NextRequest) {
  const country =
    request.headers.get("x-vercel-ip-country") ??
    request.headers.get("cf-ipcountry");
  const acceptLanguage = request.headers.get("accept-language");
  const fromQuery = localeFromQuery(request.nextUrl.searchParams.get("lang"));
  const locale = fromQuery ?? resolveLocale(country, acceptLanguage);

  const response = NextResponse.next();
  response.cookies.set(LOCALE_COOKIE, locale, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax",
  });
  response.headers.set("x-footgoat-locale", locale);
  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon|icon|.*\\.(?:png|jpg|jpeg|webp|svg|ico|webmanifest)).*)"],
};
