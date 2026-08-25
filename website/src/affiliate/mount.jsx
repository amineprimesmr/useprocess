import { createRoot } from "react-dom/client";
import { warmFirebaseAuth, warmAffiliateFunctions } from "../features/firebase-client.js";
import { initSiteLanguage } from "../features/app-copy.js";
import { AffiliateApp } from "./AffiliateApp.jsx";

export function mountAffiliate() {
  initSiteLanguage();
  warmFirebaseAuth();
  warmAffiliateFunctions();
  const el = document.getElementById("affiliate-root");
  if (!el) return;
  el.dataset.mounted = "1";
  const existingRoot = el.__affiliateRoot;
  const root = existingRoot || createRoot(el);
  if (!existingRoot) el.__affiliateRoot = root;
  root.render(<AffiliateApp />);
}

mountAffiliate();
