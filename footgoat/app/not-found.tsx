import { getRequestLocale } from "@/lib/locale-server";
import { siteCopy } from "@/lib/copy";

export default async function NotFound() {
  const locale = await getRequestLocale();
  const copy = siteCopy(locale);

  return (
    <div className="grid min-h-screen place-items-center px-5">
      <div className="text-center">
        <h1 className="text-3xl font-extrabold">404</h1>
        <p className="mt-2 text-[15px] text-[var(--muted)]">
          {locale === "en" ? "Page not found." : "Page introuvable."}
        </p>
        <a href="/" className="btn-primary mt-6 inline-flex rounded-full px-5 py-3 font-semibold">
          {copy.backHome}
        </a>
      </div>
    </div>
  );
}
