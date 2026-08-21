import { createRoot } from "react-dom/client";
import { warmFirebaseAuth } from "../features/firebase-client.js";
import { initSiteLanguage } from "../features/app-copy.js";
import { dismissCrispChat } from "../features/crisp-chat.js";
import { AffiliateApp } from "./AffiliateApp.jsx";

export function mountAffiliate() {
  initSiteLanguage();
  dismissCrispChat();
  warmFirebaseAuth();
  const el = document.getElementById("affiliate-root");
  if (!el) return;
  el.dataset.mounted = "1";
  const existingRoot = el.__affiliateRoot;
  const root = existingRoot || createRoot(el);
  if (!existingRoot) el.__affiliateRoot = root;
  root.render(<AffiliateApp />);
}

mountAffiliate();
