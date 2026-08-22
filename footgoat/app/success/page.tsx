import { SuccessClient } from "@/components/SuccessClient";
import { getRequestLocale } from "@/lib/locale-server";

export default async function SuccessPage() {
  const locale = await getRequestLocale();
  return <SuccessClient locale={locale} />;
}
