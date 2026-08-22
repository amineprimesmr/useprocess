import type { Metadata } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import { siteMetadata } from "@/lib/copy";
import { localeHtmlLang } from "@/lib/locale";
import { getRequestLocale } from "@/lib/locale-server";
import "./globals.css";

const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  variable: "--font-jakarta",
  display: "swap",
});

export async function generateMetadata(): Promise<Metadata> {
  const locale = await getRequestLocale();
  const meta = siteMetadata(locale);
  const base = process.env.NEXT_PUBLIC_SITE_URL || "https://footgoat.lol";

  return {
    title: meta.title,
    description: meta.description,
    applicationName: "footgoat",
    manifest: "/manifest.webmanifest",
    icons: {
      icon: [
        { url: "/favicon.png", sizes: "32x32", type: "image/png" },
        { url: "/favicon-16.png", sizes: "16x16", type: "image/png" },
        { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
        { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
      ],
      apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
      shortcut: "/favicon.png",
    },
    metadataBase: new URL(base),
    openGraph: {
      title: "footgoat — GOATED!",
      description: meta.ogDescription,
      type: "website",
      siteName: "footgoat",
      images: [{ url: "/og-image.png", width: 1200, height: 630, alt: "footgoat" }],
    },
    twitter: {
      card: "summary_large_image",
      title: "footgoat — GOATED!",
      description: meta.ogDescription,
      images: ["/og-image.png"],
    },
    appleWebApp: {
      capable: true,
      title: "footgoat",
      statusBarStyle: "default",
    },
    themeColor: "#ffffff",
  };
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const locale = await getRequestLocale();
  const lang = localeHtmlLang(locale);

  return (
    <html lang={lang} className={jakarta.variable}>
      <body className="antialiased">
        <div className="site-ribbons" aria-hidden="true">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="site-ribbon site-ribbon-left" src="/hero-left.jpg?v=3" alt="" loading="eager" decoding="async" fetchPriority="high" />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="site-ribbon site-ribbon-right" src="/hero-right.jpg?v=3" alt="" loading="eager" decoding="async" fetchPriority="high" />
        </div>
        <div className="relative z-[1]">{children}</div>
      </body>
    </html>
  );
}
