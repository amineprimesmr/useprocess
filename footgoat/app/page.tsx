import { HomeClient } from "@/components/HomeClient";
import { getBoard } from "@/lib/db";
import { getRequestLocale } from "@/lib/locale-server";

export const dynamic = "force-dynamic";

export default async function Page() {
  const [board, locale] = await Promise.all([getBoard(), getRequestLocale()]);
  return <HomeClient initial={board} locale={locale} />;
}
