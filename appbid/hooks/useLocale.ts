"use client";

import { useEffect, useState } from "react";
import type { Locale } from "@/lib/copy";
import { detectClientLocale } from "@/lib/locale";

export function useLocale(initial: Locale): Locale {
  const [locale, setLocale] = useState<Locale>(initial);

  useEffect(() => {
    setLocale(detectClientLocale(initial));
  }, [initial]);

  return locale;
}
