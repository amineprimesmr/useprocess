import { CheckoutClient } from "@/components/CheckoutClient";
import { getRequestLocale } from "@/lib/locale-server";

export default async function CheckoutPage() {
  const locale = await getRequestLocale();
  return <CheckoutClient locale={locale} />;
}
