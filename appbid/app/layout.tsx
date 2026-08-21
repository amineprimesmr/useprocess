import type { Metadata } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import "./globals.css";

const jakarta = Plus_Jakarta_Sans({
  subsets: ["latin"],
  variable: "--font-jakarta",
  display: "swap",
});

export const metadata: Metadata = {
  title: "appmog — Classement d'apps à enchères",
  description:
    "Paye pour être #1. Classement public d'apps iOS — lien App Store uniquement. Le rang, c'est l'enchère.",
  applicationName: "appmog",
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
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || "https://appmog.lol"),
  openGraph: {
    title: "appmog — MOGGED!",
    description: "Le classement public des apps mobiles. Rank is the bid.",
    type: "website",
    siteName: "appmog",
    images: [{ url: "/og-image.png", width: 1200, height: 630, alt: "appmog" }],
  },
  twitter: {
    card: "summary_large_image",
    title: "appmog — MOGGED!",
    description: "Le classement public des apps mobiles. Rank is the bid.",
    images: ["/og-image.png"],
  },
  appleWebApp: {
    capable: true,
    title: "appmog",
    statusBarStyle: "default",
  },
  themeColor: "#ffffff",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr" className={jakarta.variable}>
      <body className="antialiased">
        <div className="site-ribbons" aria-hidden="true">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="site-ribbon site-ribbon-left" src="/hero-left.jpg?v=2" alt="" loading="eager" decoding="async" fetchPriority="high" />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="site-ribbon site-ribbon-right" src="/hero-right.jpg?v=2" alt="" loading="eager" decoding="async" fetchPriority="high" />
        </div>
        <div className="relative z-[1]">{children}</div>
      </body>
    </html>
  );
}
