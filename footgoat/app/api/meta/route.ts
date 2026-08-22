import { NextResponse } from "next/server";
import type { Locale } from "@/lib/copy";
import { normalizeTarget } from "@/lib/keys";
import { resolveMeta } from "@/lib/meta";
import { LOCALE_COOKIE, resolveLocale } from "@/lib/locale";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const body = (await request.json().catch(() => ({}))) as { url?: string; locale?: Locale };
  const target = normalizeTarget(body.url ?? "");
  if (!target) {
    return NextResponse.json({ error: "INVALID" }, { status: 400 });
  }
  const cookieLocale = request.headers.get("cookie")?.match(new RegExp(`${LOCALE_COOKIE}=(en|fr)`))?.[1];
  const locale: Locale =
    body.locale === "en" || body.locale === "fr"
      ? body.locale
      : cookieLocale === "en" || cookieLocale === "fr"
        ? cookieLocale
        : resolveLocale(
            request.headers.get("x-vercel-ip-country"),
            request.headers.get("accept-language"),
          );
  const meta = await resolveMeta(target, locale);
  return NextResponse.json({ ...meta, url: target.url, key: target.key });
}
